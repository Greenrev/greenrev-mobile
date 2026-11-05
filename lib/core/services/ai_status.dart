import '../network/api_client.dart';

/// Whether the server's AI features are usable right now (GET /api/v1/ai/status).
/// Cached for five minutes; if the check itself fails, assume available — the real
/// request will explain any problem.
class AiStatus {
  static ({DateTime at, bool available})? _cache;

  static const offlineMessage =
      'AI features are offline right now. Everything else works as normal.';

  static Future<bool> available() async {
    final c = _cache;
    if (c != null &&
        DateTime.now().difference(c.at) < const Duration(minutes: 5)) {
      return c.available;
    }
    try {
      final data = await ApiClient().get(
        '/api/v1/ai/status',
        requiresAuth: false,
      );
      final ok = (data as Map)['available'] != false;
      _cache = (at: DateTime.now(), available: ok);
      return ok;
    } catch (_) {
      return true;
    }
  }

  /// Call when a request reports AI as offline, so other screens update immediately.
  static void markOffline() => _cache = (at: DateTime.now(), available: false);
}
