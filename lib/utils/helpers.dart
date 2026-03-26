import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  // Format timestamp for display
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, yyyy HH:mm').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Format duration
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // Calculate percentage
  static double calculatePercentage(double value, double total) {
    if (total == 0) return 0.0;
    return (value / total) * 100.0;
  }

  // Clamp value between min and max
  static double clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }

  // Round to decimal places
  static double roundToDecimal(double value, int decimals) {
    final factor = pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }

  // Check if value is within range
  static bool isInRange(double value, double min, double max) {
    return value >= min && value <= max;
  }

  // Generate random ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Validate email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Validate password strength
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Get color from health score
  static Color getHealthColor(double healthScore) {
    if (healthScore >= 80) return Colors.green;
    if (healthScore >= 60) return Colors.yellow;
    return Colors.red;
  }

  // Get health status text
  static String getHealthStatus(double healthScore) {
    if (healthScore >= 80) return 'Healthy';
    if (healthScore >= 60) return 'Warning';
    return 'Critical';
  }

  // Format sensor value with unit
  static String formatSensorValue(double value, String unit, {int decimals = 1}) {
    return '${roundToDecimal(value, decimals)} $unit';
  }

  // Calculate trend (positive, negative, neutral)
  static String calculateTrend(List<double> values) {
    if (values.length < 2) return 'neutral';

    final recent = values.sublist(values.length - 5); // Last 5 values
    final average = recent.reduce((a, b) => a + b) / recent.length;

    final firstHalf = recent.sublist(0, recent.length ~/ 2);
    final secondHalf = recent.sublist(recent.length ~/ 2);

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    final difference = secondAvg - firstAvg;

    if (difference > 1) return 'increasing';
    if (difference < -1) return 'decreasing';
    return 'stable';
  }
}