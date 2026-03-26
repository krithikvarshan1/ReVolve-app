import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/alert.dart';
import '../services/sensor_service.dart';
import '../services/firebase_service.dart';
import '../services/ml_service.dart';
import '../services/device_control_service.dart';
import '../models/ml_prediction.dart';

class SensorProvider with ChangeNotifier {
  final SensorService _sensorService = SensorService();
  final FirebaseService _firebaseService = FirebaseService();
  final MLService _mlService = MLService();
  final DeviceControlService _deviceControlService = DeviceControlService();

  List<SensorData> _sensorHistory = [];
  SensorData? _latestData;
  MLPrediction? _latestPrediction;
  bool _isLoading = false;
  final Map<String, DateTime> _lastAlertAt = {};

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
      _handleSafetyAutomation(data);

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
    final sumDust = _sensorHistory.map((d) => d.dust).reduce((a, b) => a + b);
    final sumSound = _sensorHistory.map((d) => d.sound).reduce((a, b) => a + b);

    return {
      'temperature': sumTemp / count,
      'vibration': sumVib / count,
      'current': sumCurr / count,
      'gas': sumGas / count,
      'dust': sumDust / count,
      'sound': sumSound / count,
    };
  }

  double get healthScore => _latestData?.healthScore ?? 0.0;

  double get usageHours {
    if (_sensorHistory.length < 2) {
      return 0.0;
    }
    final duration = _sensorHistory.last.timestamp.difference(_sensorHistory.first.timestamp);
    return duration.inSeconds / 3600;
  }

  int get anomalyCount => checkForAlerts().length;

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

    if (_latestData!.dust > 250.0) {
      alerts.add('High Dust Level: ${_latestData!.dust.toStringAsFixed(0)} ug/m3');
    }

    if (_latestData!.current > 10.0) {
      alerts.add('High Current: ${_latestData!.current.toStringAsFixed(1)}A');
    }

    return alerts;
  }

  Future<void> _handleSafetyAutomation(SensorData data) async {
    await _createAlertsIfNeeded(data);

    final shouldShutdown = await _deviceControlService.autoShutdownIfNeeded(
      data.temperature,
      data.vibration,
      data.gas,
    );

    if (shouldShutdown) {
      await _firebaseService.updateDeviceRelay(data.deviceId, false);
      await _firebaseService.logUsage(
        data.deviceId,
        'auto_shutdown',
        {
          'message':
              'Automatic shutdown triggered due to unsafe operating conditions.',
          'temperature': data.temperature,
          'vibration': data.vibration,
          'gas': data.gas,
        },
      );
    }
  }

  Future<void> _createAlertsIfNeeded(SensorData data) async {
    final alertSpecs = <Map<String, dynamic>>[
      if (data.temperature > 80.0)
        {
          'key': 'temperature',
          'title': 'Over-temperature detected',
          'message':
              'Temperature reached ${data.temperature.toStringAsFixed(1)} C and crossed the safe threshold.',
          'severity': AlertSeverity.high,
        },
      if (data.vibration > 5.0)
        {
          'key': 'vibration',
          'title': 'High vibration detected',
          'message':
              'Vibration reached ${data.vibration.toStringAsFixed(2)} g and may affect component life.',
          'severity': AlertSeverity.medium,
        },
      if (data.gas > 500.0)
        {
          'key': 'gas',
          'title': 'Gas leakage risk',
          'message':
              'Gas concentration reached ${data.gas.toStringAsFixed(0)} ppm and requires inspection.',
          'severity': AlertSeverity.critical,
        },
      if (data.dust > 250.0)
        {
          'key': 'dust',
          'title': 'High dust concentration',
          'message':
              'Dust concentration reached ${data.dust.toStringAsFixed(0)} ug/m3 and needs ventilation review.',
          'severity': AlertSeverity.medium,
        },
    ];

    for (final spec in alertSpecs) {
      final key = spec['key'] as String;
      final lastRaised = _lastAlertAt[key];
      if (lastRaised != null &&
          DateTime.now().difference(lastRaised) < const Duration(seconds: 30)) {
        continue;
      }

      _lastAlertAt[key] = DateTime.now();
      final alert = Alert(
        id: '${key}-${DateTime.now().millisecondsSinceEpoch}',
        title: spec['title'] as String,
        message: spec['message'] as String,
        severity: spec['severity'] as AlertSeverity,
        timestamp: DateTime.now(),
        deviceId: data.deviceId,
        metadata: {
          'temperature': data.temperature,
          'vibration': data.vibration,
          'current': data.current,
          'gas': data.gas,
          'dust': data.dust,
          'sound': data.sound,
        },
      );

      await _firebaseService.saveAlert(alert);
      await _firebaseService.logUsage(
        data.deviceId,
        'alert_generated',
        {
          'message': alert.message,
          'severity': alert.severity.name,
          'title': alert.title,
        },
      );
    }
  }

  @override
  void dispose() {
    _sensorService.dispose();
    super.dispose();
  }
}
