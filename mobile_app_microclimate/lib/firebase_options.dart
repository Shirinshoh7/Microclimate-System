import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANz1XcRpFjESkUx4nHy7mVKXqO4_k0rMM',
    appId: '1:482665616569:android:8757f18e75522bdeee7768',
    messagingSenderId: '482665616569',
    projectId: 'microclamite',
    storageBucket: 'microclamite.firebasestorage.app',
  );

  // Fill these values from Firebase Console -> Project Settings -> Web app.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: ''),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: ''),
    messagingSenderId: String.fromEnvironment(
        'FIREBASE_WEB_MESSAGING_SENDER_ID',
        defaultValue: ''),
    projectId: String.fromEnvironment('FIREBASE_WEB_PROJECT_ID',
        defaultValue: 'microclamite'),
    authDomain:
        String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN', defaultValue: ''),
    storageBucket: String.fromEnvironment(
      'FIREBASE_WEB_STORAGE_BUCKET',
      defaultValue: 'microclamite.firebasestorage.app',
    ),
    measurementId:
        String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID', defaultValue: ''),
  );

  static bool get hasWebConfig =>
      web.apiKey.isNotEmpty &&
      web.appId.isNotEmpty &&
      web.messagingSenderId.isNotEmpty &&
      web.projectId.isNotEmpty;
}
