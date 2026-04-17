import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/climate_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _sessionBootstrapped = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ClimateProvider>(
      builder: (context, auth, climate, _) {
        if (auth.isBootstrapping) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!auth.isAuthenticated) {
          _sessionBootstrapped = false;
          return const LoginScreen();
        }

        if (!_sessionBootstrapped) {
          _sessionBootstrapped = true;
          Future.microtask(() => climate.bootstrapAfterAuth());
        }

        if (climate.isDeviceLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const HomeScreen();
      },
    );
  }
}
