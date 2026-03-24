class AppConfig {
  static const String appName = 'ReVolve';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String sensorDataCollection = 'sensor_data';
  static const String alertsCollection = 'alerts';
  static const String devicesCollection = 'devices';
  static const String logsCollection = 'logs';

  // API Endpoints (for future ESP32 integration)
  static const String baseUrl = 'http://your-esp32-ip:8080'; // Replace with actual IP
  static const String sensorDataEndpoint = '/sensor-data';
  static const String relayControlEndpoint = '/relay-control';
  static const String predictEndpoint = '/predict'; // For ML backend

  // Thresholds for alerts
  static const double temperatureThreshold = 80.0; // Celsius
  static const double vibrationThreshold = 5.0; // g
  static const double gasThreshold = 500.0; // ppm
  static const double currentThreshold = 10.0; // A

  // ML Prediction weights (simulated)
  static const Map<String, double> healthWeights = {
    'temperature': 0.3,
    'vibration': 0.25,
    'current': 0.2,
    'gas': 0.15,
    'sound': 0.1,
  };

  // Update intervals
  static const Duration sensorUpdateInterval = Duration(seconds: 2);
  static const Duration mlPredictionInterval = Duration(seconds: 10);
}