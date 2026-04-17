import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/climate_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/push_service.dart';
import '../widgets/language_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildLanguageSettings(context),
              const SizedBox(height: 24),
              _buildThemeSettings(context),
              const SizedBox(height: 24),
              _buildNotificationSettings(context),
              const SizedBox(height: 24),
              _buildAccountSection(context),
              const SizedBox(height: 24),
              _buildAboutSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'settings'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'settings_desc'.tr(),
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLanguageSettings(BuildContext context) {
    return _buildExpandableSection(
      context: context,
      icon: Icons.language_rounded,
      title: 'language'.tr(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LanguageSelector(),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildExpandableSection(
      context: context,
      icon: Icons.info_rounded,
      title: 'about_app'.tr(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            _buildInfoRow(context, 'app_name'.tr(), 'MicroClimate AI Pro'),
            _buildInfoRow(context, 'version'.tr(), '1.0.0'),
            const SizedBox(height: 16),
            _buildConnectionInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return _buildExpandableSection(
      context: context,
      icon: Icons.manage_accounts_rounded,
      title: 'Аккаунт',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final climate = context.read<ClimateProvider>();
              final auth = context.read<AuthProvider>();
              await climate.clearSessionState();
              await auth.logout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Выйти'),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSettings(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return _buildExpandableSection(
          context: context,
          icon: Icons.palette_rounded,
          title: 'theme'.tr(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SwitchListTile.adaptive(
              value: themeProvider.isDarkMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('dark_theme'.tr()),
              subtitle: Text(
                themeProvider.isDarkMode
                    ? 'dark_theme_on'.tr()
                    : 'light_theme_on'.tr(),
              ),
              onChanged: (value) => themeProvider.setDarkMode(value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationSettings(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        final pushActive = provider.pushInitialized;
        return _buildExpandableSection(
          context: context,
          icon: Icons.notifications_rounded,
          title: 'notifications'.tr(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  value: provider.notificationsEnabled,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('enable_notifications'.tr()),
                  subtitle: Text('notifications_desc'.tr()),
                  onChanged: (value) async {
                    await provider.setNotificationsEnabled(value);
                  },
                ),
                SwitchListTile.adaptive(
                  value: provider.soundEnabled,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('sound_alert'.tr()),
                  subtitle: Text('play_sound'.tr()),
                  onChanged: provider.notificationsEnabled
                      ? (value) async {
                          await provider.setSoundEnabled(value);
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: provider.notificationSound,
                  decoration: InputDecoration(
                    labelText: 'notification_sound'.tr(),
                    helperText: 'notification_sound_hint'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: PushService.systemSoundKey,
                      child: Text('sound_system'.tr()),
                    ),
                    DropdownMenuItem(
                      value: PushService.defaultSoundKey,
                      child: Text('sound_default'.tr()),
                    ),
                  ],
                  onChanged:
                      provider.notificationsEnabled && provider.soundEnabled
                          ? (value) async {
                              if (value != null) {
                                await provider.setNotificationSound(value);
                              }
                            }
                          : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      pushActive
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: pushActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pushActive
                            ? 'Push-уведомления активированы'
                            : 'Push-уведомления отключены',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: provider.notificationsEnabled
                          ? () => provider.ensurePushInitialized()
                          : null,
                      child: const Text('Проверить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: _cardDecoration(context),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          backgroundColor: colorScheme.surfaceContainerHigh,
          collapsedBackgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          iconColor: colorScheme.onSurfaceVariant,
          collapsedIconColor: colorScheme.onSurfaceVariant,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(BuildContext context) {
    final provider = Provider.of<ClimateProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = provider.serverOnline ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? statusColor.withValues(alpha: 0.16)
            : statusColor.withValues(alpha: 0.08),
        border: Border.all(
          color: isDark
              ? statusColor.withValues(alpha: 0.45)
              : statusColor.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 5,
            backgroundColor: statusColor,
          ),
          const SizedBox(width: 10),
          Text(
            provider.serverOnline
                ? 'server_online'.tr()
                : 'server_offline'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
