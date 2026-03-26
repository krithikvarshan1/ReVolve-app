import 'package:flutter/material.dart';

enum AlertSeverity { low, medium, high, critical }

class Alert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final String deviceId;
  final bool isResolved;
  final Map<String, dynamic>? metadata; // Additional data like sensor values

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.deviceId,
    this.isResolved = false,
    this.metadata,
  });

  // Color based on severity
  Color get color {
    switch (severity) {
      case AlertSeverity.low:
        return Colors.blue;
      case AlertSeverity.medium:
        return Colors.yellow;
      case AlertSeverity.high:
        return Colors.orange;
      case AlertSeverity.critical:
        return Colors.red;
    }
  }

  // Icon based on severity
  IconData get icon {
    switch (severity) {
      case AlertSeverity.low:
        return Icons.info;
      case AlertSeverity.medium:
        return Icons.warning;
      case AlertSeverity.high:
        return Icons.error;
      case AlertSeverity.critical:
        return Icons.dangerous;
    }
  }

  // Factory from JSON
  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      severity: AlertSeverity.values[json['severity'] ?? 0],
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      deviceId: json['deviceId'] ?? '',
      isResolved: json['isResolved'] ?? false,
      metadata: json['metadata'],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity.index,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'isResolved': isResolved,
      'metadata': metadata,
    };
  }

  // Copy with
  Alert copyWith({
    String? id,
    String? title,
    String? message,
    AlertSeverity? severity,
    DateTime? timestamp,
    String? deviceId,
    bool? isResolved,
    Map<String, dynamic>? metadata,
  }) {
    return Alert(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
      isResolved: isResolved ?? this.isResolved,
      metadata: metadata ?? this.metadata,
    );
  }
}