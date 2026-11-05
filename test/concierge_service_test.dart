import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenrev_mobile/core/services/concierge_service.dart';

void main() {
  const history = [ConciergeMessage('user', 'Which SUV?')];

  setUp(() => SharedPreferences.setMockInitialValues({'greenrev_visitor_id': 'device-test-0001'}));
  tearDown(() => ConciergeService().clientFactory = http.Client.new);

  test('streams deltas from the server and sends only roles, text and car IDs', () async {
    late Map<String, dynamic> sent;
    ConciergeService().clientFactory = () => MockClient.streaming((req, body) async {
          sent = jsonDecode(await utf8.decodeStream(body)) as Map<String, dynamic>;
          final events = [
            {'type': 'delta', 'text': 'The BYD '},
            {'type': 'delta', 'text': 'Han.'},
            {'type': 'done'},
          ].map((e) => 'data: ${jsonEncode(e)}\n\n').join();
          return http.StreamedResponse(Stream.value(utf8.encode(events)), 200);
        });

    final parts = await ConciergeService().ask(history, compareIds: ['p1']).toList();
    expect(parts, ['The BYD ', 'The BYD Han.']);
    expect(sent, {
      'messages': [
        {'role': 'user', 'content': 'Which SUV?'},
      ],
      'compareIds': ['p1'],
      'visitorId': 'device-test-0001',
    });
  });

  test('turns the server\'s JSON error into a readable ConciergeException', () async {
    ConciergeService().clientFactory = () => MockClient((_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'AI_NOT_CONFIGURED', 'message': "AI features aren't switched on yet."},
          }),
          503,
        ));
    await expectLater(
      ConciergeService().ask(history).toList(),
      throwsA(isA<ConciergeException>()
          .having((e) => e.offline, 'offline', isTrue)
          .having((e) => e.message, 'message', "AI features aren't switched on yet.")),
    );
  });

  test('a mid-stream error event surfaces too', () async {
    ConciergeService().clientFactory = () => MockClient.streaming((_, _) async => http.StreamedResponse(
          Stream.value(utf8.encode('data: ${jsonEncode({'type': 'error', 'code': 'AI_FAILED', 'message': 'Try again.'})}\n\n')),
          200,
        ));
    await expectLater(
      ConciergeService().ask(history).toList(),
      throwsA(isA<ConciergeException>().having((e) => e.offline, 'offline', isFalse)),
    );
  });
}
