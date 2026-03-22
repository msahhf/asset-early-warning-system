import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dashboard/models/alert_model.dart';

/// Yerel depolama servisi — alarm geçmişini kalıcı saklar
class LocalStorageService {
  static const String _alertsKey = 'asset_alerts_history';
  static const String _customNameKey = 'asset_custom_device_name';
  static const int _maxAlerts = 100;

  /// Tüm alarmları getir
  static Future<List<AlertModel>> getAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_alertsKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tek alarm kaydet (mevcut listeye ekler)
  static Future<void> saveAlert(AlertModel alert) async {
    final alerts = await getAlerts();

    // Aynı ID varsa güncelle, yoksa başa ekle
    final existingIndex = alerts.indexWhere((a) => a.id == alert.id);
    if (existingIndex >= 0) {
      alerts[existingIndex] = alert;
    } else {
      alerts.insert(0, alert);
    }

    // Maksimum sınır
    if (alerts.length > _maxAlerts) {
      alerts.removeRange(_maxAlerts, alerts.length);
    }

    await _persist(alerts);
  }

  /// Toplu alarm kaydet (ilk çalıştırma için)
  static Future<void> saveAlerts(List<AlertModel> alerts) async {
    final existing = await getAlerts();
    if (existing.isEmpty) {
      await _persist(alerts);
    }
  }

  /// ID ile alarm getir
  static Future<AlertModel?> getAlertById(String id) async {
    final alerts = await getAlerts();
    try {
      return alerts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Tüm geçmişi temizle
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_alertsKey);
  }

  /// Dahili: listeyi kaydet
  static Future<void> _persist(List<AlertModel> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(alerts.map((a) => a.toJson()).toList());
    await prefs.setString(_alertsKey, jsonStr);
  }

  // --- CİHAZ ÖZEL ADI ---

  static Future<void> saveCustomDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customNameKey, name);
  }

  static Future<String?> getCustomDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customNameKey);
  }
}
