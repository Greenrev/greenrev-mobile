import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../network/api_client.dart';
import 'visit_tracker.dart';

class ConciergeMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const ConciergeMessage(this.role, this.content);
}

/// A concierge request the server refused or couldn't finish. [message] is safe to show.
class ConciergeException implements Exception {
  final String code;
  final String message;
  const ConciergeException(this.code, this.message);

  /// AI is switched off or misconfigured on the server — retrying won't help.
  bool get offline =>
      code == 'AI_NOT_CONFIGURED' ||
      code == 'AI_KEY_INVALID' ||
      code == 'AI_OUT_OF_CREDIT';

  @override
  String toString() => 'ConciergeException($code: $message)';
}

/// Streams replies from the server's AI concierge (`POST /api/v1/ai/concierge`).
/// Yields the accumulated text so far. The server builds the AI context itself, so
/// only the conversation and the IDs of the cars being compared are sent.
class ConciergeService {
  static final ConciergeService _instance = ConciergeService._internal();
  factory ConciergeService() => _instance;
  ConciergeService._internal();

  /// Swappable for tests.
  http.Client Function() clientFactory = http.Client.new;

  Stream<String> ask(
    List<ConciergeMessage> history, {
    List<String> compareIds = const [],
  }) async* {
    final client = clientFactory();
    try {
      // Lets guests on a shared mobile IP have their own message allowance.
      final visitorId = await VisitTracker.visitorId();
      final token = ApiClient().accessToken;
      final request =
          http.Request(
              'POST',
              Uri.parse('${Env.apiBaseUrl}/api/v1/ai/concierge'),
            )
            ..headers['Content-Type'] = 'application/json'
            ..headers['Accept'] = 'text/event-stream'
            ..body = jsonEncode({
              'messages': [
                for (final m in history) {'role': m.role, 'content': m.content},
              ],
              'compareIds': compareIds,
              'visitorId': visitorId,
            });
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final http.StreamedResponse response;
      try {
        response = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        throw const ConciergeException(
          'AI_TIMEOUT',
          'The concierge took too long to respond. Please try again.',
        );
      } catch (_) {
        throw const ConciergeException(
          'NETWORK_ERROR',
          "Can't reach GreenRev right now. Check your connection.",
        );
      }

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        var code = 'AI_FAILED';
        var message = 'The concierge couldn\'t answer that. Please try again.';
        try {
          final error = (jsonDecode(body) as Map)['error'] as Map;
          code = '${error['code'] ?? code}';
          message = '${error['message'] ?? message}';
        } catch (_) {}
        throw ConciergeException(code, message);
      }

      var fullText = '';
      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // keep the incomplete line
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          Map<String, dynamic> event;
          try {
            event = jsonDecode(line.substring(6)) as Map<String, dynamic>;
          } catch (_) {
            continue; // ignore malformed lines
          }
          if (event['type'] == 'delta' && event['text'] is String) {
            fullText += event['text'] as String;
            yield fullText;
          } else if (event['type'] == 'error') {
            throw ConciergeException(
              '${event['code'] ?? 'AI_FAILED'}',
              '${event['message'] ?? 'The concierge stopped responding. Please try again.'}',
            );
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
