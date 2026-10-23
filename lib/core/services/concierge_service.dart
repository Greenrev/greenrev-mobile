import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class ConciergeMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const ConciergeMessage(this.role, this.content);
}

/// Streams replies from the website's AI concierge (`POST /api/chat`), the same
/// endpoint the web Compare Concierge uses. Yields the accumulated text so far.
class ConciergeService {
  static final ConciergeService _instance = ConciergeService._internal();
  factory ConciergeService() => _instance;
  ConciergeService._internal();

  Stream<String> ask(
    List<ConciergeMessage> history, {
    List<Map<String, dynamic>>? compareData,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('${Env.siteBaseUrl}/api/chat'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'messages': [
            for (var i = 0; i < history.length; i++)
              {
                'id': 'msg-$i',
                'role': history[i].role,
                'content': history[i].content,
                'parts': [
                  {'type': 'text', 'text': history[i].content},
                ],
              },
          ],
          'compareData': compareData ?? const [],
        });

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      var fullText = '';
      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // keep the incomplete line
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final raw = line.substring(6).trim();
          if (raw == '[DONE]') continue;
          Map<String, dynamic> parsed;
          try {
            parsed = jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            continue; // ignore malformed lines
          }
          if (parsed['type'] == 'text-delta' && parsed['delta'] is String) {
            fullText += parsed['delta'] as String;
            yield fullText;
          } else if (parsed['type'] == 'error') {
            throw Exception(parsed['errorText'] ?? 'AI returned an error');
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
