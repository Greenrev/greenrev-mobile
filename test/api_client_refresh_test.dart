import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:greenrev_mobile/core/network/api_client.dart';
import 'package:greenrev_mobile/core/network/token_store.dart';

http.Response _json(int status, Object body, {Map<String, String> headers = const {}}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

http.Response _unauthorized() =>
    _json(401, {'success': false, 'error': {'code': 'UNAUTHENTICATED', 'message': 'Authentication required'}});

/// Shape of the server's Set-Cookie headers after dart:io joins them with commas.
String _cookies(String access, String refresh) =>
    'access_token=$access; Max-Age=900; Path=/; Expires=Fri, 23 Oct 2026 10:00:00 GMT; HttpOnly, '
    'refresh_token=$refresh; Max-Age=604800; Path=/; Expires=Fri, 30 Oct 2026 10:00:00 GMT; HttpOnly, '
    'csrf_token=csrf123; Path=/';

void main() {
  late ApiClient api;
  late InMemoryTokenStore store;
  late int refreshCalls;
  late List<String?> refreshCookieHeaders;

  /// Fake API: `/me` accepts only [validAccess]; `/refresh` rotates [validRefresh].
  MockClient fakeServer({
    required String Function() validAccess,
    required void Function(String) setAccess,
    required String Function() validRefresh,
    required void Function(String) setRefresh,
    Future<http.Response> Function()? refreshOverride,
  }) {
    return MockClient((req) async {
      if (req.url.path == '/api/v1/auth/refresh') {
        refreshCalls++;
        refreshCookieHeaders.add(req.headers['Cookie']);
        if (refreshOverride != null) return refreshOverride();
        await Future.delayed(const Duration(milliseconds: 20));
        if (req.headers['Cookie'] != 'refresh_token=${validRefresh()}') return _unauthorized();
        final access = 'access-$refreshCalls';
        final refresh = 'refresh-$refreshCalls';
        setAccess(access);
        setRefresh(refresh);
        return _json(200, {'success': true, 'data': {'accessToken': access, 'user': {}}},
            headers: {'set-cookie': _cookies(access, refresh)});
      }
      if (req.url.path == '/api/v1/auth/login') {
        if (jsonDecode(req.body)['password'] != 'right') {
          return _json(401, {'success': false, 'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Invalid credentials'}});
        }
        setAccess('access-login');
        setRefresh('refresh-login');
        return _json(200, {'success': true, 'data': {'accessToken': 'access-login', 'user': {'id': 'u1'}}},
            headers: {'set-cookie': _cookies('access-login', 'refresh-login')});
      }
      if (req.headers['Authorization'] != 'Bearer ${validAccess()}') return _unauthorized();
      return _json(200, {'success': true, 'data': {'user': {'id': 'u1'}}});
    });
  }

  setUp(() {
    refreshCalls = 0;
    refreshCookieHeaders = [];
    api = ApiClient();
  });

  test('login keeps the refresh token from the Set-Cookie header', () async {
    var access = '', refresh = '';
    store = InMemoryTokenStore();
    api.configureForTesting(
      client: fakeServer(
        validAccess: () => access, setAccess: (v) => access = v,
        validRefresh: () => refresh, setRefresh: (v) => refresh = v,
      ),
      store: store,
    );

    final res = await api.post('/api/v1/auth/login', body: {'email': 'a@b.co', 'password': 'right'}, requiresAuth: false);
    api.setTokens(accessToken: res['accessToken']);
    await pumpEventQueue();

    expect(api.refreshToken, 'refresh-login');
    expect(store.access, 'access-login');
    expect(store.refresh, 'refresh-login');
  });

  test('wrong password does not try to refresh', () async {
    var access = '', refresh = 'refresh-0';
    api.configureForTesting(
      client: fakeServer(
        validAccess: () => access, setAccess: (v) => access = v,
        validRefresh: () => refresh, setRefresh: (v) => refresh = v,
      ),
      store: InMemoryTokenStore(),
    );
    api.setTokens(accessToken: 'old', refreshToken: 'refresh-0');

    await expectLater(
      api.post('/api/v1/auth/login', body: {'email': 'a@b.co', 'password': 'wrong'}, requiresAuth: false),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );
    expect(refreshCalls, 0);
  });

  test('expired access token is refreshed and the request retried', () async {
    var access = 'fresh-never-issued', refresh = 'refresh-0';
    store = InMemoryTokenStore();
    api.configureForTesting(
      client: fakeServer(
        validAccess: () => access, setAccess: (v) => access = v,
        validRefresh: () => refresh, setRefresh: (v) => refresh = v,
      ),
      store: store,
    );
    api.setTokens(accessToken: 'expired', refreshToken: 'refresh-0');
    final seen = <String?>[];
    api.addAccessTokenListener(seen.add);

    final me = await api.get('/api/v1/auth/me');
    await pumpEventQueue();

    expect(me['user']['id'], 'u1');
    expect(refreshCalls, 1);
    expect(refreshCookieHeaders.single, 'refresh_token=refresh-0');
    expect(api.accessToken, 'access-1');
    expect(api.refreshToken, 'refresh-1'); // rotated token kept
    expect(store.access, 'access-1');
    expect(store.refresh, 'refresh-1');
    expect(seen, ['access-1']); // socket reconnect hook fires
  });

  test('concurrent 401s share a single refresh', () async {
    var access = 'none', refresh = 'refresh-0';
    api.configureForTesting(
      client: fakeServer(
        validAccess: () => access, setAccess: (v) => access = v,
        validRefresh: () => refresh, setRefresh: (v) => refresh = v,
      ),
      store: InMemoryTokenStore(),
    );
    api.setTokens(accessToken: 'expired', refreshToken: 'refresh-0');

    final results = await Future.wait([
      api.get('/api/v1/auth/me'),
      api.get('/api/v1/auth/me'),
      api.get('/api/v1/auth/me'),
    ]);

    expect(results, hasLength(3));
    expect(refreshCalls, 1);
  });

  test('a rejected refresh token ends the session', () async {
    var access = 'none', refresh = 'refresh-0';
    store = InMemoryTokenStore();
    api.configureForTesting(
      client: fakeServer(
        validAccess: () => access, setAccess: (v) => access = v,
        validRefresh: () => refresh, setRefresh: (v) => refresh = v,
        refreshOverride: () async => _unauthorized(),
      ),
      store: store,
    );
    api.setTokens(accessToken: 'expired', refreshToken: 'revoked');
    var expiredCalls = 0;
    api.onSessionExpired = () => expiredCalls++;

    await expectLater(
      api.get('/api/v1/auth/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expiredCalls, 1);
    expect(api.hasSession, false);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('being offline during refresh keeps the session', () async {
    var access = 'none', refresh = 'refresh-0';
    api.configureForTesting(
      client: fakeServer(
        validAccess: () => access, setAccess: (v) => access = v,
        validRefresh: () => refresh, setRefresh: (v) => refresh = v,
        refreshOverride: () async => throw http.ClientException('offline'),
      ),
      store: InMemoryTokenStore(),
    );
    api.setTokens(accessToken: 'expired', refreshToken: 'refresh-0');
    var expiredCalls = 0;
    api.onSessionExpired = () => expiredCalls++;

    await expectLater(api.get('/api/v1/auth/me'), throwsA(isA<ApiException>()));
    expect(expiredCalls, 0);
    expect(api.refreshToken, 'refresh-0');
  });

  test('tokens restore from storage on launch', () async {
    store = InMemoryTokenStore(access: 'saved-access', refresh: 'saved-refresh');
    api.configureForTesting(client: MockClient((_) async => _unauthorized()), store: store);

    await api.restoreSession();

    expect(api.accessToken, 'saved-access');
    expect(api.refreshToken, 'saved-refresh');
    expect(api.hasSession, true);
  });
}
