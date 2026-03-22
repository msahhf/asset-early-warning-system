import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ble_service.dart';
import '../../../core/services/local_storage_service.dart';

// ── State ────────────────────────────────────────────

class ProvisioningState {
  final BleProvisioningStatus status;
  final String statusMessage;
  final List<ScanResult> foundDevices;
  final ScanResult? selectedDevice;
  final bool isScanning;
  final bool isProvisioning;

  const ProvisioningState({
    this.status = BleProvisioningStatus.idle,
    this.statusMessage = '',
    this.foundDevices = const [],
    this.selectedDevice,
    this.isScanning = false,
    this.isProvisioning = false,
  });

  ProvisioningState copyWith({
    BleProvisioningStatus? status,
    String? statusMessage,
    List<ScanResult>? foundDevices,
    ScanResult? selectedDevice,
    bool? isScanning,
    bool? isProvisioning,
    bool clearSelection = false,
  }) {
    return ProvisioningState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      foundDevices: foundDevices ?? this.foundDevices,
      selectedDevice:
          clearSelection ? null : (selectedDevice ?? this.selectedDevice),
      isScanning: isScanning ?? this.isScanning,
      isProvisioning: isProvisioning ?? this.isProvisioning,
    );
  }
}

// ── Notifier ─────────────────────────────────────────

class ProvisioningNotifier extends StateNotifier<ProvisioningState> {
  final BleService _bleService;

  ProvisioningNotifier(this._bleService) : super(const ProvisioningState()) {
    _bleService.statusStream.listen((s) {
      state = state.copyWith(status: s);
    });
    _bleService.messageStream.listen((m) {
      state = state.copyWith(statusMessage: m);
    });
  }

  /// BLE tarama başlat
  Future<void> scan() async {
    state = state.copyWith(
      isScanning: true,
      foundDevices: [],
      clearSelection: true,
    );

    try {
      final results = await _bleService.scanForDevices();
      state = state.copyWith(
        foundDevices: results,
        isScanning: false,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        statusMessage: 'Tarama hatası: $e',
      );
    }
  }

  /// Cihaz seç
  void selectDevice(ScanResult device) {
    state = state.copyWith(selectedDevice: device);
  }

  /// Provisioning başlat
  Future<bool> provision(String ssid, String password,
      [String customName = '']) async {
    if (state.selectedDevice == null) return false;

    if (customName.trim().isNotEmpty) {
      await LocalStorageService.saveCustomDeviceName(customName.trim());
    }

    state = state.copyWith(isProvisioning: true);

    try {
      await _bleService.provision(
        device: state.selectedDevice!.device,
        ssid: ssid,
        password: password,
      );
      state = state.copyWith(isProvisioning: false);
      return state.status == BleProvisioningStatus.success;
    } catch (e) {
      state = state.copyWith(isProvisioning: false);
      return false;
    }
  }

  /// Sıfırla
  void reset() {
    state = const ProvisioningState();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────

final provisioningProvider =
    StateNotifierProvider<ProvisioningNotifier, ProvisioningState>((ref) {
  return ProvisioningNotifier(BleService());
});
