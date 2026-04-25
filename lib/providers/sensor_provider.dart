import 'dart:async';

import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/alert.dart';
import '../services/sensor_service.dart';
import '../services/firebase_service.dart';
import '../services/ml_service.dart';
import '../services/device_control_service.dart';
import '../models/ml_prediction.dart';
import '../models/predictive_maintenance_result.dart';
import '../services/predictive_maintenance_service.dart';
import '../config/app_config.dart';

const Duration _cloudDataFreshnessWindow = Duration(seconds: 12);

class SensorProvider with ChangeNotifier {
  final SensorService _sensorService = SensorService();
  final FirebaseService _firebaseService = FirebaseService();
  final MLService _mlService = MLService();
  final PredictiveMaintenanceService _predictiveService =
      PredictiveMaintenanceService();
  final DeviceControlService _deviceControlService = DeviceControlService();

  List<SensorData> _sensorHistory = [];
  SensorData? _latestData;
  MLPrediction? _latestPrediction;
  PredictiveMaintenanceResult? _latestPredictiveResult;
  final List<PredictiveMaintenanceResult> _predictionHistory = [];
  bool _isLoading = false;
  bool _isPredictiveLoading = false;
  String? _predictiveError;
  bool _isFallbackSimulationActive = false;
  final Map<String, DateTime> _lastAlertAt = {};
  // Throttle: only hit the backend once per mlPredictionInterval (default 30s).
  DateTime? _lastPredictiveCallAt;

  List<SensorData> get sensorHistory => _sensorHistory;
  SensorData? get latestData => _latestData;
  MLPrediction? get latestPrediction => _latestPrediction;
    PredictiveMaintenanceResult? get latestPredictiveResult =>
      _latestPredictiveResult;
    List<PredictiveMaintenanceResult> get predictionHistory =>
      List<PredictiveMaintenanceResult>.unmodifiable(_predictionHistory);
  bool get isLoading => _isLoading;
    bool get isPredictiveLoading => _isPredictiveLoading;
    String? get predictiveError => _predictiveError;
    bool get manualSimulationEnabled => _sensorService.manualSimulationEnabled;
    Map<String, double> get manualSimulationValues => _sensorService.manualValues;

  SensorProvider() {
    _init();
  }

  void _init() {
    // Listen to sensor stream
    _sensorService.sensorStream.listen((data) {
      // Ignore simulation ticks unless manual mode or fallback simulation is active.
      if (!_sensorService.manualSimulationEnabled && !_isFallbackSimulationActive) {
        return;
      }

      _latestData = data;
      _sensorHistory.add(data);

      // Keep only last 100 readings for memory efficiency
      if (_sensorHistory.length > 100) {
        _sensorHistory.removeAt(0);
      }

      // Save to Firebase
      _firebaseService.saveSensorData(data);

      // Update ML prediction (local, every tick)
      _updatePrediction();

      // Hit the backend at most once per mlPredictionInterval to avoid
      // flooding the server with 1,500+ concurrent hanging requests.
      final now = DateTime.now();
      final sinceLastCall = _lastPredictiveCallAt == null
          ? AppConfig.mlPredictionInterval
          : now.difference(_lastPredictiveCallAt!);
      if (sinceLastCall >= AppConfig.mlPredictionInterval) {
        _lastPredictiveCallAt = now;
        unawaited(_updatePredictiveResult(data));
      }
      _handleSafetyAutomation(data);

      notifyListeners();
    });

    // Load historical data
    _loadHistoricalData();
  }

  void _loadHistoricalData() async {
    _isLoading = true;
    notifyListeners();

    if (!_firebaseService.isAvailable) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Load last 50 readings from Firebase
      final stream = _firebaseService.getSensorDataStream(_sensorService.deviceId);
      stream.listen((data) {
        if (data.isNotEmpty) {
          final cloudLatest = data.last;
          _latestData = cloudLatest;

          if (_sensorService.manualSimulationEnabled) {
            // Keep the existing behavior for manual simulation mode.
            _sensorHistory = data;
          } else {
            // Live Firebase mode: append newest reading so trend chart grows over time.
            final hasNewPoint = _sensorHistory.isEmpty ||
                _sensorHistory.last.timestamp != cloudLatest.timestamp ||
                _sensorHistory.last.temperature != cloudLatest.temperature ||
                _sensorHistory.last.vibration != cloudLatest.vibration ||
                _sensorHistory.last.current != cloudLatest.current;

            if (hasNewPoint) {
              _sensorHistory = [..._sensorHistory, cloudLatest];
              if (_sensorHistory.length > 100) {
                _sensorHistory = _sensorHistory.sublist(_sensorHistory.length - 100);
              }
            }
          }

          // Always stop fallback simulation when live Firebase data exists.
          if (_isFallbackSimulationActive && !_sensorService.manualSimulationEnabled) {
            _sensorService.stopSensorSimulation();
            _isFallbackSimulationActive = false;
          }
        } else if (!_sensorService.manualSimulationEnabled) {
          // Start fallback simulation only when no cloud data is available.
          _sensorService.startSensorSimulation();
          _isFallbackSimulationActive = true;
        }
        _updatePrediction();
        if (_latestData != null) {
          unawaited(_updatePredictiveResult(_latestData!));
        }
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading historical data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isFreshReading(SensorData data) {
    final age = DateTime.now().difference(data.timestamp);
    return !age.isNegative && age <= _cloudDataFreshnessWindow;
  }

  void _updatePrediction() {
    if (_sensorHistory.isNotEmpty) {
      _latestPrediction = _mlService.predictLifecycle(_sensorHistory);
      // Save prediction to Firebase
      _firebaseService.saveMLPrediction(_latestPrediction!);
    }
  }

  Future<void> _updatePredictiveResult(SensorData data) async {
    _isPredictiveLoading = true;
    _predictiveError = null;
    notifyListeners();

    try {
      _latestPredictiveResult = await _predictiveService.fetchPrediction(data);
      _predictiveError = null;
    } catch (_) {
      // If prediction processing fails, use local fallback analysis.
      try {
        _latestPrediction ??= _mlService.predictLifecycle(_sensorHistory);
        _latestPredictiveResult = PredictiveMaintenanceResult.fromLocalPrediction(
          sensorData: data,
          prediction: _latestPrediction!,
        ).copyWithAi(
          aiInsight:
              'Live readings were analyzed locally because Claude could not be reached.',
          aiEmoji: '⚠️',
          maintenanceRecommendation: 'Monitor Closely',
        );
        _predictiveError = 'Using local analysis.';
      } catch (_) {
        // Last-resort: build a minimal result directly from sensor data so the
        // Predictive Console never stays blank.
        final healthPct = data.healthScore.clamp(0.0, 100.0);
        _latestPredictiveResult = PredictiveMaintenanceResult(
          faultPrediction: healthPct > 70 ? 'NORMAL' : healthPct > 40 ? 'OVERLOAD' : 'FAILURE_IMMINENT',
          faultConfidence: (100 - healthPct).clamp(0.0, 100.0),
          remainingUsefulLife: (healthPct * 20).round(),
          anomalyStatus: data.gas > 500 || data.vibration > 5 ? 'ANOMALY' : 'NORMAL',
          futureForecastTemp: data.temperature,
          maintenanceRecommendation: healthPct > 70 ? 'No Action Needed' : 'Schedule Inspection',
          healthScore: healthPct.round(),
          riskLevel: healthPct > 70 ? 'LOW' : healthPct > 40 ? 'MEDIUM' : 'HIGH',
          forecastSeries: List.generate(12, (i) => data.temperature + i * 0.2, growable: false),
          timestamp: DateTime.now(),
          deviceId: data.deviceId,
          aiInsight:
              'Live readings were analyzed locally because Claude could not be reached.',
          aiEmoji: '⚠️',
        );
        _predictiveError = 'Using local analysis.';
      }
    }

    if (_latestPredictiveResult != null) {
      _predictionHistory.add(_latestPredictiveResult!);
      unawaited(
        _firebaseService.savePredictiveMaintenanceResult(_latestPredictiveResult!),
      );
      if (_predictionHistory.length > 120) {
        _predictionHistory.removeAt(0);
      }
    }

    _isPredictiveLoading = false;
    notifyListeners();
  }

  void startSensorMonitoring() {
    if (_sensorService.manualSimulationEnabled) {
      _sensorService.startSensorSimulation();
      _isFallbackSimulationActive = true;
      return;
    }

    if (!_firebaseService.isAvailable) {
      _sensorService.startSensorSimulation();
      _isFallbackSimulationActive = true;
      return;
    }

    // Firebase is available: wait for onValue stream instead of forcing simulation.
    _sensorService.stopSensorSimulation();
    _isFallbackSimulationActive = false;
  }

  void setManualSimulationEnabled(bool enabled) {
    _sensorService.setManualSimulationEnabled(enabled);
    if (enabled) {
      // Ensure the simulation timer is running so manual slider values
      // are emitted immediately, regardless of Firebase data freshness.
      _sensorService.startSensorSimulation();
      _isFallbackSimulationActive = true;
    } else {
      // When disabling manual mode, stop the forced timer and let the
      // normal monitoring logic decide whether to resume auto-simulation.
      _sensorService.stopSensorSimulation();
      _isFallbackSimulationActive = false;
      // Restart monitoring so live/fallback data resumes correctly.
      startSensorMonitoring();
    }
    notifyListeners();
  }

  void updateManualSimulationValue(String key, double value) {
    _sensorService.updateManualSensorValue(key, value);
    notifyListeners();
  }

  void stopSensorMonitoring() {
    _sensorService.stopSensorSimulation();
    _isFallbackSimulationActive = false;
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

    // Only write to Firebase when we have a real device ID — in simulation
    // mode deviceId is empty and Firestore throws an invalid-path error.
    if (shouldShutdown && data.deviceId.isNotEmpty) {
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
      if (data.deviceId.isNotEmpty) {
        await _firebaseService.logUsage(
        data.deviceId,
        'alert_generated',
        {
          'message': alert.message,
          'severity': alert.severity.name,
          'title': alert.title,
        },
      );
      } // end deviceId guard
    }
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _predictiveService.dispose();
    super.dispose();
  }
}
