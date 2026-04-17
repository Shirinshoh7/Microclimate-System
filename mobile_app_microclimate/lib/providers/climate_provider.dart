import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/climate_models.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import '../services/websocket_service.dart';

/// Manages climate monitoring data and device state.
/// 
/// Handles real-time data streaming via WebSocket, historical data fetching,
/// user notifications, and device profile management.
class ClimateProvider extends ChangeNotifier {
  ClimateProvider(this._apiService) : _pushService = PushService(_apiService) {
    _initialize();
  }

  static const String _logsKey = 'event_logs';
  static const String _selectedDeviceKey = 'selected_device_id';
  static const int _maxLogs = 100;

  final ApiService _apiService;
  final PushService _pushService;
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription<ClimateData>? _wsSub;

  ClimateData? _currentData;
  Predictions? _predictions;
  double? _prediction;
  final List<ClimateData> _history = [];
  ClimateStats? _stats;

  List<ClimateProfile> _profiles = [];
  ClimateProfile? _activeProfile;

  bool _isLoading = false;
  bool _isDeviceLoading = false;
  bool _serverOnline = false;
  String? _error;

  final List<EventLog> _logs = [];

  String _forecastHorizon = '30m';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _notificationSound = PushService.systemSoundKey;

  Timer? _httpRefreshTimer;
  bool _pushInitialized = false;

  String? _lastAlertHash;
  DateTime? _lastAlertTime;

  List<Map<String, dynamic>> _devices = [];
  String? _selectedDeviceId;

  ClimateData? get currentData => _currentData;
  double? get prediction => _prediction;
  Predictions? get predictions => _predictions;
  List<ClimateData> get history => _history;
  ClimateStats? get stats => _stats;
  List<ClimateProfile> get profiles => _profiles;
  ClimateProfile? get activeProfile => _activeProfile;
  bool get isLoading => _isLoading;
  bool get isDeviceLoading => _isDeviceLoading;
  bool get serverOnline => _serverOnline;
  String? get error => _error;
  List<EventLog> get logs => _logs;
  List<EventLog> get notificationLogs =>
      _logs.where((l) => l.type == 'Alert').toList();
  String get forecastHorizon => _forecastHorizon;
  bool get pushInitialized => _pushInitialized;
  bool get wsConnected => _webSocketService.isConnected;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  String get notificationSound => _notificationSound;
  List<Map<String, dynamic>> get devices => _devices;
  String? get selectedDeviceId => _selectedDeviceId;
  bool get hasSelectedDevice =>
      _selectedDeviceId != null && _selectedDeviceId!.isNotEmpty;

  Future<void> _initialize() async {
    await _loadSettings();
    await _loadSelectedDevice();
  }

  Future<void> bootstrapAfterAuth() async {
    if (_notificationsEnabled) {
      await _initPush();
    }
    await loadDevices();
    await _ensureSelectedDeviceFromProfile();
    if (_selectedDeviceId != null) {
      _startRealtimeStream();
      await loadProfiles();
      await refreshData();
      await loadHistory();
      await loadStats();
      _startHttpAutoRefresh();
    } else {
      _httpRefreshTimer?.cancel();
      _currentData = null;
      _history.clear();
      _predictions = null;
    }
    notifyListeners();
  }

  Future<void> clearSessionState() async {
    _httpRefreshTimer?.cancel();
    _wsSub?.cancel();
    _wsSub = null;
    _devices = [];
    _selectedDeviceId = null;
    _currentData = null;
    _history.clear();
    _predictions = null;
    _activeProfile = null;
    _profiles = [];
    await _pushService.disable();
    _pushInitialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedDeviceKey);
    notifyListeners();
  }

  Future<void> _initPush() async {
    if (!_notificationsEnabled || _pushInitialized) return;
    try {
      _pushService.setSoundEnabled(_soundEnabled);
      _pushService.setNotificationSound(_notificationSound);
      await _pushService.init();
      _pushInitialized = true;
      _addLog('Push token registered', 'System');
    } catch (e) {
      _addLog('Push init failed: $e', 'Error');
    }
  }

  Future<void> ensurePushInitialized() async {
    if (_notificationsEnabled) {
      await _initPush();
    } else {
      await _pushService.disable();
      _pushInitialized = false;
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHorizon = prefs.getString('forecast_horizon');
    if (savedHorizon != null &&
        {'30m', '3h', '24h', '1h', '4h', '7d'}.contains(savedHorizon)) {
      _forecastHorizon = savedHorizon;
    }
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _notificationSound =
        prefs.getString('notification_sound') ?? PushService.systemSoundKey;

    final savedLogs = prefs.getString(_logsKey);
    if (savedLogs != null && savedLogs.isNotEmpty) {
      try {
        final rawList = json.decode(savedLogs) as List<dynamic>;
        _logs
          ..clear()
          ..addAll(
            rawList
                .whereType<Map>()
                .map((e) => EventLog.fromJson(Map<String, dynamic>.from(e)))
                .toList()
              ..sort((a, b) => b.time.compareTo(a.time)),
          );
      } catch (_) {}
    }
  }

  Future<void> _loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedDeviceId = prefs.getString(_selectedDeviceKey);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('forecast_horizon', _forecastHorizon);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setString('notification_sound', _notificationSound);
  }

  Future<void> loadDevices() async {
    _isDeviceLoading = true;
    notifyListeners();
    try {
      _devices = await _apiService.getDevices();
      if (_selectedDeviceId != null &&
          _devices.isNotEmpty &&
          !_devices.any((d) => _resolveDeviceId(d) == _selectedDeviceId)) {
        _selectedDeviceId = null;
      }
      if (_selectedDeviceId == null && _devices.isNotEmpty) {
        _devices.sort((a, b) {
          final aSeen = DateTime.tryParse(a['last_seen']?.toString() ?? '');
          final bSeen = DateTime.tryParse(b['last_seen']?.toString() ?? '');
          if (aSeen == null && bSeen == null) return 0;
          if (aSeen == null) return 1;
          if (bSeen == null) return -1;
          return bSeen.compareTo(aSeen);
        });
        _selectedDeviceId = _resolveDeviceId(_devices.first);
        await _persistSelectedDevice();
      }
      if (_selectedDeviceId == null) {
        await _ensureSelectedDeviceFromProfile();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      _addLog('Failed to load devices: $e', 'Error');
    } finally {
      _isDeviceLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerDevice({
    required String deviceId,
    required String secret,
    String? name,
  }) async {
    await _apiService.registerDevice(
      deviceId: deviceId,
      secret: secret,
      name: name,
    );
    await loadDevices();
  }

  Future<void> setSelectedDevice(String deviceId) async {
    _selectedDeviceId = deviceId;
    await _persistSelectedDevice();
    _startRealtimeStream();
    await loadProfiles();
    await refreshData();
    await loadHistory();
    await loadStats();
    _startHttpAutoRefresh();
    notifyListeners();
  }

  Future<void> rememberSelectedDevice(String deviceId) async {
    final normalized = deviceId.trim();
    if (normalized.isEmpty) return;
    _selectedDeviceId = normalized;
    await _persistSelectedDevice();
    notifyListeners();
  }

  Future<void> _ensureSelectedDeviceFromProfile() async {
    if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty) return;
    try {
      final profile = await _apiService.me();
      final candidate = _extractDeviceIdFromProfile(profile);
      if (candidate != null && candidate.isNotEmpty) {
        _selectedDeviceId = candidate;
        await _persistSelectedDevice();
      }
    } catch (_) {}
  }

  String? _extractDeviceIdFromProfile(Map<String, dynamic> profile) {
    String? pick(Map<String, dynamic> m) {
      final value = m['device_id'] ?? m['esp_number'] ?? m['espNumber'] ?? m['deviceId'];
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return null;
      return text;
    }

    final direct = pick(profile);
    if (direct != null) return direct;

    final user = profile['user'];
    if (user is Map) {
      return pick(Map<String, dynamic>.from(user));
    }

    final data = profile['data'];
    if (data is Map) {
      return pick(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<void> _persistSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedDeviceId == null) {
      await prefs.remove(_selectedDeviceKey);
      return;
    }
    await prefs.setString(_selectedDeviceKey, _selectedDeviceId!);
  }

  String _resolveDeviceId(Map<String, dynamic> device) {
    return device['device_id']?.toString() ?? device['id']?.toString() ?? '';
  }

  List<ClimateProfile> _mergeProfiles(ClimateProfile? serverProfile) {
    final result = <ClimateProfile>[];
    if (serverProfile != null) {
      result.add(serverProfile);
    }
    for (final preset in ClimateProfile.defaults) {
      final exists = result.any((p) =>
          (p.id != null && p.id == preset.id) || p.name == preset.name);
      if (!exists) {
        result.add(preset);
      }
    }
    return result;
  }

  /// Объединяет серверные пресеты с локальными дефолтами.
  /// Серверные пресеты имеют приоритет над дефолтными с тем же именем.
  List<ClimateProfile> _mergeProfilesFromServer(
    ClimateProfile? active,
    List<ClimateProfile> serverPresets,
  ) {
    final result = <ClimateProfile>[];
    if (active != null) result.add(active);
    for (final p in serverPresets) {
      final exists = result.any((r) =>
          (r.id != null && r.id == p.id) || r.name == p.name);
      if (!exists) result.add(p);
    }
    // Добавляем локальные дефолты если сервер не вернул пресеты
    if (serverPresets.isEmpty) {
      for (final preset in ClimateProfile.defaults) {
        final exists = result.any((r) =>
            (r.id != null && r.id == preset.id) || r.name == preset.name);
        if (!exists) result.add(preset);
      }
    }
    return result;
  }

  void _startHttpAutoRefresh() {
    _httpRefreshTimer?.cancel();
    if (_selectedDeviceId == null) return;
    _httpRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshData();
    });
  }

  void _startRealtimeStream() {
    _wsSub?.cancel();
    _wsSub = _webSocketService.dataStream.listen((incoming) {
      if (_selectedDeviceId == null) return;
      if (incoming.deviceId != _selectedDeviceId && incoming.deviceId != 'unknown') {
        return;
      }

      _currentData = incoming;
      _predictions = incoming.predictions ?? _predictions;
      _serverOnline = true;
      _error = null;
      _history.add(incoming);
      if (_history.length > 50) _history.removeAt(0);
      _checkAlerts();
      notifyListeners();
    });
  }

  Future<void> refreshData() async {
    if (_selectedDeviceId == null) return;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getCurrentData(
        deviceId: _selectedDeviceId!,
        forecastMin: _horizonToMinutes(_forecastHorizon),
      );

      _prediction = response.prediction;
      _predictions = response.current.predictions ?? _predictions;
      _currentData = response.current;
      _serverOnline = true;

      if (_currentData != null) {
        _history.add(_currentData!);
        if (_history.length > 20) _history.removeAt(0);
      }

      await loadHistory(limit: 50, silent: true);
      await loadStats(silent: true);

      _checkAlerts();
      _addLog('HTTP data updated', 'System');
    } catch (e) {
      final raw = e.toString();
      _error = _friendlyError(raw);
      _serverOnline = false;
      _addLog('Failed to fetch data: $_error', 'Error');
      if (raw.contains('404') && raw.toLowerCase().contains('device not found')) {
        _selectedDeviceId = null;
        await _persistSelectedDevice();
        await loadDevices();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _checkAlerts() {
    if (_currentData == null || _activeProfile == null) return;

    final alerts = <String>[];

    if (_currentData!.temp < _activeProfile!.tempMin ||
        _currentData!.temp > _activeProfile!.tempMax) {
      alerts.add(
        'Температура ${_currentData!.temp.toStringAsFixed(1)}°C вне нормы',
      );
    }

    if (_currentData!.humidity > _activeProfile!.humidityMax) {
      alerts.add(
          'Влажность ${_currentData!.humidity.toStringAsFixed(0)}% выше нормы');
    }
    if (_currentData!.co2 > _activeProfile!.co2Max) {
      alerts.add('CO2 ${_currentData!.co2.toStringAsFixed(0)} ppm выше нормы');
    }
    if (_currentData!.co > _activeProfile!.coMax) {
      alerts.add('CO ${_currentData!.co.toStringAsFixed(0)} ppm выше нормы');
    }

    if (alerts.isEmpty) return;

    final msg = alerts.join(' | ');
    final hash = '${_activeProfile!.name}::$msg';
    final now = DateTime.now();
    if (_lastAlertHash == hash &&
        _lastAlertTime != null &&
        now.difference(_lastAlertTime!).inSeconds < 10) {
      return;
    }
    _lastAlertHash = hash;
    _lastAlertTime = now;
    _addLog(msg, 'Alert');
    if (_notificationsEnabled) {
      unawaited(_pushService.showLocalAlert(body: msg));
    }
  }

  Future<void> loadProfiles() async {
    if (_selectedDeviceId == null) {
      _profiles = [];
      _activeProfile = null;
      notifyListeners();
      return;
    }

    try {
      final result = await _apiService.getProfiles(_selectedDeviceId!);
      _activeProfile = result.active;
      // Объединяем серверные пресеты с локальными дефолтами
      _profiles = _mergeProfilesFromServer(result.active, result.presets);
      _addLog('Profiles loaded', 'System');
      notifyListeners();
    } catch (e) {
      _addLog('Failed to load profiles: $e', 'Error');
      // Фоллбэк — пробуем старый endpoint с порогами
      try {
        final thresholds = await _apiService.getThresholds(_selectedDeviceId!);
        _activeProfile = thresholds;
        _profiles = _mergeProfiles(thresholds);
      } catch (_) {
        _profiles = _mergeProfiles(null);
        _activeProfile = null;
      }
      notifyListeners();
    }
  }

  Future<void> loadHistory({int limit = 50, bool silent = false}) async {
    if (_selectedDeviceId == null) return;
    try {
      final response = await _apiService.getHistory(
        deviceId: _selectedDeviceId!,
        limit: limit,
      );
      final serverHistory = response.items.map(_historyEntryToClimateData).toList();
      if (serverHistory.isNotEmpty) {
        _history
          ..clear()
          ..addAll(serverHistory);
      }
      if (!silent) notifyListeners();
    } catch (e) {
      _addLog('Failed to load history: $e', 'Error');
    }
  }

  Future<void> loadStats({bool silent = false}) async {
    if (_selectedDeviceId == null) return;
    try {
      _stats = await _apiService.getStats(deviceId: _selectedDeviceId!);
      if (!silent) notifyListeners();
    } catch (e) {
      _addLog('Failed to load stats: $e', 'Error');
    }
  }

  ClimateData _historyEntryToClimateData(HistoryEntry item) {
    return ClimateData(
      temp: item.temp,
      humidity: item.hum,
      co2: item.co2,
      co: item.co,
      mcScore: 0,
      timestamp: item.time.toIso8601String(),
      deviceId: _selectedDeviceId ?? 'unknown',
      profile: _activeProfile?.name ?? 'device-thresholds',
    );
  }

  Future<void> setActiveProfile(ClimateProfile profile) async {
    _activeProfile = profile;
    notifyListeners();
  }

  void addProfile(ClimateProfile profile) {}

  Future<void> updateProfile(ClimateProfile profile) async {
    if (_selectedDeviceId == null) return;
    try {
      await _apiService.applyProfile(
        deviceId: _selectedDeviceId!,
        profile: profile,
      );
      _activeProfile = profile;
      _profiles = _mergeProfilesFromServer(profile, []);
      _addLog('Profile updated', 'System');
      _checkAlerts();
      notifyListeners();
    } catch (e) {
      _addLog('Failed to update profile: $e', 'Error');
      rethrow;
    }
  }

  void deleteProfile(ClimateProfile profile) {}

  static int _horizonToMinutes(String horizon) {
    switch (horizon) {
      case '1h': return 60;
      case '4h': return 240;
      case '7d': return 10080;
      case '3h': return 180;
      case '24h': return 1440;
      default: return 30;
    }
  }

  void setForecastHorizon(String horizon) {
    if (!{'30m', '3h', '24h', '1h', '4h', '7d'}.contains(horizon)) return;
    _forecastHorizon = horizon;
    _saveSettings();
    refreshData();
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _saveSettings();
    if (enabled) {
      await _initPush();
    } else {
      await _pushService.disable();
      _pushInitialized = false;
    }
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    _pushService.setSoundEnabled(enabled);
    await _pushService.applySoundSettings();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setNotificationSound(String soundKey) async {
    _notificationSound = soundKey;
    _pushService.setNotificationSound(soundKey);
    await _pushService.applySoundSettings();
    await _saveSettings();
    notifyListeners();
  }

  void _addLog(String message, String type) {
    _logs.insert(
        0, EventLog(time: DateTime.now(), message: message, type: type));
    if (_logs.length > _maxLogs) _logs.removeLast();
    _saveLogs();
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(_logs.map((e) => e.toJson()).toList());
    await prefs.setString(_logsKey, data);
  }

  bool isDangerMode() {
    if (_currentData == null || _activeProfile == null) return false;
    return _currentData!.temp > _activeProfile!.tempMax ||
        _currentData!.temp < _activeProfile!.tempMin ||
        _currentData!.humidity > _activeProfile!.humidityMax ||
        _currentData!.co2 > _activeProfile!.co2Max ||
        _currentData!.co > _activeProfile!.coMax;
  }

  @override
  void dispose() {
    _httpRefreshTimer?.cancel();
    _wsSub?.cancel();
    _webSocketService.dispose();
    _pushService.dispose();
    super.dispose();
  }

  String _friendlyError(String raw) {
    final text = raw.toLowerCase();
    if (text.contains('device not found')) return 'Device not found';
    if (text.contains('401')) return 'Session expired. Please log in again';
    if (text.contains('timeout') || text.contains('connection')) {
      return 'No connection to server';
    }
    return 'Data loading error';
  }
}
