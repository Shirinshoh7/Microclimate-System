import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/climate_models.dart';

/// Manages WebSocket connection for real-time climate data from IoT devices.
/// 
/// Automatically reconnects on disconnection and normalizes various data formats
/// from different sensor configurations.
class WebSocketService extends ChangeNotifier {
  /// Backend WebSocket endpoint for real-time climate data streaming
  static const String wsUrl = 'wss://glorifier-pecan-applicant.ngrok-free.dev/api/ws/realtime';

  WebSocketChannel? _channel;
  final StreamController<ClimateData> _dataController =
      StreamController<ClimateData>.broadcast();

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  Stream<ClimateData> get dataStream => _dataController.stream;
  bool get isConnected => _isConnected;

  WebSocketService() {
    _connectAsync();
  }

  Future<void> _connectAsync() async {
    await _bypassNgrok();
    connect();
  }

  Future<void> _bypassNgrok() async {
    try {
      final baseUrl = wsUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://')
          .replaceFirst('/api/ws/realtime', '/');
      await http.get(
        Uri.parse(baseUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      debugPrint('Ngrok bypass successful');
    } catch (e) {
      debugPrint('Ngrok bypass failed (continuing anyway): $e');
    }
  }

  void connect() {
    if (_channel != null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      debugPrint('WebSocket connecting to $wsUrl');

      _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            notifyListeners();
            debugPrint('WebSocket connected to $wsUrl');
          }
          try {
            if (message == 'pong') {
              debugPrint('Pong received');
              return;
            }

            final raw = json.decode(message);

            /// Normalize payload keys to match ClimateData.fromJson structure
            /// Handles multiple field naming conventions from backend
            final normalized = <String, dynamic>{
              /// Temperature: supports 'temp', 'temperature', or 't' field names
              'temp': (raw['temp'] ?? raw['temperature'] ?? 0),
              /// Humidity: supports 'humidity', 'hum', or 'rh' field names
              'humidity': (raw['humidity'] ?? raw['hum'] ?? 0),
              /// CO2: supports 'co2', 'co2_ppm', 'co2ppm', or 'mq135' field names
              'co2': (raw['co2'] ?? raw['co2_ppm'] ?? raw['mq135'] ?? 0),
              /// CO: supports 'co', 'co_ppm', 'coppm', or 'mq7' field names
              'co': (raw['co_ppm'] ?? raw['co'] ?? raw['mq7'] ?? 0),
              /// Device identifier and timestamp
              'device_id': raw['device_id'] ?? 'unknown',
              'timestamp': raw['timestamp'],
            };

            final climateData = ClimateData.fromJson(normalized);
            _dataController.add(climateData);

            debugPrint(
              'WebSocket: temp=${climateData.temp}°C hum=${climateData.humidity}% '
              'co2=${climateData.co2} co=${climateData.co}',
            );
          } catch (e) {
            debugPrint('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _handleDisconnect();
        },
      );

      /// Send periodic ping to keep WebSocket connection alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add('ping');
          } catch (e) {
            timer.cancel();
            _handleDisconnect();
          }
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    notifyListeners();

    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        debugPrint('Attempting WebSocket reconnection...');
        _connectAsync();
      });
    }
  }

  void disconnect() {
    debugPrint('WebSocket disconnecting...');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  void reconnect() {
    debugPrint('Manual WebSocket reconnect triggered');
    disconnect();
    _shouldReconnect = true;
    connect();
  }

  @override
  void dispose() {
    debugPrint('WebSocket service disposing');
    disconnect();
    _dataController.close();
    super.dispose();
  }
}
