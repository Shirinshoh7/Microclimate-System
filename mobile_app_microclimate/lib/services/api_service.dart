import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../models/climate_models.dart';

/// Handles all API communication with the MicroClimate backend.
/// 
/// Manages authentication endpoints, device operations, and climate data.
/// Automatically includes authorization tokens in all requests.
class ApiService {
  ApiService(this.client);

  final ApiClient client;

  static String get baseUrl => ApiClient.baseUrl;
  Dio get _dio => client.dio;
  FlutterSecureStorage get _storage => client.storage;

  Future<void> register({
    required String espNumber,
    required String login,
    required String password,
  }) async {
    await _dio.post(
      '/api/auth/register',
      data: {
        'esp_number': espNumber,
        'device_id': espNumber,
        'login': login,
        'password': password,
      },
    );
  }

  Future<void> login({
    required String login,
    required String password,
  }) async {
    final response = await _dio.post(
      '/api/auth/login',
      data: {
        'login': login,
        'password': password,
      },
    );
    final data = _asMap(response.data);
    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('access_token is missing in login response');
    }
    await _storage.write(key: ApiClient.accessTokenKey, value: token);
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/api/auth/me');
    return _asMap(response.data);
  }

  Future<void> logout() async {
    await _storage.delete(key: ApiClient.accessTokenKey);
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: ApiClient.accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final response = await _dio.get('/api/devices');
    final payload = response.data;
    if (payload is List) {
      return payload.map((e) => _asMap(e)).toList();
    }
    final data = _asMap(payload);
    final items = data['devices'] ?? data['items'] ?? data['data'] ?? const [];
    if (items is! List) return const [];
    return items.map((e) => _asMap(e)).toList();
  }

  Future<void> registerDevice({
    required String deviceId,
    required String secret,
    String? name,
  }) async {
    await _dio.post(
      '/api/devices/register',
      data: {
        'device_id': deviceId,
        'secret': secret,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
  }

  Future<ClimateProfile> getThresholds(String deviceId) async {
    final response = await _dio.get('/api/devices/$deviceId/thresholds');
    final data = _asMap(response.data);
    return ClimateProfile.fromJson({
      ...data,
      if (data['name'] == null) 'name': 'Device $deviceId',
      if (data['id'] == null) 'id': deviceId,
    });
  }

  /// Загружает активный профиль + список пресетов для устройства.
  /// GET /api/profiles?device_id={deviceId}
  /// Ответ: { "active": {...}, "presets": [...] }
  Future<({ClimateProfile? active, List<ClimateProfile> presets})> getProfiles(
      String deviceId) async {
    final response = await _dio.get(
      '/api/profiles',
      queryParameters: {'device_id': deviceId},
    );
    final data = _asMap(response.data);

    final activeRaw = data['active'];
    final ClimateProfile? active = activeRaw is Map
        ? ClimateProfile.fromJson({
            ..._asMap(activeRaw),
            if (_asMap(activeRaw)['name'] == null) 'name': 'Текущий',
          })
        : null;

    final presetsRaw = data['presets'];
    final presets = <ClimateProfile>[];
    if (presetsRaw is List) {
      for (final p in presetsRaw) {
        if (p is Map) presets.add(ClimateProfile.fromJson(_asMap(p)));
      }
    }

    return (active: active, presets: presets);
  }

  /// Сохраняет профиль для конкретного устройства.
  /// POST /api/profile/update  body: { "device_id": "...", "name": "...", ... }
  Future<void> applyProfile({
    required String deviceId,
    required ClimateProfile profile,
  }) async {
    await _dio.post(
      '/api/profile/update',
      data: {
        'device_id': deviceId,
        ...profile.toJson()..remove('id'),
      },
    );
  }

  Future<void> updateThresholds({
    required String deviceId,
    required ClimateProfile profile,
  }) async {
    await _dio.put(
      '/api/devices/$deviceId/thresholds',
      data: profile.toJson()
        ..remove('id')
        ..remove('name'),
    );
  }

  Future<ApiResponse> getCurrentData({
    required String deviceId,
    String forecast = '30m',
    int? forecastMin,
  }) async {
    final response = await _dio.get(
      '/api/now',
      queryParameters: {
        'device_id': deviceId,
        if (forecastMin != null)
          'forecast_min': forecastMin
        else
          'forecast': forecast,
      },
    );
    return ApiResponse.fromJson(_asMap(response.data));
  }

  Future<ClimateStats> getStats({required String deviceId}) async {
    final response = await _dio.get(
      '/api/stats',
      queryParameters: {'device_id': deviceId},
    );
    return ClimateStats.fromJson(_asMap(response.data));
  }

  Future<HistoryResponse> getHistory({
    required String deviceId,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/api/history',
      queryParameters: {
        'device_id': deviceId,
        'limit': limit,
      },
    );
    final payload = response.data;
    if (payload is List) {
      return HistoryResponse.fromJson({'items': payload});
    }
    return HistoryResponse.fromJson(_asMap(payload));
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    await _dio.post(
      '/api/push/register',
      data: {
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<void> unregisterPushToken({required String token}) async {
    await _dio.post(
      '/api/push/unregister',
      data: {'token': token},
    );
  }

  Future<Map<String, dynamic>> pushStats() async {
    final response = await _dio.get('/api/push/stats');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> pushTest() async {
    final response = await _dio.post('/api/push/test');
    return _asMap(response.data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }
    return <String, dynamic>{};
  }
}
