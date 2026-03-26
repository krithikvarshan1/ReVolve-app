class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.deviceId,
    required this.action,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.details,
  });

  final String id;
  final String deviceId;
  final String action;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  String get category {
    if (action.contains('maintenance')) {
      return 'Maintenance';
    }
    if (action.contains('alert') || action.contains('shutdown')) {
      return 'Safety';
    }
    if (action.contains('relay') || action.contains('device')) {
      return 'Control';
    }
    return 'Operations';
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final details = Map<String, dynamic>.from(json['details'] ?? const {});
    return ActivityLog(
      id: json['id'] ?? '',
      deviceId: json['deviceId'] ?? '',
      action: json['action'] ?? 'event',
      title: json['title'] ?? _titleFromAction(json['action'] ?? 'event'),
      message: json['message'] ?? _messageFromDetails(details),
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      details: details,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'action': action,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  static String _titleFromAction(String action) {
    switch (action) {
      case 'auto_shutdown':
        return 'Automatic shutdown triggered';
      case 'relay_toggle':
        return 'Relay state updated';
      case 'maintenance_due':
        return 'Maintenance window approaching';
      default:
        return 'System event recorded';
    }
  }

  static String _messageFromDetails(Map<String, dynamic> details) {
    if (details['message'] is String) {
      return details['message'] as String;
    }
    return 'Operational activity captured for review.';
  }
}
