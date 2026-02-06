

class SensorData {
  final String estado;
  final double temperatura;
  final double irValue;
  final double aceleracion;
  final DateTime timestamp;

  SensorData({
    required this.estado,
    required this.temperatura,
    required this.irValue,
    required this.aceleracion,
    required this.timestamp,
  });

  // NUEVO Factory: Parsea JSON seguro
  // Espera formato: {"e":"NORMAL", "t":36.5, "ir":45000, "a":1.0}
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      estado: json['e'] ?? "DESC", // 'e' es estado
      temperatura: (json['t'] as num?)?.toDouble() ?? 0.0,
      irValue: (json['ir'] as num?)?.toDouble() ?? 0.0,
      aceleracion: (json['a'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
  }
}