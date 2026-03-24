class SensorData {
  final String id;
  final double temperature; // Celsius
  final double vibration; // g
  final double current; // Amperes
  final double gas; // ppm
  final double sound; // dB
  final DateTime timestamp;
  final String deviceId;

  SensorData({
    required this.id,
    required this.temperature,
    required this.vibration,
    required this.current,
    required this.gas,
    required this.sound,
    required this.timestamp,
    required this.deviceId,
  });

  // Calculate health score based on weighted formula
  double get healthScore {
    final weights = {
      temperature: 0.3,
      vibration: 0.25,
      current: 0.2,
      gas: 0.15,
      sound: 0.1,
    };

    // Normalize values (assuming max safe values)
    final normalizedTemp = temperature / 100.0;
    final normalizedVib = vibration / 10.0;
    final normalizedCurr = current / 15.0;
    final normalizedGas = gas / 1000.0;
    final normalizedSound = sound / 120.0;

    final score = 1.0 - (
      normalizedTemp * weights[temperature]! +
      normalizedVib * weights[vibration]! +
      normalizedCurr * weights[current]! +
      normalizedGas * weights[gas]! +
      normalizedSound * weights[sound]!
    );

    return (score * 100).clamp(0.0, 100.0);
  }

  // Factory constructor for creating from JSON (e.g., from API)
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      vibration: (json['vibration'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      gas: (json['gas'] as num?)?.toDouble() ?? 0.0,
      sound: (json['sound'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      deviceId: json['deviceId'] ?? '',
    );
  }

  // Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'temperature': temperature,
      'vibration': vibration,
      'current': current,
      'gas': gas,
      'sound': sound,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  // Copy with method for updates
  SensorData copyWith({
    String? id,
    double? temperature,
    double? vibration,
    double? current,
    double? gas,
    double? sound,
    DateTime? timestamp,
    String? deviceId,
  }) {
    return SensorData(
      id: id ?? this.id,
      temperature: temperature ?? this.temperature,
      vibration: vibration ?? this.vibration,
      current: current ?? this.current,
      gas: gas ?? this.gas,
      sound: sound ?? this.sound,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}