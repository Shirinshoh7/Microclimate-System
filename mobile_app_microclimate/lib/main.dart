import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/climate_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/app_gate.dart';
import 'core/api_client.dart';
import 'services/api_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_shouldInitFirebase) {
    await _initializeFirebase();
  }
}

bool get _shouldInitFirebase =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final firebaseInitialized = await _initializeFirebase();
  if (firebaseInitialized && !kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('kk'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      child: MultiProvider(
        providers: [
          Provider(create: (_) => const FlutterSecureStorage()),
          Provider(
            create: (context) =>
                ApiClient(context.read<FlutterSecureStorage>()),
          ),
          Provider(
            create: (context) => ApiService(context.read<ApiClient>()),
          ),
          ChangeNotifierProvider(
            create: (context) => AuthProvider(
              context.read<ApiService>(),
              context.read<ApiClient>(),
            )..bootstrap(),
          ),
          ChangeNotifierProvider(
            create: (context) => ClimateProvider(context.read<ApiService>()),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'app_title'.tr(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF4F46E5),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F7FB),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F1117),
          ),
          home: const AppGate(),
        );
      },
    );
  }
}

Future<bool> _initializeFirebase() async {
  if (!_shouldInitFirebase) return false;

  if (kIsWeb && !DefaultFirebaseOptions.hasWebConfig) {
    debugPrint(
      'Firebase Web is not configured. Pass FIREBASE_WEB_* dart-defines.',
    );
    return false;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  return true;
}
