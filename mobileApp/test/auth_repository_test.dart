import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asset_mobile/features/auth/repositories/auth_repository.dart';

void main() {
  group('AuthRepository Tests', () {
    late AuthRepository authRepo;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      authRepo = AuthRepository();
    });

    test('isLoggedIn initially false', () async {
      final isLoggedIn = await authRepo.isLoggedIn();
      expect(isLoggedIn, false);
    });

    test('login saves a token and returns true', () async {
      final success = await authRepo.login('test@asset.com', 'password123');
      expect(success, true);

      final isLoggedIn = await authRepo.isLoggedIn();
      expect(isLoggedIn, true);

      final token = await authRepo.getToken();
      expect(token, isNotNull);
      expect(token!.startsWith('mock_jwt_token_'), true);
    });

    test('logout removes the token', () async {
      // Önce login
      await authRepo.login('user', 'pass');
      expect(await authRepo.isLoggedIn(), true);

      // Sonra logout
      await authRepo.logout();
      expect(await authRepo.isLoggedIn(), false);
      expect(await authRepo.getToken(), isNull);
    });
  });
}
