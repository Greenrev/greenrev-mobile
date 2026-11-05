import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../state/auth_provider.dart';

/// Counts this device once per day for DAU / WAU / MAU (and again when the user signs
/// in, so the day is attributed to their account). Sends only a random device ID.
class VisitTracker with WidgetsBindingObserver {
  VisitTracker._();
  static final instance = VisitTracker._();

  static const _idKey = 'greenrev_visitor_id';
  static const _sentKey = 'greenrev_visit_sent';
  AuthProvider? _auth;
  bool _sending = false;

  /// Anonymous, random per-install ID — also lets guests on a shared mobile IP have their
  /// own AI concierge allowance.
  static Future<String> visitorId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_idKey);
    if (existing != null && RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(existing)) return existing;
    final rng = Random.secure();
    final id = List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_idKey, id);
    return id;
  }

  /// Lagos calendar day (UTC+1), matching the server.
  static String lagosDay([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().add(const Duration(hours: 1)).toIso8601String().substring(0, 10);

  static String get _platform => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

  void start(AuthProvider auth) {
    if (_auth != null) return;
    _auth = auth;
    WidgetsBinding.instance.addObserver(this);
    auth.addListener(ping);
    ping();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ping();
  }

  Future<void> ping() async {
    final auth = _auth;
    if (auth == null || auth.isLoading || _sending) return;
    _sending = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stamp = '${lagosDay()}|${auth.user?.id ?? 'guest'}';
      if (prefs.getString(_sentKey) == stamp) return;
      await ApiClient().post('/api/v1/analytics/visit', body: {'visitorId': await visitorId(), 'platform': _platform});
      await prefs.setString(_sentKey, stamp);
    } catch (_) {
      // Offline or server down: try again next time the app opens.
    } finally {
      _sending = false;
    }
  }
}
