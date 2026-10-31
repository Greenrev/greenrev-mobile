import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _sessionExpired = false;

  UserModel? get user => _user;
  String? get token => _apiClient.accessToken;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _apiClient.hasSession && _user != null;

  /// True once after the server rejected the saved session; the UI shows a notice and resets it.
  bool get sessionExpired => _sessionExpired;
  void acknowledgeSessionExpired() => _sessionExpired = false;

  AuthProvider() {
    _apiClient.onSessionExpired = _handleSessionExpired;
    // Keep the realtime socket on the current token after each refresh.
    _apiClient.addAccessTokenListener((token) {
      if (token != null && _user != null) SocketService().reconnect(token);
    });
    loadPersistedSession();
  }

  void _handleSessionExpired() {
    if (_user == null) return;
    _user = null;
    _sessionExpired = true;
    SocketService().disconnect();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadPersistedSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.restoreSession();
      if (_apiClient.hasSession) {
        // An expired access token is renewed automatically by ApiClient.
        final response = await _apiClient.get('/api/v1/auth/me');
        if (response != null && response['user'] != null) {
          _user = UserModel.fromJson(response['user']);
          SocketService().connect(_apiClient.accessToken!);
        } else {
          await clearSession();
        }
      }
    } on ApiException catch (e) {
      // Offline at launch: keep the saved session so the next launch can restore it.
      if (e.code != 'NETWORK_ERROR') await clearSession();
    } catch (_) {
      await clearSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );
      if (response != null && response is Map<String, dynamic>) {
        final token = (response['accessToken'] ?? response['token'])?.toString();

        if (response['user'] != null && response['user'] is Map<String, dynamic>) {
          _user = UserModel.fromJson(response['user']);
        }

        if (token != null && token.isNotEmpty) {
          // The refresh token arrives as a cookie on this response; ApiClient has already kept it.
          _apiClient.setTokens(accessToken: token);
          _sessionExpired = false;
          SocketService().connect(token);
        }
        return _user != null && token != null && token.isNotEmpty;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String role,
    String? name,
    String? companyName,
    String? garageName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'role': role,
      };
      if (name != null) body['name'] = name;
      if (companyName != null) body['companyName'] = companyName;
      if (garageName != null) body['garageName'] = garageName;

      final response = await _apiClient.post(
        '/api/v1/auth/register',
        body: body,
        requiresAuth: false,
      );

      if (response != null && response['user'] != null) {
        _user = UserModel.fromJson(response['user']);
        return true;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmail(String email, String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/email/verify',
        body: {'email': email, 'pin': pin},
        requiresAuth: false,
      );

      if (response != null && response['ok'] == true) {
        if (_user != null && _user!.email == email) {
          _user = UserModel(
            id: _user!.id,
            email: _user!.email,
            role: _user!.role,
            name: _user!.name,
            companyName: _user!.companyName,
            garageName: _user!.garageName,
            isEmailVerified: true,
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerification(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/email/resend',
        body: {'email': email},
        requiresAuth: false,
      );
      return response != null && response['ok'] == true;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a time-limited reset link; the link itself is completed on the website.
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiClient.post(
        '/api/v1/auth/password/forgot',
        body: {'email': email},
        requiresAuth: false,
      );
      return true;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.post('/api/v1/auth/logout', requiresAuth: true);
    } catch (_) {}
    await clearSession();
    _isLoading = false;
    notifyListeners();
  }

  /// Permanently deletes the signed-in account (DELETE /api/v1/profile), then signs out.
  /// Throws [ApiException] if the server refuses, leaving the session intact.
  Future<void> deleteAccount() async {
    await _apiClient.delete('/api/v1/profile');
    await clearSession();
    notifyListeners();
  }

  Future<void> clearSession() async {
    _user = null;
    SocketService().disconnect();
    await _apiClient.clearTokens();
  }
}
