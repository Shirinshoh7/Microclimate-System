# MicroClimate AI Pro

A comprehensive Flutter mobile application for real-time environmental monitoring using IoT sensors and machine learning predictions.

## Features

- **Real-time Monitoring**: Live climate data streaming via WebSocket
- **Multi-Device Support**: Monitor and manage multiple IoT devices
- **Smart Profiles**: Create and manage environmental control profiles with customizable thresholds
- **Predictive Analytics**: AI-powered forecasts for temperature, humidity, CO2, and CO levels
- **Push Notifications**: Instant alerts when thresholds are exceeded
- **Data Visualization**: Interactive charts with multiple time range options (1h, 4h, 24h, 7d)
- **Cross-Platform**: Supports Android, iOS, Web, Windows, macOS, and Linux
- **Multi-Language**: English, Russian, and Kazakh localization
- **Dark Mode**: Complete dark theme support

## Tech Stack

### Frontend
- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **HTTP Client**: Dio
- **WebSocket**: web_socket_channel
- **Local Storage**: FlutterSecureStorage, SharedPreferences
- **Charts**: FL Chart
- **Notifications**: Firebase Cloud Messaging, flutter_local_notifications
- **Localization**: easy_localization
- **UI**: Material Design 3

## Getting Started

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart 3.0 or higher

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mobile_app_microclimate
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── core/                  # Core infrastructure
├── models/                # Data models
├── providers/             # State management
├── screens/               # UI screens
├── services/              # Business logic & API
├── widgets/               # Reusable widgets
└── utils/                 # Helper utilities
```

## Key Features

- **Authentication**: Secure login/registration with token management
- **Real-Time Data**: WebSocket connection for live sensor readings
- **Notifications**: Firebase Cloud Messaging integration
- **Data Analytics**: Interactive charts and historical data visualization
- **Multi-Language**: English, Russian, and Kazakh support

## Building for Production

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Documentation

For more detailed information, see the inline documentation within the source code.

## License

This project is provided for portfolio purposes.
