import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/sensor_data.dart';
import '../models/ml_prediction.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Fetch sensor data from ESP32
  Future<SensorData> fetchSensorData() async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.sensorDataEndpoint}'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return SensorData.fromJson(jsonData);
      } else {
        throw Exception('Failed to fetch sensor data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching sensor data: $e');
      rethrow;
    }
  }

  // Send relay control command to ESP32
  Future<bool> controlRelay(String deviceId, bool status) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.relayControlEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'deviceId': deviceId,
          'status': status,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error controlling relay: $e');
      return false;
    }
  }

  // Get ML prediction from Python backend
  Future<MLPrediction> getMLPrediction(List<SensorData> sensorHistory) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.predictEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sensor_history': sensorHistory.map((data) => data.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return MLPrediction.fromJson(jsonData);
      } else {
        throw Exception('ML prediction failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling ML API: $e');
      rethrow;
    }
  }

  // Upload sensor data batch to server
  Future<bool> uploadSensorDataBatch(List<SensorData> dataList) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/upload-sensor-data'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'data': dataList.map((data) => data.toJson()).toList(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error uploading sensor data: $e');
      return false;
    }
  }

  // Get device configuration from server
  Future<Map<String, dynamic>> getDeviceConfig(String deviceId) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/device-config/$deviceId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get device config');
      }
    } catch (e) {
      print('Error getting device config: $e');
      rethrow;
    }
  }

  // Update device firmware (future feature)
  Future<bool> updateFirmware(String deviceId, String firmwareUrl) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/update-firmware'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'deviceId': deviceId,
          'firmwareUrl': firmwareUrl,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating firmware: $e');
      return false;
    }
  }

  // Health check for ESP32
  Future<bool> checkDeviceHealth(String deviceId) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/health/$deviceId'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Device health check failed: $e');
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}