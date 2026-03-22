import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dashboard/models/device_model.dart';
import '../../features/dashboard/models/sensor_reading.dart';
import '../../features/dashboard/models/alert_model.dart';

/// Gerçek backend API'si üzerinden cihaz verilerini besleyen servis
class ApiDataService {
  final String baseUrl = Platform.isAndroid ? 'http://10.0.2.2:5000/api' : 'http://localhost:5000/api';
  
  Timer? _timer;
  final _sensorController = StreamController<SensorReading>.broadcast();
  Stream<SensorReading> get sensorStream => _sensorController.stream;
  String? _activeDeviceObjId; // MongoDB ObjectId _id

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Kullanıcının cihazlarını getirir
  Future<List<DeviceModel>> getMyDevices() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/devices'), headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List;
        return data.map((d) => DeviceModel(
          id: d['_id'],
          deviceId: d['deviceId'],
          name: d['name'],
          location: d['location'] ?? 'Belirtilmedi',
          isOnline: d['isOnline'],
          hasActiveAlert: d['hasActiveAlert'],
          batteryLevel: (d['batteryLevel'] ?? 0).toDouble(),
          firmwareVersion: d['firmwareVersion'] ?? '1.0.0',
          lastHeartbeat: d['lastHeartbeat'] != null ? DateTime.parse(d['lastHeartbeat']) : null,
        )).toList();
      }
    } catch (e) {
      print("getMyDevices Hata: $e");
    }
    return [];
  }

  /// Tüm cihazlardaki alarm geçmişini getirir
  Future<List<AlertModel>> getMyAlerts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/alerts'), headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List;
        return data.map((a) {
           final deviceName = a['device'] != null ? a['device']['name'] : 'Bilinmiyor';
           return AlertModel(
             id: a['_id'],
             deviceName: deviceName,
             type: _mapType(a['type']),
             message: a['message'],
             createdAt: DateTime.parse(a['createdAt']),
             resolvedAt: a['resolvedAt'] != null ? DateTime.parse(a['resolvedAt']) : null,
             snapshot: SensorSnapshot(
                 mq2Value: (a['sensorSnapshot']?['mq2Value'] ?? 0).toInt(),
                 temperature: (a['sensorSnapshot']?['temperature'] ?? 0.0).toDouble(),
                 humidity: (a['sensorSnapshot']?['humidity'] ?? 0.0).toDouble(),
                 batteryPercent: 100.0,
             ),
           );
        }).toList();
      }
    } catch(e) { 
        print("getMyAlerts Hata: $e");
    }
    return [];
  }

  AlertType _mapType(String type) {
    if (type == 'fire') return AlertType.fire;
    if (type == 'gas_warning') return AlertType.gas;
    if (type == 'offline') return AlertType.offline;
    if (type == 'lowBattery') return AlertType.lowBattery;
    return AlertType.gas;
  }

  /// Seçilen cihazın tüm sensör log geçmişini çeker
  Future<List<SensorReading>> getDeviceHistory(String deviceObjId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/devices/$deviceObjId/history'), headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List;
        return data.map((d) => _parseReading(d)).toList();
      }
    } catch(e) { 
        print("getDeviceHistory Hata: $e");
    }
    return [];
  }

  SensorReading _parseReading(Map<String, dynamic> d) {
      return SensorReading(
          mq2Value: d['mq2Value'] ?? 0,
          temperature: (d['temperature'] ?? 0).toDouble(),
          humidity: (d['humidity'] ?? 0).toDouble(),
          batteryPercent: (d['rawPayload'] != null && d['rawPayload']['batteryLevel'] != null) ? d['rawPayload']['batteryLevel'].toDouble() : 100.0,
          gasStatus: SensorReading.getGasStatus(d['mq2Value'] ?? 0),
          timestamp: DateTime.parse(d['createdAt']),
      );
  }

  void setActiveDevice(String deviceObjId) {
    _activeDeviceObjId = deviceObjId;
  }

  /// 5 saniyede bir polling ile son cihaz durumunu ve sensör logunu çeker
  void startStreaming() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_activeDeviceObjId == null) return;
      try {
        final res = await http.get(Uri.parse('$baseUrl/devices/$_activeDeviceObjId/history'), headers: await _headers());
        if (res.statusCode == 200) {
           final data = jsonDecode(res.body)['data'] as List;
           if (data.isNotEmpty) {
             _sensorController.add(_parseReading(data.first));
           }
        }
      } catch (e) { 
          print("Polling Hata: $e");
      }
    });
  }

  void stopStreaming() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _sensorController.close();
  }
}
