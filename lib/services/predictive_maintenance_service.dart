import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/predictive_maintenance_result.dart';
import '../models/sensor_data.dart';

class PredictiveMaintenanceService {
  PredictiveMaintenanceService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<PredictiveMaintenanceResult> fetchPrediction(
    SensorData sensorData,
  ) async {
    final uri = Uri.parse(
      '${AppConfig.mlBackendBaseUrl}${AppConfig.predictiveMaintenanceEndpoint}',
    );

    final payload = {
      'temperature': sensorData.temperature,
      'vibration': sensorData.vibration,
      'current': sensorData.current,
      'gas': sensorData.gas,
      'dust': sensorData.dust,
      'sound': sensorData.sound,
      'deviceId': sensorData.deviceId,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Predictive API failed: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return PredictiveMaintenanceResult.fromJson(
      body,
      deviceId: sensorData.deviceId,
    );
  }

  void dispose() {
    _client.close();
  }
}
