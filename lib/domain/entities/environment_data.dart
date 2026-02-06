class EnvironmentData {
  final bool isDoorOpen;      // Sensor magnético
  final bool isVibrationDetected; // Sensor vibración
  final bool isLightDetected; // Sensor LDR
  final bool isRelay1On;      // Estado Relé 1
  final bool isRelay2On;      // Estado Relé 2
  final DateTime timestamp;

  EnvironmentData({
    required this.isDoorOpen,
    required this.isVibrationDetected,
    required this.isLightDetected,
    required this.isRelay1On,
    required this.isRelay2On,
    required this.timestamp,
  });

  // Este Factory detecta el JSON: {"type":"ENV", "door":1, "vib":0...}
  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    return EnvironmentData(
      isDoorOpen: (json['door'] ?? 0) == 1,
      isVibrationDetected: (json['vib'] ?? 0) == 1,
      isLightDetected: (json['ldr'] ?? 0) == 1,
      isRelay1On: (json['r1'] ?? 0) == 1,
      isRelay2On: (json['r2'] ?? 0) == 1,
      timestamp: DateTime.now(),
    );
  }
}