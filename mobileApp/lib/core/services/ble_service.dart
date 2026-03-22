import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';

/// BLE provisioning durumları
enum BleProvisioningStatus {
  idle,
  scanning,
  found,
  connecting,
  connected,
  discoveringServices,
  sendingCredentials,
  waitingResponse,
  success,
  failed,
}

/// BLE Provisioning servisi — Deneyap Kart ile iletişim
class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passChar;
  BluetoothCharacteristic? _statusChar;

  final _statusController = StreamController<BleProvisioningStatus>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  Stream<BleProvisioningStatus> get statusStream => _statusController.stream;
  Stream<String> get messageStream => _messageController.stream;

  // ── Tarama ──────────────────────────────────────────

  Future<List<ScanResult>> scanForDevices() async {
    _statusController.add(BleProvisioningStatus.scanning);
    _messageController.add('ASSET cihazları aranıyor...');

    final results = <ScanResult>[];

    // Tarama başlat
    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.serviceUUID)],
      timeout: BleConstants.scanTimeout,
    );

    // Sonuçları dinle
    final subscription = FlutterBluePlus.onScanResults.listen((scanResults) {
      for (final result in scanResults) {
        if (!results.any((e) => e.device.remoteId == result.device.remoteId)) {
          results.add(result);
        }
      }
    });

    // Tarama süresini bekle
    await Future.delayed(BleConstants.scanTimeout + const Duration(seconds: 1));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    if (results.isNotEmpty) {
      _statusController.add(BleProvisioningStatus.found);
      _messageController.add('${results.length} cihaz bulundu.');
    } else {
      _messageController.add('Cihaz bulunamadı.');
      _statusController.add(BleProvisioningStatus.idle);
    }

    return results;
  }

  // ── Provisioning ───────────────────────────────────

  Future<void> provision({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    try {
      _device = device;

      // 1. Bağlan
      _statusController.add(BleProvisioningStatus.connecting);
      _messageController.add('Cihaza bağlanılıyor...');
      await device.connect(timeout: const Duration(seconds: 15));

      _statusController.add(BleProvisioningStatus.connected);
      _messageController.add('Bağlandı. Servisler keşfediliyor...');

      // 2. Servisleri keşfet
      _statusController.add(BleProvisioningStatus.discoveringServices);
      final services = await device.discoverServices();

      final assetService = services.firstWhere(
        (s) => s.serviceUuid == Guid(BleConstants.serviceUUID),
        orElse: () => throw Exception('ASSET BLE servisi bulunamadı.'),
      );

      // 3. Karakteristikleri bul
      for (final char in assetService.characteristics) {
        final uuid = char.characteristicUuid.toString().toLowerCase();
        if (uuid == BleConstants.ssidCharUUID.toLowerCase()) {
          _ssidChar = char;
        } else if (uuid == BleConstants.passCharUUID.toLowerCase()) {
          _passChar = char;
        } else if (uuid == BleConstants.statusCharUUID.toLowerCase()) {
          _statusChar = char;
        }
      }

      if (_ssidChar == null || _passChar == null || _statusChar == null) {
        throw Exception('BLE karakteristikleri bulunamadı.');
      }

      // 4. Status notify'a abone ol
      await _statusChar!.setNotifyValue(true);

      final completer = Completer<String>();

      _statusChar!.onValueReceived.listen((value) {
        final msg = String.fromCharCodes(value);
        _messageController.add(msg);

        if (msg.startsWith('CONNECTED:') && !completer.isCompleted) {
          completer.complete(msg);
        } else if (msg == 'FAILED' && !completer.isCompleted) {
          completer.completeError('Wi-Fi bağlantısı başarısız.');
        }
      });

      // 5. Wi-Fi bilgilerini gönder
      _statusController.add(BleProvisioningStatus.sendingCredentials);
      _messageController.add('Wi-Fi bilgileri gönderiliyor...');

      await _ssidChar!.write(ssid.codeUnits, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 300));
      await _passChar!.write(password.codeUnits, withoutResponse: false);

      // 6. Cihaz yanıtını bekle
      _statusController.add(BleProvisioningStatus.waitingResponse);
      _messageController.add('Cihaz Wi-Fi\'ye bağlanmayı deniyor...');

      final result = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Cihaz yanıt vermedi.'),
      );

      // Başarılı
      _statusController.add(BleProvisioningStatus.success);
      final ip = result.replaceFirst('CONNECTED:', '');
      _messageController.add('Cihaz bağlandı! IP: $ip');
    } catch (e) {
      _statusController.add(BleProvisioningStatus.failed);
      _messageController.add('Hata: ${e.toString()}');
      rethrow;
    } finally {
      await disconnect();
    }
  }

  // ── Bağlantı Kesme ─────────────────────────────────

  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _ssidChar = null;
    _passChar = null;
    _statusChar = null;
  }

  void dispose() {
    _statusController.close();
    _messageController.close();
  }
}
