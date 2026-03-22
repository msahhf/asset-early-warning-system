import 'dart:async';
import 'dart:math';
import '../../features/dashboard/models/device_model.dart';
import '../../features/dashboard/models/sensor_reading.dart';
import '../../features/dashboard/models/alert_model.dart';

/// Mock data servisi — backend olmadan test için gerçekçi veri üretir
class MockDataService {
  static final _random = Random();

  Timer? _timer;
  final _sensorController = StreamController<SensorReading>.broadcast();
  Stream<SensorReading> get sensorStream => _sensorController.stream;

  // Sahte baseline değerler (gerçekçi salınım için)
  double _baseMq2 = 350;
  double _baseTemp = 23.5;
  double _baseHumidity = 55.0;
  double _baseBattery = 87.0;

  /// Sahte cihaz
  DeviceModel getMockDevice() {
    return DeviceModel(
      id: '507f1f77bcf86cd799439011',
      deviceId: '25d607fe-e954-452a-b967-fcc870cd4d19',
      name: 'ASSET-α3f2',
      location: 'Oturma Odası',
      isOnline: true,
      hasActiveAlert: false,
      batteryLevel: _baseBattery,
      firmwareVersion: '1.0.0',
      lastHeartbeat: DateTime.now(),
    );
  }

  /// Sahte alarm geçmişi
  List<AlertModel> getMockAlerts() {
    final now = DateTime.now();
    return [
      AlertModel(
        id: 'alert-001',
        deviceName: 'ASSET-α3f2',
        type: AlertType.fire,
        message: 'Duman seviyesi kritik! MQ-2: 2847',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 13)),
        resolvedAt: now.subtract(const Duration(hours: 2, minutes: 8)),
        snapshot: const SensorSnapshot(
            mq2Value: 2847,
            temperature: 42.3,
            humidity: 38.0,
            batteryPercent: 82.0),
      ),
      AlertModel(
        id: 'alert-002',
        deviceName: 'ASSET-α3f2',
        type: AlertType.offline,
        message: 'Cihaz bağlantısı kesildi (90sn timeout)',
        createdAt: now.subtract(const Duration(hours: 5, minutes: 41)),
        resolvedAt: now.subtract(const Duration(hours: 5, minutes: 38)),
        snapshot: const SensorSnapshot(
            mq2Value: 310,
            temperature: 22.1,
            humidity: 55.0,
            batteryPercent: 76.0),
      ),
      AlertModel(
        id: 'alert-003',
        deviceName: 'ASSET-α3f2',
        type: AlertType.gas,
        message: 'Gaz seviyesi uyarı eşiğinde: MQ-2: 1623',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        resolvedAt:
            now.subtract(const Duration(days: 1, hours: 2, minutes: 55)),
        snapshot: const SensorSnapshot(
            mq2Value: 1623,
            temperature: 26.8,
            humidity: 48.0,
            batteryPercent: 91.0),
      ),
      AlertModel(
        id: 'alert-004',
        deviceName: 'ASSET-α3f2',
        type: AlertType.lowBattery,
        message: 'Pil seviyesi düşük: %12',
        createdAt: now.subtract(const Duration(days: 2)),
        resolvedAt: now.subtract(const Duration(days: 1, hours: 23)),
        snapshot: const SensorSnapshot(
            mq2Value: 280,
            temperature: 21.5,
            humidity: 60.0,
            batteryPercent: 12.0),
      ),
    ];
  }

  /// Anlık okuma üret
  SensorReading _generateReading() {
    // Küçük rastgele salınım
    _baseMq2 += (_random.nextDouble() - 0.48) * 60;
    _baseMq2 = _baseMq2.clamp(150, 800);

    _baseTemp += (_random.nextDouble() - 0.5) * 0.4;
    _baseTemp = _baseTemp.clamp(18, 35);

    _baseHumidity += (_random.nextDouble() - 0.5) * 1.5;
    _baseHumidity = _baseHumidity.clamp(30, 80);

    _baseBattery -= _random.nextDouble() * 0.03;
    _baseBattery = _baseBattery.clamp(5, 100);

    // Nadiren yüksek spike (test amaçlı)
    int mq2 = _baseMq2.round();
    if (_random.nextDouble() > 0.95) {
      mq2 = 1500 + _random.nextInt(1500); // Spike
    }

    return SensorReading(
      mq2Value: mq2,
      temperature: double.parse(_baseTemp.toStringAsFixed(1)),
      humidity: double.parse(_baseHumidity.toStringAsFixed(1)),
      batteryPercent: double.parse(_baseBattery.toStringAsFixed(1)),
      gasStatus: SensorReading.getGasStatus(mq2),
      timestamp: DateTime.now(),
    );
  }

  /// İlk 20 geçmiş veri noktası (grafik için)
  List<SensorReading> getInitialHistory() {
    final history = <SensorReading>[];
    final now = DateTime.now();
    for (int i = 19; i >= 0; i--) {
      _baseMq2 += (_random.nextDouble() - 0.48) * 40;
      _baseMq2 = _baseMq2.clamp(150, 800);
      _baseTemp += (_random.nextDouble() - 0.5) * 0.3;
      _baseTemp = _baseTemp.clamp(18, 35);

      history.add(SensorReading(
        mq2Value: _baseMq2.round(),
        temperature: double.parse(_baseTemp.toStringAsFixed(1)),
        humidity: double.parse(
            (_baseHumidity + (_random.nextDouble() - 0.5) * 2)
                .clamp(30, 80)
                .toStringAsFixed(1)),
        batteryPercent: double.parse(
            (_baseBattery + i * 0.02).clamp(5, 100).toStringAsFixed(1)),
        gasStatus: SensorReading.getGasStatus(_baseMq2.round()),
        timestamp: now.subtract(Duration(seconds: i * 5)),
      ));
    }
    return history;
  }

  /// 5 saniyede bir yeni veri üretmeye başla
  void startStreaming() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sensorController.add(_generateReading());
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
