/// Cihaz veri modeli
class DeviceModel {
  final String id;
  final String deviceId;
  final String name;
  final String location;
  final bool isOnline;
  final bool hasActiveAlert;
  final double batteryLevel;
  final String firmwareVersion;
  final DateTime? lastHeartbeat;

  const DeviceModel({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.location,
    this.isOnline = false,
    this.hasActiveAlert = false,
    this.batteryLevel = 0,
    this.firmwareVersion = '1.0.0',
    this.lastHeartbeat,
  });

  DeviceModel copyWith({
    String? name,
    String? location,
    bool? isOnline,
    bool? hasActiveAlert,
    double? batteryLevel,
    DateTime? lastHeartbeat,
  }) {
    return DeviceModel(
      id: id,
      deviceId: deviceId,
      name: name ?? this.name,
      location: location ?? this.location,
      isOnline: isOnline ?? this.isOnline,
      hasActiveAlert: hasActiveAlert ?? this.hasActiveAlert,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      firmwareVersion: firmwareVersion,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    );
  }
}
