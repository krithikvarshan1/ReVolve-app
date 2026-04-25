import 'package:flutter/material.dart';

import '../models/activity_log.dart';
import '../services/firebase_service.dart';

class LogProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<ActivityLog> _logs = [];
  bool _isLoading = false;

  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;

  LogProvider() {
    _loadLogs();
  }

  void _loadLogs() {
    // Show mock logs immediately so the UI is never blank.
    _logs = _mockLogs();
    _isLoading = true;
    notifyListeners();

    if (!_firebaseService.isAvailable) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    const deviceId = 'device-001';
    _firebaseService.getLogsStream(deviceId).listen((items) {
      // Only replace mock logs if Firebase actually returned real entries.
      if (items.isNotEmpty) {
        _logs = items;
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      // Firebase error — keep the mock logs, just stop the spinner.
      _isLoading = false;
      notifyListeners();
    });
  }

  List<ActivityLog> get maintenanceLogs => _logs
      .where((log) => log.category == 'Maintenance')
      .toList(growable: false);

  List<ActivityLog> _mockLogs() {
    final now = DateTime.now();
    return [
      ActivityLog(
        id: 'log-1',
        deviceId: 'device-001',
        action: 'maintenance_due',
        title: 'Preventive maintenance recommended',
        message: 'Bearing inspection window opens within the next 36 hours.',
        timestamp: now.subtract(const Duration(minutes: 18)),
        details: const {'priority': 'high'},
      ),
      ActivityLog(
        id: 'log-2',
        deviceId: 'device-001',
        action: 'relay_toggle',
        title: 'Relay safety test completed',
        message: 'Remote relay responded successfully during diagnostics.',
        timestamp: now.subtract(const Duration(hours: 2)),
        details: const {'status': 'ON'},
      ),
      ActivityLog(
        id: 'log-3',
        deviceId: 'device-001',
        action: 'system_review',
        title: 'Shift summary generated',
        message: 'Temperature remained stable while vibration showed brief spikes.',
        timestamp: now.subtract(const Duration(hours: 6)),
        details: const {'operator': 'AI monitor'},
      ),
    ];
  }
}
