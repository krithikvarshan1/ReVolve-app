import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class SensorData {
  final String id;
  final double temperature; // Celsius
  final double vibration; // g
  final double current; // Amperes
  final double gas; // ppm
  final double dust; // ug/m3
  final double sound; // dB
  final DateTime timestamp;
  final String deviceId;

  SensorData({
    required this.id,
    required this.temperature,
    required this.vibration,
    required this.current,
    required this.gas,
    required this.dust,
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
      dust: 0.05,
      sound: 0.05,
    };

    // Normalize values (assuming max safe values)
    final normalizedTemp = temperature / 100.0;
    final normalizedVib = vibration / 10.0;
    final normalizedCurr = current / 15.0;
    final normalizedGas = gas / 1000.0;
    final normalizedDust = dust / 500.0;
    final normalizedSound = sound / 120.0;

    final score = 1.0 - (
      normalizedTemp * weights[temperature]! +
      normalizedVib * weights[vibration]! +
      normalizedCurr * weights[current]! +
      normalizedGas * weights[gas]! +
      normalizedDust * weights[dust]! +
      normalizedSound * weights[sound]!
    );

    return (score * 100).clamp(0.0, 100.0);
  }

  // Factory constructor for creating from JSON (e.g., from API)
  factory SensorData.fromJson(Map<String, dynamic> json) {
    final temperature = _readDouble(
          json,
          const ['temp'],
          fallback:
              _readDouble(
                json,
                const ['temperature', 'temperatureC', 'temperature_c'],
                fallback: 0.0,
              ) ??
              0.0,
        ) ??
        0.0;

    final adxlX = _readDouble(json, const ['adxl_x'], fallback: 0.0) ?? 0.0;
    final adxlY = _readDouble(json, const ['adxl_y'], fallback: 0.0) ?? 0.0;
    final adxlZ = _readDouble(json, const ['adxl_z'], fallback: 0.0) ?? 0.0;
    final adxlMagnitude = math.sqrt((adxlX * adxlX) + (adxlY * adxlY) + (adxlZ * adxlZ));
    final hasAdxlVector = json.containsKey('adxl_x') ||
        json.containsKey('adxl_y') ||
        json.containsKey('adxl_z');
    final vibration = hasAdxlVector
        ? double.parse(adxlMagnitude.toStringAsFixed(2))
        : (_readDouble(
                  json,
                  const ['vibration', 'vib', 'vibration_g', 'vibrationG'],
                  fallback: 0.0,
                ) ??
                0.0);

    return SensorData(
      id: _readString(json, const ['id', 'docId', 'recordId']) ?? '',
      temperature: temperature,
      vibration: vibration,
      current: _readDouble(
          json,
          const ['current'],
          fallback:
              _readDouble(json, const ['currentA', 'current_a', 'amps'], fallback: 0.0) ??
              0.0,
        ) ??
        0.0,
      gas: _readDouble(
          json,
          const ['gas'],
          fallback: _readDouble(json, const ['gasPpm', 'gas_ppm', 'mq2', 'mq135'], fallback: 0.0) ??
              0.0,
        ) ??
        0.0,
      dust: _readDouble(
          json,
          const ['dust'],
          fallback:
              _readDouble(json, const ['dustPpm', 'dust_ppm', 'dust_density', 'pm25'], fallback: 0.0) ??
              0.0,
        ) ??
        0.0,
      sound: _readDouble(
          json,
          const ['sound'],
          fallback: _readDouble(json, const ['soundDb', 'sound_db', 'noise', 'noise_db'], fallback: 0.0) ??
              0.0,
        ) ??
        0.0,
      timestamp: _readTimestamp(
        json,
        const ['timestamp', 'time', 'createdAt', 'created_at', 'ts'],
      ),
      deviceId: _readString(
            json,
            const [
              'deviceId',
              'device_id',
              'device',
              'machineId',
              'machine_id',
              'nodeId',
              'node_id',
            ],
          ) ??
          '',
    );
  }

  factory SensorData.fromFirestoreDocument(
    String docId,
    Map<String, dynamic> json, {
    String? fallbackDeviceId,
  }) {
    final parsed = SensorData.fromJson({
      ...json,
      if ((json['id'] ?? '').toString().isEmpty) 'id': docId,
      if ((json['deviceId'] ?? '').toString().isEmpty &&
          (json['device_id'] ?? '').toString().isEmpty &&
          fallbackDeviceId != null)
        'deviceId': fallbackDeviceId,
    });

    if (parsed.id.isEmpty) {
      final timestamp = parsed.timestamp.millisecondsSinceEpoch;
      final device = parsed.deviceId.isEmpty ? 'device' : parsed.deviceId;
      return parsed.copyWith(id: '$device-$timestamp');
    }

    return parsed;
  }

  // Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'temperature': temperature,
      'vibration': vibration,
      'current': current,
      'gas': gas,
      'dust': dust,
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
    double? dust,
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
      dust: dust ?? this.dust,
      sound: sound ?? this.sound,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  static DateTime _readTimestamp(Map<String, dynamic> json, List<String> keys) {
    final raw = _readAny(json, keys);
    if (raw == null) {
      return DateTime.now();
    }

    if (raw is Timestamp) {
      return raw.toDate();
    }

    if (raw is DateTime) {
      return raw;
    }

    if (raw is num) {
      final value = raw.toInt();
      final ms = value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    final parsed = DateTime.tryParse(raw.toString());
    return parsed ?? DateTime.now();
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    final raw = _readAny(json, keys);
    if (raw == null) {
      return null;
    }
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _readDouble(
    Map<String, dynamic> json,
    List<String> keys, {
    double? fallback,
  }) {
    final raw = _readAny(json, keys);
    if (raw == null) {
      return fallback;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    final normalized = raw.toString().replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? fallback;
  }

  static dynamic _readAny(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        final value = json[key];
        if (value != null) {
          return value;
        }
      }
    }

    const nestedContainers = ['payload', 'data', 'reading', 'readings', 'sensors'];
    for (final container in nestedContainers) {
      final nested = json[container];
      if (nested is Map<String, dynamic>) {
        final value = _readAny(nested, keys);
        if (value != null) {
          return value;
        }
      }
    }

    return null;
  }
}
