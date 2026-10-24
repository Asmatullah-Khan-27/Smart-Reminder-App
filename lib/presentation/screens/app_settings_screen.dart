import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'backup_export_screen.dart';
import 'categories_screen.dart';
import 'premium_upgrade_screen.dart';
import 'privacy_permissions_screen.dart';
import 'theme_settings_screen.dart';
import 'voice_settings_screen.dart';
import 'widget_info_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  final AppController controller;

  const AppSettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final prefs = controller.userPreferences;
        final ad = controller.adConfig;
        final isPro = controller.isPremiumActive;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: <Widget>[
            // Quick Navigation Hub to Dedicated Feature Screens
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Modules & Feature Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TierStatusBadge(
                        isPremium: isPro,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PremiumUpgradeScreen(controller: controller),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SettingsNavTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Smart Reminder Pro & Store Billing',
                    subtitle: isPro
                        ? 'Pro Entitlement Active (All features unlocked)'
                        : 'Free Tier — Tap to view Pro features & QA Sandbox',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PremiumUpgradeScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 12),
                  _SettingsNavTile(
                    icon: Icons.category_outlined,
                    title: 'Categories & Safe Reassignment',
                    subtitle:
                        '${controller.categories.length} categories configured',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CategoriesScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 12),
                  _SettingsNavTile(
                    icon: Icons.record_voice_over_outlined,
                    title: 'Voice Alarm (TTS) & Speech Recognition',
                    subtitle:
                        'Default TTS: ${controller.speechSettings.defaultLanguage} • Rate: ${controller.speechSettings.defaultSpeechRate.toStringAsFixed(2)}x',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              VoiceSettingsScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 12),
                  _SettingsNavTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme & Automatic Day/Night Schedule',
                    subtitle:
                        '${controller.themeSettings.mode.label} • ${controller.themeSettings.accentPreset.label}',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ThemeSettingsScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 12),
                  _SettingsNavTile(
                    icon: Icons.backup_outlined,
                    title: 'Local Backup, Export & Restore',
                    subtitle:
                        'Versioned offline JSON export & transactional SQLite restore',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BackupExportScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 12),
                  _SettingsNavTile(
                    icon: Icons.widgets_outlined,
                    title: 'Native Android Home-Screen Widget',
                    subtitle:
                        'SharedPreferences snapshot bridge & live widget preview',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              WidgetInfoScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 12),
                  _SettingsNavTile(
                    icon: Icons.security_rounded,
                    title: 'Android Permissions & Reliability Guide',
                    subtitle:
                        'Exact alarms, notifications, full-screen intent, reboot recovery',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PrivacyPermissionsScreen(
                            controller: controller,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // General User Preferences
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'General Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use 24-Hour Time Format'),
                    subtitle: const Text(
                      'Display times as 14:30 instead of 2:30 PM',
                    ),
                    value: prefs.use24HourFormat,
                    onChanged: (bool val) {
                      controller.updateUserPreferences(
                        prefs.copyWith(use24HourFormat: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Confirm Before Deleting Items'),
                    subtitle: const Text(
                      'Show confirmation dialog before deleting reminders or alarms',
                    ),
                    value: prefs.confirmBeforeDelete,
                    onChanged: (bool val) {
                      controller.updateUserPreferences(
                        prefs.copyWith(confirmBeforeDelete: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Sync Home-Screen Widget'),
                    subtitle: const Text(
                      'Automatically push snapshot updates when reminders or alarms change',
                    ),
                    value: prefs.autoSyncHomeWidget,
                    onChanged: (bool val) {
                      controller.updateUserPreferences(
                        prefs.copyWith(autoSyncHomeWidget: val),
                      );
                    },
                  ),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Default Snooze Duration',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButton<int>(
                        value: prefs.defaultSnoozeMinutes,
                        items: const <int>[5, 10, 15, 30, 60]
                            .map(
                              (m) => DropdownMenuItem<int>(
                                value: m,
                                child: Text('$m min'),
                              ),
                            )
                            .toList(),
                        onChanged: (int? v) {
                          if (v != null) {
                            controller.updateUserPreferences(
                              prefs.copyWith(defaultSnoozeMinutes: v),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Advertising & Consent Configuration
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Advertising & Privacy Consent (Test-Mode Safe)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Supports Google AdMob and Amazon Ads in strict test mode. Ads are automatically removed for Pro users and are never shown while an alarm is ringing.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AdNetworkProvider>(
                    initialValue: ad.provider,
                    decoration: const InputDecoration(
                      labelText: 'Ad Network Provider Abstraction',
                    ),
                    items: AdNetworkProvider.values.map((p) {
                      return DropdownMenuItem<AdNetworkProvider>(
                        value: p,
                        child: Text(p.label),
                      );
                    }).toList(),
                    onChanged: (AdNetworkProvider? val) {
                      if (val != null) {
                        controller.updateAdvertisingConfig(
                          ad.copyWith(provider: val),
                        );
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Banner Placements Enabled'),
                    value: ad.bannerEnabled,
                    onChanged: (bool val) {
                      controller.updateAdvertisingConfig(
                        ad.copyWith(bannerEnabled: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy Consent Granted (GDPR/CCPA)'),
                    subtitle: const Text(
                      'Controls whether test ad requests include consent flags',
                    ),
                    value: ad.userConsentGranted,
                    onChanged: (bool val) {
                      controller.updateAdvertisingConfig(
                        ad.copyWith(userConsentGranted: val),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
