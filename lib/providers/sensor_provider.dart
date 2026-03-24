import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/sensor_service.dart';
import '../services/firebase_service.dart';
import '../services/ml_service.dart';
import '../models/ml_prediction.dart';

class SensorProvider with ChangeNotifier {
  final SensorService _sensorService = SensorService();
  final FirebaseService _firebaseService = FirebaseService();
  final MLService _mlService = MLService();

  List<SensorData> _sensorHistory = [];
  SensorData? _latestData;
  MLPrediction? _latestPrediction;
  bool _isLoading = false;

  List<SensorData> get sensorHistory => _sensorHistory;
  SensorData? get latestData => _latestData;
  MLPrediction? get latestPrediction => _latestPrediction;
  bool get isLoading => _isLoading;

  SensorProvider() {
    _init();
  }

  void _init() {
    // Listen to sensor stream
    _sensorService.sensorStream.listen((data) {
      _latestData = data;
      _sensorHistory.add(data);

      // Keep only last 100 readings for memory efficiency
      if (_sensorHistory.length > 100) {
        _sensorHistory.removeAt(0);
      }

      // Save to Firebase
      _firebaseService.saveSensorData(data);

      // Update ML prediction
      _updatePrediction();

      notifyListeners();
    });

    // Load historical data
    _loadHistoricalData();
  }

  void _loadHistoricalData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load last 50 readings from Firebase
      final stream = _firebaseService.getSensorDataStream(_sensorService.deviceId);
      stream.listen((data) {
        _sensorHistory = data;
        if (_sensorHistory.isNotEmpty) {
          _latestData = _sensorHistory.last;
        }
        _updatePrediction();
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading historical data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updatePrediction() {
    if (_sensorHistory.isNotEmpty) {
      _latestPrediction = _mlService.predictLifecycle(_sensorHistory);
      // Save prediction to Firebase
      _firebaseService.saveMLPrediction(_latestPrediction!);
    }
  }

  void startSensorMonitoring() {
    _sensorService.startSensorSimulation();
  }

  void stopSensorMonitoring() {
    _sensorService.stopSensorSimulation();
  }

  // Get sensor data for specific time range
  List<SensorData> getSensorDataInRange(DateTime start, DateTime end) {
    return _sensorHistory.where((data) =>
      data.timestamp.isAfter(start) && data.timestamp.isBefore(end)
    ).toList();
  }

  // Get average values for dashboard
  Map<String, double> getAverageValues() {
    if (_sensorHistory.isEmpty) return {};

    final count = _sensorHistory.length;
    final sumTemp = _sensorHistory.map((d) => d.temperature).reduce((a, b) => a + b);
    final sumVib = _sensorHistory.map((d) => d.vibration).reduce((a, b) => a + b);
    final sumCurr = _sensorHistory.map((d) => d.current).reduce((a, b) => a + b);
    final sumGas = _sensorHistory.map((d) => d.gas).reduce((a, b) => a + b);
    final sumSound = _sensorHistory.map((d) => d.sound).reduce((a, b) => a + b);

    return {
      'temperature': sumTemp / count,
      'vibration': sumVib / count,
      'current': sumCurr / count,
      'gas': sumGas / count,
      'sound': sumSound / count,
    };
  }

  // Check for alerts based on thresholds
  List<String> checkForAlerts() {
    if (_latestData == null) return [];

    final alerts = <String>[];

    if (_latestData!.temperature > 80.0) {
      alerts.add('High Temperature: ${_latestData!.temperature.toStringAsFixed(1)}°C');
    }

    if (_latestData!.vibration > 5.0) {
      alerts.add('High Vibration: ${_latestData!.vibration.toStringAsFixed(2)}g');
    }

    if (_latestData!.gas > 500.0) {
      alerts.add('Gas Leak Detected: ${_latestData!.gas.toStringAsFixed(0)}ppm');
    }

    if (_latestData!.current > 10.0) {
      alerts.add('High Current: ${_latestData!.current.toStringAsFixed(1)}A');
    }

    return alerts;
  }

  void dispose() {
    _sensorService.dispose();
  }
}