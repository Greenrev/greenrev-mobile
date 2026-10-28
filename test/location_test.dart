import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:greenrev_mobile/core/network/api_client.dart';
import 'package:greenrev_mobile/core/network/token_store.dart';
import 'package:greenrev_mobile/core/utils/location.dart';

void main() {
  test('distanceKm and formatKm', () {
    // Lekki Phase 1 -> Ikeja is about 21 km as the crow flies.
    final d = distanceKm(6.4474, 3.4723, 6.6018, 3.3515);
    expect(d, closeTo(21.6, 1.5));
    expect(formatKm(0.4), '< 1 km');
    expect(formatKm(4.26), '4.3 km');
    expect(formatKm(21.6), '22 km');
  });

  test('ApiClient.patch sends a JSON PATCH with the access token', () async {
    late http.Request seen;
    final api = ApiClient()
      ..configureForTesting(
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode({'success': true, 'data': {'ok': true}}), 200,
              headers: {'content-type': 'application/json'});
        }),
        store: InMemoryTokenStore(),
      )
      ..setTokens(accessToken: 'tok');
    final res = await api.patch('/api/v1/mechanic/location', body: {'lat': 6.4, 'lng': 3.4});
    expect(res, {'ok': true});
    expect(seen.method, 'PATCH');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body), {'lat': 6.4, 'lng': 3.4});
  });
}
