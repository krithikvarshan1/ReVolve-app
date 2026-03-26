class AppConstants {
  // App Info
  static const String appName = 'ReVolve';
  static const String appVersion = '1.0.0';

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);
  static const Duration longAnimationDuration = Duration(milliseconds: 1000);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 4.0;

  // Chart Constants
  static const int maxChartPoints = 50;
  static const Duration chartUpdateInterval = Duration(seconds: 2);

  // Sensor thresholds (for alerts)
  static const double temperatureThreshold = 80.0;
  static const double vibrationThreshold = 5.0;
  static const double currentThreshold = 10.0;
  static const double gasThreshold = 500.0;
  static const double soundThreshold = 90.0;

  // Health score weights
  static const Map<String, double> healthWeights = {
    'temperature': 0.3,
    'vibration': 0.25,
    'current': 0.2,
    'gas': 0.15,
    'sound': 0.1,
  };

  // ML Constants
  static const double maxHealthScore = 100.0;
  static const double maxRULHours = 2000.0;
  static const int mlHistoryWindow = 50; // Number of data points for ML

  // Firebase collection names
  static const String sensorDataCollection = 'sensor_data';
  static const String alertsCollection = 'alerts';
  static const String devicesCollection = 'devices';
  static const String logsCollection = 'logs';
  static const String mlPredictionsCollection = 'ml_predictions';

  // API endpoints
  static const String sensorDataEndpoint = '/sensor-data';
  static const String relayControlEndpoint = '/relay-control';
  static const String predictEndpoint = '/predict';
  static const String deviceConfigEndpoint = '/device-config';
  static const String firmwareUpdateEndpoint = '/update-firmware';

  // Update intervals
  static const Duration sensorUpdateInterval = Duration(seconds: 2);
  static const Duration mlPredictionInterval = Duration(seconds: 10);
  static const Duration deviceHealthCheckInterval = Duration(minutes: 5);

  // Error messages
  static const String networkError = 'Network connection failed';
  static const String authenticationError = 'Authentication failed';
  static const String sensorError = 'Sensor data unavailable';
  static const String deviceError = 'Device communication failed';

  // Success messages
  static const String loginSuccess = 'Login successful';
  static const String logoutSuccess = 'Logout successful';
  static const String dataSaved = 'Data saved successfully';
  static const String deviceUpdated = 'Device updated successfully';
}