import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenrev_mobile/core/state/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AuthProvider Tests', () {
    test('Initial auth state is logged out', () {
      final auth = AuthProvider();
      expect(auth.isLoggedIn, false);
      expect(auth.user, null);
      expect(auth.token, null);
    });

    test('Session clear resets tokens and user data', () async {
      final auth = AuthProvider();
      await auth.clearSession();
      expect(auth.isLoggedIn, false);
      expect(auth.token, null);
      expect(auth.user, null);
    });
  });
}
