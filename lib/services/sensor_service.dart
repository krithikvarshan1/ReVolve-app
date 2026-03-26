import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';

class SensorService {
  final StreamController<SensorData> _sensorStreamController = StreamController<SensorData>.broadcast();
  Timer? _timer;
  final Uuid _uuid = const Uuid();

  // Mock device ID
  final String deviceId = 'device-001';

  Stream<SensorData> get sensorStream => _sensorStreamController.stream;

  // Start simulating sensor data
  void startSensorSimulation() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(AppConfig.sensorUpdateInterval, (_) {
      final sensorData = _generateMockSensorData();
      _sensorStreamController.add(sensorData);
    });
  }

  // Stop simulation
  void stopSensorSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  // Generate mock sensor data with some randomness
  SensorData _generateMockSensorData() {
    final random = Random();

    // Base values with some variation
    final temperature = 25.0 + random.nextDouble() * 50.0; // 25-75°C
    final vibration = random.nextDouble() * 8.0; // 0-8g
    final current = 2.0 + random.nextDouble() * 8.0; // 2-10A
    final gas = random.nextDouble() * 800.0; // 0-800ppm
    final dust = random.nextDouble() * 350.0; // 0-350 ug/m3
    final sound = 30.0 + random.nextDouble() * 60.0; // 30-90dB

    return SensorData(
      id: _uuid.v4(),
      temperature: temperature,
      vibration: vibration,
      current: current,
      gas: gas,
      dust: dust,
      sound: sound,
      timestamp: DateTime.now(),
      deviceId: deviceId,
    );
  }

  // Future method for fetching from ESP32 API
  // This will be used when integrating with hardware
  /*
  Future<SensorData> fetchSensorDataFromESP32() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}${AppConfig.sensorDataEndpoint}'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return SensorData.fromJson(jsonData);
      } else {
        throw Exception('Failed to fetch sensor data');
      }
    } catch (e) {
      print('Error fetching sensor data: $e');
      rethrow;
    }
  }
  */

  void dispose() {
    _timer?.cancel();
    _sensorStreamController.close();
  }
}
