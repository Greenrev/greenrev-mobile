import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:greenrev_mobile/core/network/api_client.dart';
import 'package:greenrev_mobile/core/network/token_store.dart';
import 'package:greenrev_mobile/core/state/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('deleteAccount calls DELETE /profile and clears the session', () async {
    final requests = <String>[];
    ApiClient()..configureForTesting(
      client: MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        return json(200, {
          'success': true,
          'data': {'message': 'Account deleted successfully'},
        });
      }),
      store: InMemoryTokenStore(),
    );
    // AuthProvider restores the saved (empty) session on creation; sign in after that.
    final auth = AuthProvider();
    await pumpEventQueue();
    ApiClient().setTokens(accessToken: 'tok', refreshToken: 'ref');

    await auth.deleteAccount();

    expect(requests, ['DELETE /api/v1/profile']);
    expect(ApiClient().hasSession, isFalse);
  });

  test('a failed deletion keeps the user signed in', () async {
    ApiClient()..configureForTesting(
      client: MockClient(
        (_) async => json(500, {
          'success': false,
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Server error'},
        }),
      ),
      store: InMemoryTokenStore(),
    );
    final auth = AuthProvider();
    await pumpEventQueue();
    ApiClient().setTokens(accessToken: 'tok', refreshToken: 'ref');

    await expectLater(auth.deleteAccount(), throwsA(isA<ApiException>()));
    expect(ApiClient().hasSession, isTrue);
  });
}
