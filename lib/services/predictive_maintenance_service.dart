import '../models/predictive_maintenance_result.dart';
import '../models/sensor_data.dart';

class PredictiveMaintenanceService {
  PredictiveMaintenanceService();

  Future<PredictiveMaintenanceResult> fetchPrediction(
    SensorData sensorData,
  ) async {
    final temperature = sensorData.temperature;
    final vibration = sensorData.vibration;
    final gas = sensorData.gas;
    final dust = sensorData.dust;
    final sound = sensorData.sound;

    String recommendation;
    String insight;
    String emoji;

    if (temperature >= 85 || vibration >= 4.5 || gas >= 700 || sound >= 95) {
      recommendation = 'Immediate Attention Required';
      insight =
          'Readings indicate severe stress across one or more safety-critical parameters.';
      emoji = '🚨';
    } else if (temperature >= 70 || vibration >= 2.8 || gas >= 450 || dust >= 250) {
      recommendation = 'Monitor Closely';
      insight =
          'Telemetry is elevated and trending toward warning levels that should be watched closely.';
      emoji = '⚠️';
    } else {
      recommendation = 'No Action Needed';
      insight = 'Sensors are within expected operating range with stable behavior.';
      emoji = '✅';
    }

    final riskLevel = switch (recommendation) {
      'No Action Needed' => 'LOW',
      'Monitor Closely' => 'MEDIUM',
      'Immediate Attention Required' => 'CRITICAL',
      _ => 'MEDIUM',
    };

    final faultPrediction = switch (recommendation) {
      'No Action Needed' => 'NORMAL',
      'Monitor Closely' => 'OVERLOAD',
      'Immediate Attention Required' => 'FAILURE_IMMINENT',
      _ => 'OVERLOAD',
    };

    final confidence = switch (recommendation) {
      'No Action Needed' => 30.0,
      'Monitor Closely' => 65.0,
      'Immediate Attention Required' => 90.0,
      _ => 55.0,
    };

    final healthScore = switch (recommendation) {
      'No Action Needed' => 85,
      'Monitor Closely' => 58,
      'Immediate Attention Required' => 25,
      _ => 50,
    };

    final remainingUsefulLife = switch (recommendation) {
      'No Action Needed' => 1400,
      'Monitor Closely' => 620,
      'Immediate Attention Required' => 120,
      _ => 500,
    };

    return PredictiveMaintenanceResult(
      faultPrediction: faultPrediction,
      faultConfidence: confidence,
      remainingUsefulLife: remainingUsefulLife,
      anomalyStatus: recommendation == 'Immediate Attention Required'
          ? 'ANOMALY'
          : 'NORMAL',
      futureForecastTemp: sensorData.temperature,
      maintenanceRecommendation: recommendation,
      healthScore: healthScore,
      riskLevel: riskLevel,
      forecastSeries: List<double>.generate(
        12,
        (index) => sensorData.temperature + (index * 0.2),
        growable: false,
      ),
      timestamp: DateTime.now(),
      deviceId: sensorData.deviceId,
      aiInsight: insight,
      aiEmoji: emoji,
    );
  }

  void dispose() {}
}
