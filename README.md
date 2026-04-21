# ReVolve - AI-Powered Product Lifecycle Management System

A comprehensive Flutter application for monitoring IoT sensor data, predicting product lifecycle using machine learning, detecting anomalies, and performing automated safety actions.

## Features

### 🔄 Real-Time Dashboard
- Live sensor data monitoring (Temperature, Vibration, Current, Gas, Sound)
- Interactive charts with fl_chart
- Health score visualization with color-coded indicators
- Real-time data streaming every 2 seconds

### 🤖 Machine Learning Integration
- Remaining Useful Life (RUL) prediction
- Failure probability calculation
- AI-powered insights and recommendations
- Degradation trend analysis

### 🚨 Alert System
- Automatic anomaly detection
- Severity-based alert classification
- Real-time notifications
- Alert history and resolution tracking

### 🎛️ Device Control Panel
- Remote relay control (ON/OFF)
- Device status monitoring
- Auto-shutdown safety features
- Multi-device support

### 📍 GPS Tracking
- Device location monitoring
- Google Maps integration
- Real-time position updates

### 🔐 Authentication
- Firebase Authentication
- Biometric authentication (Fingerprint)
- Secure user management

### 📊 Usage & Maintenance Logs
- Comprehensive logging system
- Maintenance record tracking
- Usage analytics

## Tech Stack

- **Frontend**: Flutter (Android, iOS, Web, Desktop)
- **Backend**: Firebase (Firestore, Auth)
- **Maps**: Google Maps Flutter
- **Charts**: FL Chart
- **Authentication**: Local Auth + Firebase Auth
- **State Management**: Provider
- **ML**: Simulated (ready for Python backend integration)

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   └── app_config.dart       # App configuration
├── models/
│   ├── sensor_data.dart      # Sensor data model
│   ├── alert.dart            # Alert model
│   ├── device.dart           # Device model
│   ├── user.dart             # User model
│   └── ml_prediction.dart    # ML prediction model
├── services/
│   ├── sensor_service.dart   # Sensor data simulation
│   ├── ml_service.dart       # ML prediction logic
│   ├── firebase_service.dart # Firebase operations
│   ├── device_control_service.dart # Device control
│   ├── api_service.dart      # HTTP API calls
│   └── auth_service.dart     # Authentication
├── providers/
│   ├── auth_provider.dart    # Auth state management
│   ├── sensor_provider.dart  # Sensor data management
│   ├── alert_provider.dart   # Alert management
│   └── device_provider.dart  # Device management
├── screens/
│   ├── login_screen.dart     # Authentication screen
│   └── dashboard_screen.dart # Main dashboard
├── widgets/
│   ├── custom_button.dart    # Reusable button
│   ├── custom_text_field.dart # Reusable text field
│   ├── sensor_chart.dart     # Chart widget
│   └── alert_card.dart       # Alert display card
├── utils/
│   ├── constants.dart        # App constants
│   └── helpers.dart          # Utility functions
└── routes/
    └── app_routes.dart       # App navigation routes
```

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Install Flutter (version 3.0.0 or higher)
   ```bash
   flutter --version
   ```

2. **Android Studio**: For Android development and emulator
   - Install Android Studio
   - Set up Android SDK (API 21+)
   - Configure emulator or connect physical device

3. **VS Code**: Recommended IDE
   - Install Flutter and Dart extensions

### Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project called "revolve"

2. **Enable Services**
   - Enable Firestore Database
   - Enable Firebase Authentication
   - Enable Google Sign-In

3. **Add Android App**
   - Package name: `com.example.revolve`
   - Download `google-services.json`
   - Place it in `android/app/src/main/` directory

4. **Firestore Security Rules** (Basic setup)
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

### Google Maps Setup

1. **Get API Key**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Maps SDK for Android
   - Create API key

2. **Add to Android Manifest**
   - Open `android/app/src/main/AndroidManifest.xml`
   - Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key

### Installation

1. **Clone/Download the project**
   ```bash
   cd your-projects-directory
   # Copy the revolve folder to your Flutter projects directory
   ```

2. **Install Dependencies**
   ```bash
   cd revolve
   flutter pub get
   ```

3. **Run the App**

   **On VS Code:**
   - Open the project in VS Code
   - Press F5 or go to Run > Start Debugging
   - Select device (Android emulator/web)

   **From Terminal:**
   ```bash
   flutter run
   ```

   **For Android Device:**
   ```bash
   flutter run --device-id=YOUR_DEVICE_ID
   ```

   **For Web:**
   ```bash
   flutter run -d chrome
   ```

### Predictive Maintenance Backend (FastAPI)

The project now includes a Python backend in `backend/` that loads all trained
models from `models_ml/` once at startup and exposes a single unified endpoint.

1. **Install backend dependencies**
   ```bash
   pip install -r backend/requirements.txt
   ```

2. **Install Node scripts dependency (one time)**
   ```bash
   npm install
   ```

3. **Run backend + Flutter together**
   ```bash
   npm run dev
   ```

4. **Optional: run backend only**
   ```bash
   python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
   ```

5. **Optional: run Flutter only with backend URL**
   ```bash
   flutter run -d chrome --dart-define=ML_BACKEND_URL=http://127.0.0.1:8000
   ```

6. **API endpoint**
   - `POST /predictive-maintenance`
   - Expected sensor payload keys:
     `temperature`, `vibration`, `current`, `gas`, `dust`, `sound`, `deviceId`

## ESP32 Hardware Integration

### Hardware Requirements
- ESP32 microcontroller
- DS18B20 temperature sensor
- MPU6050 vibration sensor
- INA219 current sensor
- MQ-2 gas sensor
- Sound sensor
- NEO-6M GPS module (optional)

### ESP32 API Endpoints

The ESP32 should expose these endpoints:

```cpp
// GET /sensor-data
{
  "temperature": 25.5,
  "vibration": 2.1,
  "current": 5.2,
  "gas": 150.0,
  "sound": 45.0,
  "timestamp": "2024-01-01T12:00:00Z",
  "deviceId": "esp32-001"
}

// POST /relay-control
// Body: {"deviceId": "esp32-001", "status": true}
```

### Integration Steps

1. **Update API URLs** in `lib/config/app_config.dart`:
   ```dart
   static const String baseUrl = 'http://YOUR_ESP32_IP:8080';
   ```

2. **Uncomment API calls** in services:
   - `sensor_service.dart`: Use `fetchSensorDataFromESP32()`
   - `device_control_service.dart`: Use actual HTTP calls

## Python ML Backend Integration

### Backend Requirements
- Flask/FastAPI server
- Scikit-learn or TensorFlow
- Pandas for data processing

### ML API Endpoint

```python
# POST /predict
# Input: sensor history data
# Output: ML predictions

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json['sensor_history']
    # ML prediction logic here
    return {
        'remainingUsefulLife': 1500.0,
        'failureProbability': 0.15,
        'insights': ['Temperature spikes detected', 'System efficiency dropping'],
        'degradationTrend': {'temperature': 0.02, 'vibration': 0.01}
    }
```

### Integration Steps

1. **Update API URL** in `lib/config/app_config.dart`

2. **Uncomment ML API calls** in `ml_service.dart`:
   ```dart
   return await predictFromAPI(sensorHistory);
   ```

## Common Issues & Fixes

### Flutter Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Check devices
flutter devices

# Run with verbose logging
flutter run -v
```

### Android Issues
- **SDK Issues**: Ensure Android SDK 21+ is installed
- **Emulator**: Create AVD with API 21+
- **Permissions**: Check device permissions in AndroidManifest.xml

### Firebase Issues
- **google-services.json**: Ensure file is in correct location
- **SHA-1**: Add SHA-1 fingerprint for Android app

### Maps Issues
- **API Key**: Ensure Maps API is enabled and key is correct
- **Billing**: Enable billing for Maps API usage

## Development Workflow

1. **VS Code**: Primary development environment
2. **Android Studio**: For Android-specific debugging and emulator
3. **Hot Reload**: Use `r` in terminal for hot reload during development
4. **Testing**: Run `flutter test` for unit tests

## Future Enhancements

- [ ] Real ESP32 integration
- [ ] Python ML backend
- [ ] Push notifications
- [ ] Offline data sync
- [ ] Multi-device dashboard
- [ ] Advanced analytics
- [ ] Predictive maintenance scheduling

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the code comments for implementation details
