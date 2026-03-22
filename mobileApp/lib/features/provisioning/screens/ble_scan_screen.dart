import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/asset_button.dart';
import '../providers/provisioning_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/scanning_animation.dart';

/// BLE Tarama ekranı — cihaz keşfi
class BleScanScreen extends ConsumerStatefulWidget {
  const BleScanScreen({super.key});

  @override
  ConsumerState<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends ConsumerState<BleScanScreen>
    with WidgetsBindingObserver {
  bool _permissionGranted = false;
  bool _bluetoothOn = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ayarlardan dönüldüğünde tekrar kontrol et
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    await _checkBluetooth();
    if (_bluetoothOn) {
      await _requestPermissions();
    }
  }

  /// Bluetooth adaptör durumunu kontrol et
  Future<void> _checkBluetooth() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (mounted) {
        setState(() {
          _bluetoothOn = state == BluetoothAdapterState.on;
          if (!_bluetoothOn) {
            _errorMessage = 'bluetooth';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bluetoothOn = false;
          _errorMessage = 'bluetooth';
        });
      }
    }
  }

  /// İzin diyaloglarını göster (ayarlara atmadan)
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses;

    if (Platform.isAndroid) {
      // Tüm BLE izinlerini tek seferde iste
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } else {
      // iOS
      statuses = await [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();
    }

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    // Kalıcı olarak reddedildi mi?
    final permanentlyDenied = statuses.values.any(
      (s) => s.isPermanentlyDenied,
    );

    if (mounted) {
      setState(() {
        _permissionGranted = allGranted;
        if (!allGranted) {
          _errorMessage = permanentlyDenied ? 'permanentlyDenied' : 'denied';
        }
      });

      if (_permissionGranted) {
        _startScan();
      }
    }
  }

  /// Bluetooth'u açmayı iste
  Future<void> _turnOnBluetooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
      // Biraz bekle ve tekrar kontrol et
      await Future.delayed(const Duration(seconds: 1));
      await _initialize();
    } catch (e) {
      // Kullanıcı reddetti
    }
  }

  void _startScan() {
    ref.read(provisioningProvider.notifier).scan();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisioningProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cihaz Bul'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Bluetooth kapalı
              if (!_bluetoothOn) ...[
                _buildBluetoothOffState(),
              ]
              // İzin verilmemiş
              else if (!_permissionGranted) ...[
                _buildPermissionWarning(),
              ]
              // Her şey hazır
              else ...[
                Text(
                  'Yakınınızdaki ASSET cihazlarını\narıyoruz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.bodyColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Radar animasyonu veya boş durum
                if (state.isScanning)
                  const ScanningAnimation()
                else if (state.foundDevices.isEmpty)
                  _buildEmptyState()
                else
                  const SizedBox.shrink(),

                const SizedBox(height: 24),

                // Bulunan cihazlar
                if (state.foundDevices.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bulunan Cihazlar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.hintColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.foundDevices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final result = state.foundDevices[index];
                        final name = result.device.platformName.isEmpty
                            ? 'ASSET Cihaz'
                            : result.device.platformName;
                        final isSelected =
                            state.selectedDevice?.device.remoteId ==
                                result.device.remoteId;

                        return DeviceCard(
                          name: name,
                          rssi: result.rssi,
                          isSelected: isSelected,
                          onTap: () {
                            ref
                                .read(provisioningProvider.notifier)
                                .selectDevice(result);
                          },
                        );
                      },
                    ),
                  ),
                ],

                // Yeniden tara
                if (!state.isScanning && state.foundDevices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _startScan,
                    icon: Icon(Icons.refresh_rounded,
                        color: AppTheme.accent, size: 18),
                    label: Text(
                      'Yeniden Tara',
                      style: TextStyle(
                          color: AppTheme.accent, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],

              const Spacer(),

              // Devam butonu
              if (_permissionGranted && _bluetoothOn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: AssetButton(
                    label: 'Devam',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: state.selectedDevice != null
                        ? () => context.go('/wifi-config')
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bluetooth kapalı durumu
  Widget _buildBluetoothOffState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.bluetooth_disabled_rounded,
                color: Color(0xFF007AFF),
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth Kapalı',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cihaz taraması için\nBluetooth\'u açmanız gerekiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.bodyColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            AssetButton(
              label: 'Bluetooth\'u Aç',
              icon: Icons.bluetooth_rounded,
              onPressed: _turnOnBluetooth,
            ),
          ],
        ),
      ),
    );
  }

  /// İzin verilmemiş durumu
  Widget _buildPermissionWarning() {
    final isPermanent = _errorMessage == 'permanentlyDenied';

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppTheme.warning,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'İzin Gerekli',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isPermanent
                  ? 'İzinler kalıcı olarak reddedildi.\nAyarlardan manuel olarak açmanız gerekiyor.'
                  : 'Cihaz taraması için Bluetooth ve\nKonum izinleri gereklidir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.bodyColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            AssetButton(
              label: isPermanent ? 'Ayarlara Git' : 'İzin Ver',
              icon: isPermanent
                  ? Icons.settings_rounded
                  : Icons.check_circle_outline_rounded,
              onPressed:
                  isPermanent ? () => openAppSettings() : _requestPermissions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.bluetooth_searching_rounded,
            color: AppTheme.hintColor,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Cihaz bulunamadı',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.titleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cihazın açık olduğundan ve\nBLE modunda beklediğinden emin olun.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.bodyColor,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        AssetButton(
          label: 'Tekrar Ara',
          icon: Icons.refresh_rounded,
          outlined: true,
          onPressed: _startScan,
        ),
      ],
    );
  }
}
