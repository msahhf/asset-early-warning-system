/// Alarm modeli — JSON serialize desteği + sensör snapshot
class AlertModel {
  final String id;
  final String deviceName;
  final AlertType type;
  final String message;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final SensorSnapshot? snapshot;

  const AlertModel({
    required this.id,
    required this.deviceName,
    required this.type,
    required this.message,
    required this.createdAt,
    this.resolvedAt,
    this.snapshot,
  });

  bool get isActive => resolvedAt == null;

  /// Süre hesapla (oluşma → çözüm)
  Duration? get duration => resolvedAt?.difference(createdAt);

  /// JSON dönüşümleri (local storage için)
  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceName': deviceName,
        'type': type.name,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'snapshot': snapshot?.toJson(),
      };

  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
        id: json['id'] as String,
        deviceName: json['deviceName'] as String,
        type: AlertType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AlertType.fire,
        ),
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
        snapshot: json['snapshot'] != null
            ? SensorSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>)
            : null,
      );
}

/// O anki sensör değerlerinin snapshot'ı
class SensorSnapshot {
  final int mq2Value;
  final double temperature;
  final double humidity;
  final double batteryPercent;

  const SensorSnapshot({
    required this.mq2Value,
    required this.temperature,
    required this.humidity,
    required this.batteryPercent,
  });

  Map<String, dynamic> toJson() => {
        'mq2Value': mq2Value,
        'temperature': temperature,
        'humidity': humidity,
        'batteryPercent': batteryPercent,
      };

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) => SensorSnapshot(
        mq2Value: json['mq2Value'] as int,
        temperature: (json['temperature'] as num).toDouble(),
        humidity: (json['humidity'] as num).toDouble(),
        batteryPercent: (json['batteryPercent'] as num).toDouble(),
      );
}

enum AlertType {
  fire,
  gas,
  offline,
  lowBattery;

  String get label {
    switch (this) {
      case AlertType.fire:
        return 'Yangın';
      case AlertType.gas:
        return 'Gaz Sızıntısı';
      case AlertType.offline:
        return 'Bağlantı Koptu';
      case AlertType.lowBattery:
        return 'Düşük Pil';
    }
  }

  String get emoji {
    switch (this) {
      case AlertType.fire:
        return '🔥';
      case AlertType.gas:
        return '💨';
      case AlertType.offline:
        return '📡';
      case AlertType.lowBattery:
        return '🔋';
    }
  }

  String get description {
    switch (this) {
      case AlertType.fire:
        return 'MQ-2 sensörü tehlikeli duman seviyesi ve DHT22 sıcaklık artışı algıladı. Çift doğrulama ile yangın riski tespit edildi.';
      case AlertType.gas:
        return 'MQ-2 sensörü uyarı eşiğinin üzerinde gaz seviyesi algıladı. Ortam havalandırması kontrol edilmeli.';
      case AlertType.offline:
        return 'Cihaz 90 saniye boyunca heartbeat sinyali göndermedi. Bağlantı veya güç sorunu olabilir.';
      case AlertType.lowBattery:
        return 'UPS pil seviyesi %15\'in altına düştü. Şarj kaynağını kontrol edin.';
    }
  }
}
