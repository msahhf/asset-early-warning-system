/// BLE sabitleri — Deneyap Kart firmware'deki UUID'ler ile eşleşmelidir
class BleConstants {
  BleConstants._();

  /// BLE Servis UUID
  static const String serviceUUID = '12345678-1234-5678-1234-56789abcdef0';

  /// Wi-Fi SSID yazma karakteristiği
  static const String ssidCharUUID = '12345678-1234-5678-1234-56789abcdef1';

  /// Wi-Fi şifre yazma karakteristiği
  static const String passCharUUID = '12345678-1234-5678-1234-56789abcdef2';

  /// Durum bildirimi karakteristiği (Notify)
  static const String statusCharUUID = '12345678-1234-5678-1234-56789abcdef3';

  /// BLE tarama süresi
  static const Duration scanTimeout = Duration(seconds: 6);

  /// Cihaz adı prefix'i
  static const String deviceNamePrefix = 'ASSET-';
}
