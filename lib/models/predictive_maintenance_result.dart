import 'ml_prediction.dart';
import 'sensor_data.dart';

class PredictiveMaintenanceResult {
  const PredictiveMaintenanceResult({
    required this.faultPrediction,
    required this.faultConfidence,
    required this.remainingUsefulLife,
    required this.anomalyStatus,
    required this.futureForecastTemp,
    required this.maintenanceRecommendation,
    required this.healthScore,
    required this.riskLevel,
    required this.forecastSeries,
    required this.timestamp,
    required this.deviceId,
  });

  final String faultPrediction;
  final double faultConfidence;
  final int remainingUsefulLife;
  final String anomalyStatus;
  final double futureForecastTemp;
  final String maintenanceRecommendation;
  final int healthScore;
  final String riskLevel;
  final List<double> forecastSeries;
  final DateTime timestamp;
  final String deviceId;

  bool get isAnomaly => anomalyStatus.toUpperCase() == 'ANOMALY';

  factory PredictiveMaintenanceResult.fromJson(
    Map<String, dynamic> json, {
    required String deviceId,
  }) {
    return PredictiveMaintenanceResult(
      faultPrediction: (json['fault_prediction'] ?? 'NORMAL').toString(),
      faultConfidence: (json['fault_confidence'] as num?)?.toDouble() ?? 0,
      remainingUsefulLife:
          (json['remaining_useful_life'] as num?)?.round() ?? 0,
      anomalyStatus: (json['anomaly_status'] ?? 'NORMAL').toString(),
      futureForecastTemp:
          (json['future_forecast_temp'] as num?)?.toDouble() ?? 0,
      maintenanceRecommendation:
          (json['maintenance_recommendation'] ?? 'No Action Needed').toString(),
      healthScore: (json['health_score'] as num?)?.round() ?? 0,
      riskLevel: (json['risk_level'] ?? 'LOW').toString(),
      forecastSeries: (json['forecast_series'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toDouble())
          .toList(growable: false),
      timestamp: DateTime.now(),
      deviceId: deviceId,
    );
  }

  factory PredictiveMaintenanceResult.fromLocalPrediction({
    required SensorData sensorData,
    required MLPrediction prediction,
  }) {
    final fault = prediction.failureProbability > 0.85
        ? 'FAILURE_IMMINENT'
        : prediction.failureProbability > 0.65
            ? 'OVERLOAD'
            : sensorData.temperature > 78
                ? 'OVERHEAT'
                : 'NORMAL';
    final faultConfidence =
        (prediction.failureProbability * 100).clamp(0.0, 100.0).toDouble();
    final anomalyStatus = sensorData.gas > 500 || sensorData.vibration > 5
        ? 'ANOMALY'
        : 'NORMAL';
    final remainingUsefulLife =
        _normalizeRulToHours(prediction.remainingUsefulLife);
    final healthScore = _calculateHealthScore(
      fault: fault,
      faultConfidence: faultConfidence,
      rul: remainingUsefulLife,
      anomalyStatus: anomalyStatus,
    );
    final riskLevel = _deriveRiskLevel(
      fault: fault,
      faultConfidence: faultConfidence,
      rul: remainingUsefulLife,
      anomalyStatus: anomalyStatus,
      healthScore: healthScore,
    );

    return PredictiveMaintenanceResult(
      faultPrediction: fault,
      faultConfidence: faultConfidence,
      remainingUsefulLife: remainingUsefulLife,
      anomalyStatus: anomalyStatus,
      futureForecastTemp: sensorData.temperature,
      maintenanceRecommendation: _recommendationForFault(
        fault,
        anomalyStatus,
        riskLevel,
      ),
      healthScore: healthScore,
      riskLevel: riskLevel,
      forecastSeries: List<double>.generate(
        12,
        (index) => sensorData.temperature + (index * 0.25),
        growable: false,
      ),
      timestamp: DateTime.now(),
      deviceId: sensorData.deviceId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fault_prediction': faultPrediction,
      'fault_confidence': faultConfidence,
      'remaining_useful_life': remainingUsefulLife,
      'anomaly_status': anomalyStatus,
      'future_forecast_temp': futureForecastTemp,
      'maintenance_recommendation': maintenanceRecommendation,
      'health_score': healthScore,
      'risk_level': riskLevel,
      'forecast_series': forecastSeries,
      'timestamp': timestamp.toIso8601String(),
      'device_id': deviceId,
    };
  }

  static int _normalizeRulToHours(double rawValue) {
    // Handle normalized outputs from some models and convert to hours.
    final value = rawValue >= 0 && rawValue <= 1.5
        ? rawValue * 2000
        : rawValue;
    return value.round().clamp(0, 100000).toInt();
  }

  static int _faultSeverityWeight(String fault) {
    switch (fault.toUpperCase()) {
      case 'NORMAL':
        return 0;
      case 'DUST_FAULT':
        return 10;
      case 'OVERHEAT':
        return 20;
      case 'OVERLOAD':
        return 25;
      case 'VIBRATION_FAULT':
        return 25;
      case 'BEARING_WEAR':
        return 30;
      case 'FAILURE_IMMINENT':
        return 40;
      default:
        return 15;
    }
  }

  static int _calculateHealthScore({
    required String fault,
    required double faultConfidence,
    required int rul,
    required String anomalyStatus,
  }) {
    final severity = _faultSeverityWeight(fault);
    var score = 100;

    final confidencePenalty = ((faultConfidence / 100) * severity * 0.9).round();
    score -= confidencePenalty;

    if (anomalyStatus.toUpperCase() == 'ANOMALY') {
      score -= 20;
    }

    if (rul < 50) {
      score -= 30;
    } else if (rul < 150) {
      score -= 18;
    } else if (rul < 300) {
      score -= 8;
    }

    score -= (severity * 0.5).round();
    return score.clamp(0, 100).toInt();
  }

  static String _deriveRiskLevel({
    required String fault,
    required double faultConfidence,
    required int rul,
    required String anomalyStatus,
    required int healthScore,
  }) {
    final anomaly = anomalyStatus.toUpperCase() == 'ANOMALY';
    final severity = _faultSeverityWeight(fault);

    var riskScore = 0.0;
    riskScore += severity;
    riskScore += faultConfidence * 0.15;

    if (anomaly) {
      riskScore += 20;
    }

    if (healthScore < 30) {
      riskScore += 30;
    } else if (healthScore < 50) {
      riskScore += 20;
    } else if (healthScore < 70) {
      riskScore += 10;
    }

    if (rul < 10) {
      riskScore += 40;
    } else if (rul < 50) {
      riskScore += 30;
    } else if (rul < 100) {
      riskScore += 20;
    } else if (rul < 300) {
      riskScore += 10;
    }

    if (riskScore <= 30) {
      return 'LOW';
    }
    if (riskScore <= 60) {
      return 'MEDIUM';
    }
    if (riskScore <= 90) {
      return 'HIGH';
    }
    return 'CRITICAL';
  }

  static String _recommendationForFault(
    String fault,
    String anomalyStatus,
    String riskLevel,
  ) {
    final recommendation = switch (fault.toUpperCase()) {
      'NORMAL' => 'No Action Needed',
      'DUST_FAULT' => 'Inspect and replace air filters',
      'OVERHEAT' => 'Inspect Cooling System',
      'OVERLOAD' => 'Reduce Load',
      'VIBRATION_FAULT' => 'Inspect mounts and balance rotating components',
      'BEARING_WEAR' => 'Schedule bearing inspection and lubrication',
      'FAILURE_IMMINENT' => 'Immediate Shutdown Required',
      _ => 'Schedule maintenance inspection',
    };

    if (riskLevel.toUpperCase() == 'CRITICAL' && recommendation == 'No Action Needed') {
      return 'Immediate Shutdown Required';
    }
    if (anomalyStatus.toUpperCase() == 'ANOMALY' &&
        (riskLevel.toUpperCase() == 'HIGH' || riskLevel.toUpperCase() == 'CRITICAL')) {
      return '$recommendation (Anomaly escalation)';
    }

    return recommendation;
  }
}
