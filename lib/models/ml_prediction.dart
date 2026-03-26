import 'package:flutter/material.dart';

class MLPrediction {
  final String id;
  final double remainingUsefulLife; // RUL in hours
  final double failureProbability; // 0-1
  final List<String> insights; // AI-generated insights
  final Map<String, double> degradationTrend; // Key: sensor, Value: degradation rate
  final DateTime timestamp;
  final String deviceId;

  MLPrediction({
    required this.id,
    required this.remainingUsefulLife,
    required this.failureProbability,
    required this.insights,
    required this.degradationTrend,
    required this.timestamp,
    required this.deviceId,
  });

  // Health status based on RUL and failure probability
  String get healthStatus {
    if (failureProbability > 0.8 || remainingUsefulLife < 100) {
      return 'Critical';
    } else if (failureProbability > 0.5 || remainingUsefulLife < 500) {
      return 'Warning';
    } else if (failureProbability > 0.2 || remainingUsefulLife < 1000) {
      return 'Caution';
    } else {
      return 'Healthy';
    }
  }

  // Color for UI
  Color get statusColor {
    switch (healthStatus) {
      case 'Critical':
        return Colors.red;
      case 'Warning':
        return Colors.orange;
      case 'Caution':
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  // Factory from JSON (for API response)
  factory MLPrediction.fromJson(Map<String, dynamic> json) {
    return MLPrediction(
      id: json['id'] ?? '',
      remainingUsefulLife: (json['remainingUsefulLife'] as num?)?.toDouble() ?? 0.0,
      failureProbability: (json['failureProbability'] as num?)?.toDouble() ?? 0.0,
      insights: List<String>.from(json['insights'] ?? []),
      degradationTrend: Map<String, double>.from(json['degradationTrend'] ?? {}),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      deviceId: json['deviceId'] ?? '',
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'remainingUsefulLife': remainingUsefulLife,
      'failureProbability': failureProbability,
      'insights': insights,
      'degradationTrend': degradationTrend,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }
}