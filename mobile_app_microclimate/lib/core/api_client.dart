import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient(this.storage)
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {
              'Content-Type': 'application/json',
              'Bypass-Tunnel-Reminder': 'true',
              'ngrok-skip-browser-warning': 'true',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ensure ngrok bypass header is always present
          options.headers['ngrok-skip-browser-warning'] = 'true';
          final token = await storage.read(key: accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Initializes ngrok bypass: sends a HEAD request to bypass ngrok browser warning.
  /// Call this once during app startup to unlock ngrok tunnel in web environments.
  Future<void> warmUp() async {
    try {
      final bypassDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {
          'ngrok-skip-browser-warning': 'true',
          'Bypass-Tunnel-Reminder': 'true',
        },
        validateStatus: (_) => true,
      ));
      await bypassDio.get(baseUrl);
      debugPrint('API warmUp: ngrok bypass successful');
    } catch (e) {
      debugPrint('API warmUp failed (continuing anyway): $e');
    }
  }

  static const String baseUrl = 'https://glorifier-pecan-applicant.ngrok-free.dev/';
  static const String accessTokenKey = 'access_token';

  final Dio dio;
  final FlutterSecureStorage storage;
}
