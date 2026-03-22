import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  static const String _tokenKey = 'auth_token';
  
  Future<bool> login(String email, String password) async {
    // TODO: Gerçek HTTP isteği (Backend API)
    await Future.delayed(const Duration(seconds: 1)); // Mock Network Request
    
    // Rastgele başarılı sayıp Mock JWT kaydediyoruz
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}');
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    // TODO: Gerçek HTTP isteği (Backend API)
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
