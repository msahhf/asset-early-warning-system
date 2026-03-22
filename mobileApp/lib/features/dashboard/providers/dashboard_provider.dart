import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/api_data_service.dart';
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
  final ApiDataService _apiService;
  StreamSubscription<SensorReading>? _subscription;

  static const int maxHistory = 20;

  DashboardNotifier(this._apiService) : super(const DashboardState()) {
    _init();
  }

  Future<void> _init() async {
    final allDevices = await _apiService.getMyDevices();
    final alerts = await _apiService.getMyAlerts();

    if (allDevices.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final effectiveDevice = allDevices.first;
    _apiService.setActiveDevice(effectiveDevice.id);
    
    final history = await _apiService.getDeviceHistory(effectiveDevice.id);

    state = state.copyWith(
      device: effectiveDevice,
      allDevices: allDevices,
      alerts: alerts,
      history: history,
      currentReading: history.isNotEmpty ? history.first : null,
      isLoading: false,
    );

    _subscription = _apiService.sensorStream.listen((reading) {
      final updatedHistory = [reading, ...state.history];
      if (updatedHistory.length > maxHistory) {
        updatedHistory.removeLast();
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

    _apiService.startStreaming();
  }

  Future<void> addAlert(AlertModel alert) async {
    final updatedAlerts = [alert, ...state.alerts];
    state = state.copyWith(alerts: updatedAlerts);
    await LocalStorageService.saveAlert(alert);
  }

  void switchDevice(String deviceId) async {
    if (state.allDevices.isEmpty) return;
    final target = state.allDevices.firstWhere((d) => d.deviceId == deviceId, orElse: () => state.device!);
    
    state = state.copyWith(isLoading: true);
    
    _apiService.setActiveDevice(target.id);
    final history = await _apiService.getDeviceHistory(target.id);
    final alerts = await _apiService.getMyAlerts();
    final deviceAlerts = alerts.where((a) => a.deviceName == target.name).toList();
    
    state = state.copyWith(
      device: target,
      history: history,
      currentReading: history.isNotEmpty ? history.first : null,
      alerts: deviceAlerts,
      isLoading: false,
    );
  }

  void clearAlerts() {
    state = state.copyWith(alerts: []);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _apiService.dispose();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ApiDataService());
});
