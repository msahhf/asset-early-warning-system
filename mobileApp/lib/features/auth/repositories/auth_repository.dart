import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  static const String _tokenKey = 'auth_token';
  final String baseUrl = Platform.isAndroid ? 'http://10.0.2.2:5000/api' : 'http://localhost:5000/api';
  
  Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, data['token']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'email': email, 'password': password, 'phone': '05555555555'}));
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, data['token']);
        return true;
      }
    } catch (_) {}
    return false;
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
