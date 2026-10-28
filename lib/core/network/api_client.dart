import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/env.dart';
import 'token_store.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => 'ApiException(code: $code, message: $message, status: $statusCode)';
}

/// A file for [ApiClient.postMultipart].
class UploadFile {
  final String field;
  final Uint8List bytes;
  final String filename;
  final String contentType;
  const UploadFile({required this.field, required this.bytes, required this.filename, required this.contentType});
}

/// Outcome of renewing the session: new tokens, session dead, or server unreachable.
enum RefreshResult { refreshed, invalid, unavailable }

/// HTTP client for the GreenRev API.
///
/// Sessions: the server issues a short-lived access token (body + cookie) and a
/// long-lived refresh token (cookie only). We keep both, and when an authenticated
/// call returns 401 we refresh once — shared by all concurrent callers, because the
/// server revokes a refresh token on use — then retry the original request.
class ApiClient {
  static const _refreshPath = '/api/v1/auth/refresh';
  static const _logoutPath = '/api/v1/auth/logout';
  // Auth calls whose 401 means "wrong credentials", not "session expired".
  static const _noRefreshPaths = {
    '/api/v1/auth/login',
    '/api/v1/auth/register',
    _refreshPath,
    _logoutPath,
  };

  http.Client _client = http.Client();
  TokenStore _store = SecureTokenStore();
  String? _accessToken;
  String? _refreshToken;
  Future<RefreshResult>? _refreshing;
  Future<void> _persisting = Future.value();
  final List<void Function(String? accessToken)> _tokenListeners = [];

  /// Called when the session can't be renewed (refresh token expired or revoked).
  VoidCallback? onSessionExpired;

  // Singleton instance
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  @visibleForTesting
  void configureForTesting({http.Client? client, TokenStore? store}) {
    if (client != null) _client = client;
    if (store != null) _store = store;
    _accessToken = null;
    _refreshToken = null;
    _refreshing = null;
    _tokenListeners.clear();
    onSessionExpired = null;
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _accessToken != null || _refreshToken != null;

  /// Notified whenever the access token changes (login, refresh, logout).
  void addAccessTokenListener(void Function(String? accessToken) listener) => _tokenListeners.add(listener);

  /// Load tokens saved by a previous launch.
  Future<void> restoreSession() async {
    final (access, refresh) = await _store.read();
    _accessToken = access;
    _refreshToken = refresh;
  }

  /// Set after login. The refresh token is normally captured from the response cookies.
  void setTokens({required String? accessToken, String? refreshToken}) {
    final changed = accessToken != _accessToken;
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    _persist();
    if (changed) _notify();
  }

  Future<void> clearTokens() async {
    final hadAccess = _accessToken != null;
    _accessToken = null;
    _refreshToken = null;
    _persisting = _persisting.then((_) => _store.clear());
    await _persisting;
    if (hadAccess) _notify();
  }

  void _persist() {
    final access = _accessToken;
    final refresh = _refreshToken;
    // Chain writes so a slow earlier write can't overwrite a newer token.
    _persisting = _persisting.then((_) => _store.write(access: access, refresh: refresh));
  }

  void _notify() {
    for (final l in List.of(_tokenListeners)) {
      l(_accessToken);
    }
  }

  Future<dynamic> get(String path, {bool requiresAuth = true}) =>
      _send('GET', path, requiresAuth: requiresAuth);

  Future<dynamic> post(String path, {dynamic body, bool requiresAuth = true}) =>
      _send('POST', path, body: body, requiresAuth: requiresAuth);

  Future<dynamic> put(String path, {dynamic body, bool requiresAuth = true}) =>
      _send('PUT', path, body: body, requiresAuth: requiresAuth);

  Future<dynamic> patch(String path, {dynamic body, bool requiresAuth = true}) =>
      _send('PATCH', path, body: body, requiresAuth: requiresAuth);

  Future<dynamic> delete(String path, {bool requiresAuth = true}) =>
      _send('DELETE', path, requiresAuth: requiresAuth);

  /// multipart/form-data POST for file uploads (product photos, voice notes).
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<UploadFile> files = const [],
    Duration timeout = const Duration(seconds: 90),
  }) =>
      _withRefresh(path, true, () => _rawMultipart(path, fields, files, timeout));

  Future<dynamic> _send(String method, String path, {dynamic body, bool requiresAuth = true}) =>
      _withRefresh(path, requiresAuth, () => _raw(method, path, body: body, requiresAuth: requiresAuth));

  Future<dynamic> _withRefresh(String path, bool requiresAuth, Future<http.Response> Function() request) async {
    final usedToken = _accessToken;
    var response = await request();

    if (response.statusCode == 401 && requiresAuth && !_noRefreshPaths.contains(path) && hasSession) {
      // Another caller may already have refreshed while this request was in flight.
      final alreadyRenewed = _accessToken != null && _accessToken != usedToken;
      final result = alreadyRenewed ? RefreshResult.refreshed : await refreshSession();
      if (result == RefreshResult.refreshed) {
        response = await request();
      } else if (result == RefreshResult.invalid) {
        await clearTokens();
        onSessionExpired?.call();
      }
    }

    _captureRefreshToken(response);
    return _processResponse(response);
  }

  /// Renew the access token. Concurrent callers share one in-flight refresh.
  Future<RefreshResult> refreshSession() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<RefreshResult> _doRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return RefreshResult.invalid;

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${Env.apiBaseUrl}$_refreshPath'),
            headers: {..._headers(requiresAuth: false), 'Cookie': 'refresh_token=$refreshToken'},
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Offline or timed out: keep the session, the caller just gets the original error.
      return RefreshResult.unavailable;
    }

    if (response.statusCode == 401 || response.statusCode == 403) return RefreshResult.invalid;
    if (response.statusCode < 200 || response.statusCode >= 300) return RefreshResult.unavailable;

    final newRefresh = _refreshTokenFromCookies(response);
    String? newAccess;
    try {
      final json = jsonDecode(response.body);
      final data = json is Map<String, dynamic> && json['data'] is Map ? json['data'] : json;
      newAccess = (data as Map)['accessToken']?.toString();
    } catch (_) {}
    if (newAccess == null || newAccess.isEmpty) return RefreshResult.unavailable;

    setTokens(accessToken: newAccess, refreshToken: newRefresh);
    return RefreshResult.refreshed;
  }

  Future<http.Response> _raw(String method, String path, {dynamic body, required bool requiresAuth}) async {
    final uri = Uri.parse('${Env.apiBaseUrl}$path');
    final headers = _headers(requiresAuth: requiresAuth);
    // Logout reads the refresh token from its cookie so the server can revoke it.
    if (path == _logoutPath && _refreshToken != null) {
      headers['Cookie'] = 'refresh_token=$_refreshToken';
    }
    final encoded = body != null ? jsonEncode(body) : null;
    try {
      switch (method) {
        case 'GET':
          return await _client.get(uri, headers: headers);
        case 'POST':
          return await _client.post(uri, headers: headers, body: encoded);
        case 'PUT':
          return await _client.put(uri, headers: headers, body: encoded);
        case 'PATCH':
          return await _client.patch(uri, headers: headers, body: encoded);
        default:
          return await _client.delete(uri, headers: headers);
      }
    } catch (e) {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to connect to the server: $e',
        statusCode: 0,
      );
    }
  }

  Future<http.Response> _rawMultipart(
    String path,
    Map<String, String> fields,
    List<UploadFile> files,
    Duration timeout,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse('${Env.apiBaseUrl}$path'))
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields);
    if (_accessToken != null) request.headers['Authorization'] = 'Bearer $_accessToken';
    for (final f in files) {
      request.files.add(http.MultipartFile.fromBytes(
        f.field,
        f.bytes,
        filename: f.filename,
        contentType: MediaType.parse(f.contentType),
      ));
    }
    try {
      return await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on TimeoutException {
      throw ApiException(code: 'TIMEOUT', message: 'The upload took too long. Check your connection and try again.', statusCode: 0);
    } catch (e) {
      throw ApiException(code: 'NETWORK_ERROR', message: 'Unable to connect to the server: $e', statusCode: 0);
    }
  }

  Map<String, String> _headers({bool requiresAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// Login and refresh responses carry the refresh token only as a Set-Cookie header.
  void _captureRefreshToken(http.Response response) {
    final token = _refreshTokenFromCookies(response);
    if (token != null && token != _refreshToken) {
      _refreshToken = token;
      _persist();
    }
  }

  static String? _refreshTokenFromCookies(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return null;
    // Multiple Set-Cookie headers are joined with commas; token values are base64url.
    final match = RegExp(r'(?:^|[;,]\s*)refresh_token=([A-Za-z0-9_\-]+)').firstMatch(setCookie);
    return match?.group(1);
  }

  dynamic _processResponse(http.Response response) {
    final int status = response.statusCode;
    final String bodyString = response.body;

    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(bodyString);
    } catch (_) {
      throw ApiException(
        code: 'PARSE_ERROR',
        message: 'Failed to parse response body',
        statusCode: status,
      );
    }

    if (status >= 200 && status < 300) {
      dynamic data = jsonBody;
      if (jsonBody is Map<String, dynamic> && jsonBody['success'] == true) {
        data = jsonBody['data'];
      }

      if (data is Map<String, dynamic>) {
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null && (data['accessToken'] == null && data['token'] == null)) {
          final match = RegExp(r'access_token=([^;]+)').firstMatch(setCookie);
          if (match != null) {
            data['accessToken'] = match.group(1);
          }
        }
      }
      return data;
    } else {
      String code = 'API_ERROR';
      String message = 'Something went wrong';
      if (jsonBody is Map<String, dynamic> && jsonBody['error'] != null) {
        final error = jsonBody['error'];
        if (error is Map<String, dynamic>) {
          code = error['code'] ?? 'API_ERROR';
          message = error['message'] ?? 'Something went wrong';
        } else if (error is String) {
          message = error;
        }
      }
      throw ApiException(
        code: code,
        message: message,
        statusCode: status,
      );
    }
  }
}
