import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';

class SensorService {
  final StreamController<SensorData> _sensorStreamController = StreamController<SensorData>.broadcast();
  Timer? _timer;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();

  bool _manualSimulationEnabled = false;
  final Map<String, double> _manualValues = {
    'temperature': 42.0,
    'vibration': 2.2,
    'current': 6.0,
    'gas': 220.0,
    'dust': 120.0,
    'sound': 55.0,
  };

  final String deviceId = AppConfig.sensorDeviceId;

  Stream<SensorData> get sensorStream => _sensorStreamController.stream;
  bool get manualSimulationEnabled => _manualSimulationEnabled;
  Map<String, double> get manualValues => Map<String, double>.from(_manualValues);

  // Start simulating sensor data
  void startSensorSimulation() {
    // Cancel any existing timer so we always get a fresh start (needed when
    // switching between manual and auto modes).
    _timer?.cancel();
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
    // Base values with bounded variation for stable live charts.
    final temperature = _sample('temperature', min: 20, max: 120, jitter: 3.8);
    final vibration = _sample('vibration', min: 0, max: 10, jitter: 0.45);
    final current = _sample('current', min: 0, max: 15, jitter: 0.35);
    final gas = _sample('gas', min: 0, max: 1000, jitter: 22);
    final dust = _sample('dust', min: 0, max: 500, jitter: 12);
    final sound = _sample('sound', min: 0, max: 120, jitter: 3.6);

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

  void setManualSimulationEnabled(bool enabled) {
    _manualSimulationEnabled = enabled;
  }

  void updateManualSensorValue(String key, double value) {
    if (_manualValues.containsKey(key)) {
      _manualValues[key] = value;
    }
  }

  double _sample(
    String key, {
    required double min,
    required double max,
    required double jitter,
  }) {
    if (_manualSimulationEnabled) {
      final base = _manualValues[key] ?? min;
      final noisy = base + (_random.nextDouble() * 2 - 1) * jitter;
      return noisy.clamp(min, max);
    }

    final value = min + _random.nextDouble() * (max - min);
    return value.clamp(min, max);
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
