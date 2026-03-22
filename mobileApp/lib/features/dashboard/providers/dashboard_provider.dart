import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/mock_data_service.dart';
import '../models/device_model.dart';
import '../models/sensor_reading.dart';
import '../models/alert_model.dart';

// ── State ────────────────────────────────────────────

class DashboardState {
  final DeviceModel? device;
  final List<DeviceModel> allDevices;
  final SensorReading? currentReading;
  final List<SensorReading> history;
  final List<AlertModel> alerts;
  final bool isLoading;

  const DashboardState({
    this.device,
    this.allDevices = const [],
    this.currentReading,
    this.history = const [],
    this.alerts = const [],
    this.isLoading = true,
  });

  DashboardState copyWith({
    DeviceModel? device,
    List<DeviceModel>? allDevices,
    SensorReading? currentReading,
    List<SensorReading>? history,
    List<AlertModel>? alerts,
    bool? isLoading,
  }) {
    return DashboardState(
      device: device ?? this.device,
      allDevices: allDevices ?? this.allDevices,
      currentReading: currentReading ?? this.currentReading,
      history: history ?? this.history,
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ─────────────────────────────────────────

class DashboardNotifier extends StateNotifier<DashboardState> {
  final MockDataService _mockService;
  StreamSubscription<SensorReading>? _subscription;

  static const int maxHistory = 20;

  DashboardNotifier(this._mockService) : super(const DashboardState()) {
    _init();
  }

  Future<void> _init() async {
    // Mock veri yükle
    final device = _mockService.getMockDevice();
    final mockAlerts = _mockService.getMockAlerts();
    final history = _mockService.getInitialHistory();

    // Local storage'dan geçmiş alarmları yükle
    var savedAlerts = await LocalStorageService.getAlerts();
    if (savedAlerts.isEmpty) {
      // İlk çalıştırma: mock alarmları kaydet
      await LocalStorageService.saveAlerts(mockAlerts);
      savedAlerts = mockAlerts;
    }

    // Özel cihaz ismini yükle (varsa BLE adını ez)
    final customName = await LocalStorageService.getCustomDeviceName();
    final effectiveDevice = customName != null && customName.isNotEmpty
        ? device.copyWith(name: customName)
        : device;

    // Çoklu cihaz mock verisi
    final allDevices = [
      effectiveDevice,
      effectiveDevice.copyWith(deviceId: 'mock_2', name: 'Mutfak Sensörü', location: 'Mutfak'),
      effectiveDevice.copyWith(deviceId: 'mock_3', name: 'Yazlık', location: 'Yazlık'),
    ];

    state = state.copyWith(
      device: effectiveDevice,
      allDevices: allDevices,
      alerts: savedAlerts,
      history: history,
      currentReading: history.isNotEmpty ? history.last : null,
      isLoading: false,
    );

    // Canlı veri akışını başlat
    _subscription = _mockService.sensorStream.listen((reading) {
      final updatedHistory = [...state.history, reading];
      if (updatedHistory.length > maxHistory) {
        updatedHistory.removeAt(0);
      }

      state = state.copyWith(
        currentReading: reading,
        history: updatedHistory,
        device: state.device?.copyWith(
          batteryLevel: reading.batteryPercent,
          lastHeartbeat: DateTime.now(),
        ),
      );
    });

    _mockService.startStreaming();
  }

  /// Yeni alarm ekle (demo + gerçek kullanım)
  Future<void> addAlert(AlertModel alert) async {
    final updatedAlerts = [alert, ...state.alerts];
    state = state.copyWith(alerts: updatedAlerts);
    await LocalStorageService.saveAlert(alert);
  }

  /// Cihaz Değiştir
  void switchDevice(String deviceId) {
    if (state.allDevices.isEmpty) return;
    final target = state.allDevices.firstWhere((d) => d.deviceId == deviceId, orElse: () => state.device!);
    state = state.copyWith(
      device: target,
      // Gerçek senaryoda burada geçmiş verileri ve alarmları yeni cihaza göre fetch edersiniz.
      alerts: [], // Cihaz değiştiğinde alarmları temizle (mock davranış)
      history: [], 
    );
  }

  /// Tüm alarmları temizle
  void clearAlerts() {
    state = state.copyWith(alerts: []);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mockService.dispose();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(MockDataService());
});
