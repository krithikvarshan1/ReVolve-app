import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';

class AlertProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Alert> _alerts = [];
  bool _isLoading = false;

  List<Alert> get alerts => _alerts;
  List<Alert> get unresolvedAlerts => _alerts.where((alert) => !alert.isResolved).toList();
  bool get isLoading => _isLoading;

  AlertProvider() {
    _init();
  }

  void _init() {
    // Listen to alerts stream
    _loadAlerts();
  }

  void _loadAlerts() {
    _isLoading = true;
    notifyListeners();

    // For now, use a mock device ID. In real app, get from auth
    const deviceId = 'device-001';

    final stream = _firebaseService.getAlertsStream(deviceId);
    stream.listen((alerts) {
      _alerts = alerts;
      _isLoading = false;
      notifyListeners();
    });
  }

  // Create alert from sensor data
  Future<void> createAlertFromSensorData(SensorData data) async {
    final alerts = <Alert>[];

    if (data.temperature > 80.0) {
      alerts.add(Alert(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        title: 'High Temperature Alert',
        message: 'Temperature exceeded safe threshold: ${data.temperature.toStringAsFixed(1)}°C',
        severity: AlertSeverity.high,
        timestamp: DateTime.now(),
        deviceId: data.deviceId,
        metadata: {'sensor': 'temperature', 'value': data.temperature},
      ));
    }

    if (data.vibration > 5.0) {
      alerts.add(Alert(
        id: 'vib-${DateTime.now().millisecondsSinceEpoch}',
        title: 'High Vibration Alert',
        message: 'Vibration exceeded safe threshold: ${data.vibration.toStringAsFixed(2)}g',
        severity: AlertSeverity.medium,
        timestamp: DateTime.now(),
        deviceId: data.deviceId,
        metadata: {'sensor': 'vibration', 'value': data.vibration},
      ));
    }

    if (data.gas > 500.0) {
      alerts.add(Alert(
        id: 'gas-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Gas Leak Alert',
        message: 'Gas levels exceeded safe threshold: ${data.gas.toStringAsFixed(0)}ppm',
        severity: AlertSeverity.critical,
        timestamp: DateTime.now(),
        deviceId: data.deviceId,
        metadata: {'sensor': 'gas', 'value': data.gas},
      ));
    }

    if (data.current > 10.0) {
      alerts.add(Alert(
        id: 'curr-${DateTime.now().millisecondsSinceEpoch}',
        title: 'High Current Alert',
        message: 'Current exceeded safe threshold: ${data.current.toStringAsFixed(1)}A',
        severity: AlertSeverity.medium,
        timestamp: DateTime.now(),
        deviceId: data.deviceId,
        metadata: {'sensor': 'current', 'value': data.current},
      ));
    }

    // Save alerts to Firebase
    for (final alert in alerts) {
      await _firebaseService.saveAlert(alert);
    }
  }

  // Resolve alert
  Future<void> resolveAlert(String alertId) async {
    await _firebaseService.resolveAlert(alertId);
    // The stream will automatically update the list
  }

  // Get alerts by severity
  List<Alert> getAlertsBySeverity(AlertSeverity severity) {
    return _alerts.where((alert) => alert.severity == severity).toList();
  }

  // Get recent alerts (last 24 hours)
  List<Alert> getRecentAlerts() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _alerts.where((alert) => alert.timestamp.isAfter(yesterday)).toList();
  }

  // Get alert statistics
  Map<String, int> getAlertStatistics() {
    final stats = <String, int>{
      'total': _alerts.length,
      'resolved': _alerts.where((a) => a.isResolved).length,
      'unresolved': unresolvedAlerts.length,
      'critical': getAlertsBySeverity(AlertSeverity.critical).length,
      'high': getAlertsBySeverity(AlertSeverity.high).length,
      'medium': getAlertsBySeverity(AlertSeverity.medium).length,
      'low': getAlertsBySeverity(AlertSeverity.low).length,
    };

    return stats;
  }
}