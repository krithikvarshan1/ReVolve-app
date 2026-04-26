import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/predictive_maintenance_result.dart';
import '../models/sensor_data.dart';

class PredictiveMaintenanceService {
  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 30);

  PredictiveMaintenanceService({http.Client? client})
      : _client = client ?? http.Client();

  Future<PredictiveMaintenanceResult> fetchPrediction(
    SensorData sensorData,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
              '${AppConfig.mlBackendBaseUrl}${AppConfig.predictiveMaintenanceEndpoint}',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode(sensorData.toJson()),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        print('Predictive backend success: ${response.statusCode}');
        return PredictiveMaintenanceResult.fromJson(
          jsonData,
          deviceId: sensorData.deviceId,
        );
      }

      throw Exception(
        'Backend predictive maintenance failed: ${response.statusCode}',
      );
    } catch (e) {
      print('Predictive backend fallback engaged: $e');
      final temperature = sensorData.temperature;
      final vibration = sensorData.vibration;
      final current = sensorData.current;
      final gas = sensorData.gas;
      final dust = sensorData.dust;
      final sound = sensorData.sound;

      final tempNorm = (temperature / 120.0).clamp(0.0, 1.8);
      final vibNorm = (vibration / 10.0).clamp(0.0, 2.0);
      final currNorm = (current / 12.0).clamp(0.0, 2.0);
      final gasNorm = (gas / 5000.0).clamp(0.0, 1.5);
      final dustNorm = (dust / 4000.0).clamp(0.0, 1.5);
      final soundNorm = (sound / 120.0).clamp(0.0, 1.5);

      final degradation = (0.28 * tempNorm) +
          (0.24 * vibNorm) +
          (0.18 * currNorm) +
          (0.16 * gasNorm) +
          (0.08 * dustNorm) +
          (0.06 * soundNorm);

      final continuousRul = (1500.0 * (1.0 - 0.78 * degradation)).clamp(10.0, 1500.0);
      final remainingUsefulLife = continuousRul.round();

      final continuousHealth = (100.0 - (degradation * 85.0)).clamp(0.0, 100.0);
      final healthScore = continuousHealth.round();

      final riskScore = ((100.0 - continuousHealth) * 0.55) +
          (((300.0 - continuousRul).clamp(0.0, 300.0) / 300.0) * 35.0);
      final riskLevel = riskScore < 30
          ? 'LOW'
          : riskScore < 60
              ? 'MEDIUM'
              : riskScore < 85
                  ? 'HIGH'
                  : 'CRITICAL';

      final anomalyFlag = riskScore >= 68.0 || gas > 4600 || vibration > 8.8;
      final anomalyStatus = anomalyFlag ? 'ANOMALY' : 'NORMAL';

      final faultPrediction = anomalyFlag
          ? (riskScore >= 85 ? 'FAILURE_IMMINENT' : 'OVERLOAD')
          : 'NORMAL';

      final confidence = (45.0 + (degradation * 52.0)).clamp(35.0, 97.0);

      final recommendation = riskLevel == 'LOW'
          ? 'No Action Needed'
          : riskLevel == 'MEDIUM'
              ? 'Monitor Closely'
              : riskLevel == 'HIGH'
                  ? 'Schedule Inspection'
                  : 'Immediate Attention Required';

      final insight =
          'Live readings were analyzed using continuous local fallback because backend prediction was unavailable.';
      final emoji = anomalyFlag ? '⚠️' : '✅';

      return PredictiveMaintenanceResult(
        faultPrediction: faultPrediction,
        faultConfidence: confidence,
        remainingUsefulLife: remainingUsefulLife,
        anomalyStatus: anomalyStatus,
        futureForecastTemp: sensorData.temperature,
        maintenanceRecommendation: recommendation,
        healthScore: healthScore,
        riskLevel: riskLevel,
        forecastSeries: const [],
        lstmForecast: _buildDescendingRulForecast(remainingUsefulLife),
        timestamp: DateTime.now(),
        deviceId: sensorData.deviceId,
        aiInsight: insight,
        aiEmoji: emoji,
      );
    }
  }

  void dispose() {
    _client.close();
  }

  List<double> _buildDescendingRulForecast(int rul, {int steps = 12}) {
    final start = rul.toDouble().clamp(0.0, 100000.0);
    final decay = start <= 0 ? 0.0 : (start / (steps + 2)).clamp(1.0, 50.0);
    return List<double>.generate(
      steps,
      (index) => (start - (decay * index)).clamp(0.0, 100000.0).toDouble(),
      growable: false,
    );
  }
}
