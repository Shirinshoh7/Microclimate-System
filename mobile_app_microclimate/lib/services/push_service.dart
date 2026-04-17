import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';

class PushService {
  PushService(this._apiService);

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService;

  static const String _channelBaseId = 'critical_alerts';
  static const String _channelName = 'Оповещения микроклимата';
  static const String _defaultTitle = 'Микроклимат';
  static const String _defaultBody =
      'Параметры микроклимата вышли за пределы нормы.';
  static const String _androidDefaultSoundName = 'default_notification';
  static const String systemSoundKey = 'system';
  static const String defaultSoundKey = 'default_notification';
  static const List<String> supportedSoundKeys = [
    systemSoundKey,
    defaultSoundKey,
  ];

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _isInitialized = false;
  bool _soundEnabled = true;
  String _notificationSoundKey = systemSoundKey;

  String get _channelId =>
      '${_channelBaseId}_${_soundEnabled ? 'sound' : 'silent'}_$_notificationSoundKey';

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static final RegExp _latinLetters = RegExp(r'[A-Za-z]');
  static final List<RegExp> _badBodyPatterns = [
    RegExp(r'не\s*норма', caseSensitive: false),
    RegExp(r'вне\s*нормы', caseSensitive: false),
    RegExp(r'not\s*normal', caseSensitive: false),
    RegExp(r'out\s*of\s*range', caseSensitive: false),
    RegExp(r'outside\s*limits?', caseSensitive: false),
  ];

  AndroidNotificationSound? _androidSound() {
    if (!_soundEnabled) return null;
    switch (_notificationSoundKey) {
      case defaultSoundKey:
        return const RawResourceAndroidNotificationSound(
            _androidDefaultSoundName);
      case systemSoundKey:
      default:
        return null;
    }
  }

  String? _iosSound() {
    if (!_soundEnabled) return null;
    if (_notificationSoundKey == defaultSoundKey) {
      return 'default_notification.aiff';
    }
    return 'default';
  }

  Future<void> init() async {
    if (kIsWeb || _isInitialized) return;

    await _configureLocalNotifications();
    if (_isDesktop) {
      _isInitialized = true;
      return;
    }

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _fcm.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
      await _registerToken(newToken);
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((msg) async {
      final notification = msg.notification;
      if (notification == null) return;
      final title = _normalizeTitle(notification.title);
      final body = _normalizeBody(notification.body);

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Critical microclimate alerts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: _soundEnabled,
        enableVibration: true,
        sound: _androidSound(),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: _soundEnabled,
        sound: _iosSound(),
      );

      await _localNotifications.show(
        notification.hashCode,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
    });

    _isInitialized = true;
  }

  Future<void> unregister() async {
    if (kIsWeb || _isDesktop) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    await _apiService.unregisterPushToken(token: token);
  }

  Future<void> _configureLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    for (final soundKey in supportedSoundKeys) {
      await android
          ?.deleteNotificationChannel('${_channelBaseId}_sound_$soundKey');
      await android
          ?.deleteNotificationChannel('${_channelBaseId}_silent_$soundKey');
    }

    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Critical microclimate alerts',
      importance: Importance.max,
      playSound: _soundEnabled,
      sound: _androidSound() as RawResourceAndroidNotificationSound?,
    );

    await android?.createNotificationChannel(channel);
    await android?.requestNotificationsPermission();
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setNotificationSound(String soundKey) {
    if (supportedSoundKeys.contains(soundKey)) {
      _notificationSoundKey = soundKey;
    } else {
      _notificationSoundKey = systemSoundKey;
    }
  }

  Future<void> applySoundSettings() async {
    if (kIsWeb || !_isInitialized) return;
    await _configureLocalNotifications();
  }

  Future<void> _registerToken(String token) async {
    await _apiService.registerPushToken(
      token: token,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    );
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _isInitialized = false;
  }

  Future<void> disable() async {
    await unregister();
    dispose();
  }

  Future<void> showLocalAlert({
    required String body,
    String? title,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await init();
    }
    final safeTitle = _normalizeTitle(title);
    final safeBody = _normalizeBody(body);
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        safeTitle,
        safeBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Critical microclimate alerts',
            importance: Importance.max,
            priority: Priority.high,
            playSound: _soundEnabled,
            enableVibration: true,
            sound: _androidSound(),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: _soundEnabled,
            sound: _iosSound(),
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: _soundEnabled,
            sound: _iosSound(),
          ),
        ),
      );
    } on MissingPluginException {
      // Ignore if the current desktop target has no notifications plugin.
    }
  }

  String _normalizeTitle(String? raw) {
    final title = (raw ?? '').trim();
    if (title.isEmpty || _latinLetters.hasMatch(title)) {
      return _defaultTitle;
    }
    return title;
  }

  String _normalizeBody(String? raw) {
    final body = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (body.isEmpty || _latinLetters.hasMatch(body)) {
      return _defaultBody;
    }
    for (final pattern in _badBodyPatterns) {
      if (pattern.hasMatch(body)) {
        return _defaultBody;
      }
    }
    return body;
  }
}
