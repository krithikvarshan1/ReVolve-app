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
- Fault classification & anomaly detection
- LSTM-based temperature forecasting
- AI-powered insights and recommendations

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

### 💬 In-App Chat Assistant
- Ollama LLM integration (optional)
- Built-in fallback knowledge base
- Context-aware help for all app features

### 🔐 Authentication
- Firebase Authentication (Email/Password, Google Sign-In)
- Biometric authentication (Android)
- Secure user management

### 📊 Usage & Maintenance Logs
- Comprehensive logging system
- Downloadable CSV & PDF reports
- Prediction history analytics

## Tech Stack

- **Frontend**: Flutter (Android, Web)
- **Backend**: FastAPI (Python) with ML model inference
- **Database**: Firebase (Firestore + Realtime Database)
- **ML Models**: XGBoost, Isolation Forest, LSTM (PyTorch)
- **Chat**: Ollama (optional, falls back gracefully)
- **State Management**: Provider
- **Charts**: FL Chart

## Project Structure

```
├── backend/
│   ├── main.py                 # FastAPI backend with ML inference
│   └── requirements.txt        # Python dependencies
├── models_ml/                  # Pre-trained ML models (.pkl, .pth)
├── lib/
│   ├── main.dart               # App entry point
│   ├── config/
│   │   ├── app_config.dart     # App configuration (env-driven)
│   │   ├── firebase_bootstrap.dart
│   │   └── firebase_options.dart
│   ├── models/                 # Data models
│   ├── services/               # Business logic & API calls
│   ├── providers/              # State management
│   ├── screens/                # UI screens
│   ├── widgets/                # Reusable widgets
│   ├── utils/                  # Constants & helpers
│   └── routes/                 # Navigation
├── .env.example                # Environment variable template
├── .firebase/
│   └── web.example.json        # Firebase config template
└── web/                        # Web-specific assets
```

## Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.0.0 | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Python | ≥ 3.9 | [python.org](https://python.org) |
| Node.js | ≥ 18 | [nodejs.org](https://nodejs.org) |

### 1. Clone & Install

```bash
git clone https://github.com/<your-username>/ReVolve-app.git
cd ReVolve-app

# Flutter dependencies
flutter pub get

# Node dependencies (for dev script)
npm install

# Python backend dependencies
pip install -r backend/requirements.txt
```

### 2. Configure Firebase

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/)
2. Enable **Authentication** (Email/Password + Google Sign-In)
3. Enable **Firestore Database**
4. Enable **Realtime Database**
5. Copy your web app config into `.firebase/web.json`:

```bash
cp .firebase/web.example.json .firebase/web.json
```

Then fill in the values:

```json
{
  "FIREBASE_WEB_API_KEY": "your-api-key",
  "FIREBASE_WEB_APP_ID": "your-app-id",
  "FIREBASE_WEB_MESSAGING_SENDER_ID": "your-sender-id",
  "FIREBASE_WEB_PROJECT_ID": "your-project-id",
  "FIREBASE_WEB_AUTH_DOMAIN": "your-project.firebaseapp.com",
  "FIREBASE_WEB_STORAGE_BUCKET": "your-project.appspot.com",
  "FIREBASE_WEB_MEASUREMENT_ID": "G-XXXXXXXXXX"
}
```

> [!NOTE]
> The app works **without** Firebase — it will start in offline/demo mode with
> limited functionality. Firebase is only needed for auth, cloud data, and live
> sensor streaming.

### 3. (Optional) Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 4. Run

**Backend + Frontend together (recommended):**

```bash
npm run dev
```

**Or run separately:**

```bash
# Terminal 1 – backend
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000

# Terminal 2 – Flutter web
flutter run -d chrome \
  --dart-define-from-file=.firebase/web.json \
  --dart-define=ML_BACKEND_URL=http://127.0.0.1:8000
```

**VS Code:** Press F5 — the included launch configuration handles Firebase config injection.

### 5. (Optional) Ollama Chat

For LLM-powered chat assistance:

```bash
# Install Ollama: https://ollama.com
ollama pull llama3
ollama serve
```

The backend auto-detects Ollama. If unavailable, the chat falls back to a built-in knowledge base.

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

The ESP32 should expose:

```
GET  /sensor-data     → { temperature, vibration, current, gas, sound, timestamp, deviceId }
POST /relay-control   → { deviceId, status }
```

Update `lib/config/app_config.dart` with your ESP32 IP:

```dart
static const String baseUrl = 'http://YOUR_ESP32_IP:8080';
```

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API info |
| GET | `/health` | Model & Ollama status |
| POST | `/predictive-maintenance` | Run ML inference |
| POST | `/chat-assistant` | Chat with assistant |
| GET | `/debug-models` | Model diagnostics |

### Predictive Maintenance Payload

```json
{
  "temperature": 45.0,
  "vibration": 2.1,
  "current": 5.2,
  "gas": 150.0,
  "dust": 80.0,
  "sound": 50.0,
  "deviceId": "esp32-001"
}
```

## Troubleshooting

```bash
# Clean Flutter build
flutter clean && flutter pub get

# Check connected devices
flutter devices

# Verbose Flutter run
flutter run -v

# Test backend independently
curl http://127.0.0.1:8000/health
```

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
