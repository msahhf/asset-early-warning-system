/// Sensör okuma modeli
class SensorReading {
  final int mq2Value;
  final double temperature;
  final double humidity;
  final double batteryPercent;
  final GasStatus gasStatus;
  final DateTime timestamp;

  const SensorReading({
    required this.mq2Value,
    required this.temperature,
    required this.humidity,
    required this.batteryPercent,
    required this.gasStatus,
    required this.timestamp,
  });

  /// MQ-2 değerine göre durum
  static GasStatus getGasStatus(int mq2) {
    if (mq2 >= 2500) return GasStatus.danger;
    if (mq2 >= 1500) return GasStatus.warning;
    return GasStatus.safe;
  }
}

enum GasStatus {
  safe,
  warning,
  danger;

  String get label {
    switch (this) {
      case GasStatus.safe:
        return 'Güvenli';
      case GasStatus.warning:
        return 'Uyarı';
      case GasStatus.danger:
        return 'Tehlike';
    }
  }
}
