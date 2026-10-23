import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the session tokens live between launches.
abstract class TokenStore {
  Future<(String? access, String? refresh)> read();
  Future<void> write({String? access, String? refresh});
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed storage (Android).
class SecureTokenStore implements TokenStore {
  static const _accessKey = 'gr_access_token';
  static const _refreshKey = 'gr_refresh_token';
  // Where older app versions kept the access token in plain text.
  static const _legacyPrefsKey = 'access_token';

  final FlutterSecureStorage _storage;
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<(String?, String?)> read() async {
    try {
      return await _read().timeout(const Duration(seconds: 5));
    } catch (_) {
      // A stalled keychain must not block app start; continue signed out.
      return (null, null);
    }
  }

  Future<(String?, String?)> _read() async {
    try {
      var access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);

      // One-time migration out of SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPrefsKey);
      if (legacy != null) {
        if (access == null) {
          access = legacy;
          await _storage.write(key: _accessKey, value: legacy);
        }
        await prefs.remove(_legacyPrefsKey);
      }
      return (access, refresh);
    } catch (_) {
      return (null, null);
    }
  }

  @override
  Future<void> write({String? access, String? refresh}) async {
    try {
      await _put(_accessKey, access);
      await _put(_refreshKey, refresh);
    } catch (_) {
      // Storage unavailable: the session still works for this launch.
    }
  }

  Future<void> _put(String key, String? value) =>
      value == null ? _storage.delete(key: key) : _storage.write(key: key, value: value);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyPrefsKey);
    } catch (_) {}
  }
}

/// For tests.
class InMemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;
  InMemoryTokenStore({this.access, this.refresh});

  @override
  Future<(String?, String?)> read() async => (access, refresh);

  @override
  Future<void> write({String? access, String? refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
