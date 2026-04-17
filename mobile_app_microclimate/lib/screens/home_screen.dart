import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dashboard_screen.dart';
import 'prediction_screen.dart';
import 'history_screen.dart';
import 'profiles_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    PredictionScreen(),
    HistoryScreen(),
    ProfilesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: colorScheme.surfaceContainerHigh,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF4F46E5),
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_rounded),
              label: 'dashboard'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_graph_rounded),
              label: 'prediction'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_rounded),
              label: 'history'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.tune_rounded),
              label: 'profiles'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              label: 'settings'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
