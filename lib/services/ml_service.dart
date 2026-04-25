import 'dart:math';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';
import '../models/ml_prediction.dart';

class MLService {
  final Uuid _uuid = const Uuid();
  final Random _random = Random();

  // Simulate ML prediction based on sensor data
  MLPrediction predictLifecycle(List<SensorData> sensorHistory) {
    if (sensorHistory.isEmpty) {
      return _createDefaultPrediction();
    }

    final latestData = sensorHistory.last;

    // Calculate health score using weighted formula
    final healthScore = latestData.healthScore / 100.0; // 0-1

    // Deterministic failure probability — inverse of health score with no
    // random noise so the Failure Risk KPI stays stable on fixed inputs.
    final failureProbability = (1.0 - healthScore).clamp(0.0, 1.0);

    // Simulate RUL based on health score and degradation trend
    final degradationRate = _calculateDegradationRate(sensorHistory);
    final remainingUsefulLife = _calculateRUL(healthScore, degradationRate);

    // Generate AI insights
    final insights = _generateInsights(latestData, failureProbability, remainingUsefulLife);

    // Calculate degradation trend for each sensor
    final degradationTrend = _calculateDegradationTrends(sensorHistory);

    return MLPrediction(
      id: _uuid.v4(),
      remainingUsefulLife: remainingUsefulLife,
      failureProbability: failureProbability,
      insights: insights,
      degradationTrend: degradationTrend,
      timestamp: DateTime.now(),
      deviceId: latestData.deviceId,
    );
  }

  MLPrediction _createDefaultPrediction() {
    return MLPrediction(
      id: _uuid.v4(),
      remainingUsefulLife: 2000.0,
      failureProbability: 0.1,
      insights: ['System operating normally'],
      degradationTrend: {},
      timestamp: DateTime.now(),
      deviceId: 'unknown',
    );
  }

  double _calculateDegradationRate(List<SensorData> history) {
    if (history.length < 2) return 0.0;

    // Simple linear regression on health scores
    final healthScores = history.map((data) => data.healthScore).toList();
    final n = healthScores.length;
    final sumX = (n * (n - 1) / 2.0);
    final sumY = healthScores.reduce((a, b) => a + b);
    final sumXY = healthScores.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
    final sumXX = (n * (n - 1) * (2 * n - 1) / 6.0);

    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    return -slope; // Negative slope indicates degradation
  }

  double _calculateRUL(double healthScore, double degradationRate) {
    // Stable, deterministic formula: health score maps linearly to remaining
    // life hours. 100% health = 2000 h; 0% = 0 h.
    // The old slope-regression approach divided by a near-zero value, producing
    // wildly different results (51 h → 27 h → 32 h) for identical fixed inputs.
    const maxLifeHours = 2000.0;
    return (healthScore * maxLifeHours).clamp(0.0, maxLifeHours);
  }

  List<String> _generateInsights(SensorData data, double failureProb, double rul) {
    final insights = <String>[];

    if (data.temperature > AppConfig.temperatureThreshold * 0.8) {
      insights.add('High temperature detected - monitor cooling system');
    }

    if (data.vibration > AppConfig.vibrationThreshold * 0.8) {
      insights.add('Elevated vibration levels - check mounting and bearings');
    }

    if (data.gas > AppConfig.gasThreshold * 0.8) {
      insights.add('Gas levels rising - ensure proper ventilation');
    }

    if (data.dust > AppConfig.dustThreshold * 0.8) {
      insights.add('Dust concentration is trending upward - inspect filters and airflow');
    }

    if (failureProb > 0.7) {
      insights.add('High failure probability - schedule maintenance immediately');
    }

    if (rul < 500) {
      insights.add('Remaining useful life low - plan for replacement');
    }

    if (insights.isEmpty) {
      insights.add('System operating within normal parameters');
    }

    return insights;
  }

  Map<String, double> _calculateDegradationTrends(List<SensorData> history) {
    if (history.length < 2) return {};

    final trends = <String, double>{};
    final sensors = ['temperature', 'vibration', 'current', 'gas', 'dust', 'sound'];

    for (final sensor in sensors) {
      final values = history.map((data) {
        switch (sensor) {
          case 'temperature': return data.temperature;
          case 'vibration': return data.vibration;
          case 'current': return data.current;
          case 'gas': return data.gas;
          case 'dust': return data.dust;
          case 'sound': return data.sound;
          default: return 0.0;
        }
      }).toList();

      trends[sensor] = _calculateSlope(values);
    }

    return trends;
  }

  double _calculateSlope(List<double> values) {
    final n = values.length;
    if (n < 2) return 0.0;

    final sumX = (n * (n - 1) / 2.0);
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = values.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
    final sumXX = (n * (n - 1) * (2 * n - 1) / 6.0);

    return (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  }

  // Future method for API call to Python ML backend
  /*
  Future<MLPrediction> predictFromAPI(List<SensorData> sensorHistory) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.predictEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sensor_history': sensorHistory.map((data) => data.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return MLPrediction.fromJson(jsonData);
      } else {
        throw Exception('ML prediction failed');
      }
    } catch (e) {
      print('Error calling ML API: $e');
      // Fallback to local prediction
      return predictLifecycle(sensorHistory);
    }
  }
  */
}
