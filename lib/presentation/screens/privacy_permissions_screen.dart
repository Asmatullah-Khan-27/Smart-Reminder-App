import 'package:flutter/material.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';

class PrivacyPermissionsScreen extends StatelessWidget {
  final AppController controller;

  const PrivacyPermissionsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final perm = controller.permissionStatus;

        return GlassScaffold(
          themeSettings: controller.themeSettings,
          appBar: AppBar(
            title: const Text('Permissions, Reliability & Privacy'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh Permission Status',
                onPressed: controller.refreshAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Runtime Android Permissions & System Capabilities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Detected Android SDK Level: API ${perm.androidSdkInt}\n'
                      'Active Scheduling Mode: ${perm.schedulingModeDescription}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const Divider(height: 22),

                    // 1. Exact Alarms
                    _PermissionTile(
                      icon: Icons.alarm_on_rounded,
                      title: 'Exact Alarm Access (SCHEDULE_EXACT_ALARM)',
                      subtitle:
                          'Required on Android 12+ (API 31+) so AlarmManager triggers at the exact scheduled minute during Doze.',
                      granted: perm.canScheduleExactAlarms,
                      actionLabel: 'Configure',
                      onAction: () async {
                        await controller.nativeAlarmBridge
                            .requestExactAlarmPermission();
                        await controller.refreshAll();
                      },
                    ),
                    const Divider(),

                    // 2. Notifications
                    _PermissionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Post Notifications (POST_NOTIFICATIONS)',
                      subtitle:
                          'Required on Android 13+ (API 33+) to display reminder alerts and fallback alarm notifications.',
                      granted: perm.notificationsGranted,
                      actionLabel: 'Request',
                      onAction: () async {
                        await controller.nativeAlarmBridge
                            .requestNotificationPermission();
                        await controller.refreshAll();
                      },
                    ),
                    const Divider(),

                    // 3. Full Screen Intent
                    _PermissionTile(
                      icon: Icons.fullscreen_rounded,
                      title: 'Full-Screen Alarm Intent (USE_FULL_SCREEN_INTENT)',
                      subtitle:
                          'Permits waking the lock screen for ringing alarms. If restricted on Android 14+, a high-priority heads-up notification with Snooze/Dismiss is shown.',
                      granted: perm.canUseFullScreenIntent,
                      actionLabel: 'Settings',
                      onAction: () async {
                        await controller.nativeAlarmBridge
                            .requestFullScreenIntentPermission();
                        await controller.refreshAll();
                      },
                    ),
                    const Divider(),

                    // 4. Battery Optimization
                    _PermissionTile(
                      icon: Icons.battery_charging_full_rounded,
                      title:
                          'Unrestricted Battery / Doze Exemption (Optional)',
                      subtitle:
                          'Prevents aggressive OEM background killers from delaying native TTS initialization during Voice Alarms.',
                      granted: perm.batteryOptimizationIgnored,
                      actionLabel: 'Exempt',
                      onAction: () async {
                        await controller.nativeAlarmBridge
                            .requestIgnoreBatteryOptimizations();
                        await controller.refreshAll();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Transparent Reliability Disclosure
              const GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.info_outline_rounded, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Android Background Execution & Reliability Limits',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Reboot & Clock Changes: BootAndTimeChangeReceiver listens for BOOT_COMPLETED, QUICKBOOT_POWERON, TIME_SET, and TIMEZONE_CHANGED to reschedule active alarms from the persistent native registry.\n'
                      '• Native TTS Execution: AlarmForegroundService initializes Android native TextToSpeech directly in Kotlin so custom spoken alarms do not depend on a live Flutter UI engine.\n'
                      '• Important Platform Limitations: No Android application can fire alarms if the user explicitly clicks "Force Stop" in system settings, revokes notification/alarm permissions, or enables strict OEM vendor deep-sleep killers (e.g. Xiaomi MIUI, Huawei EMUI, Samsung Deep Sleeping Apps).',
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Offline Privacy Policy Summary
              const GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.lock_outline_rounded, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '100% Offline Data Privacy & Zero Cloud Dependency',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Local Storage Only: All reminders, spoken alarm messages, categories, and settings are stored exclusively in your device\'s local SQLite database and SharedPreferences.\n'
                      '• Microphone Usage: RECORD_AUDIO is requested solely when you tap the Voice Dictation button to transcribe text into reminder fields.\n'
                      '• No Location Tracking: Automatic Day/Night theme scheduling uses your configured local clock hours and never requests GPS or coarse location permissions.',
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: granted ? const Color(0xFF10B981) : Colors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onAction,
            child: Text(granted ? 'Verified' : actionLabel),
          ),
        ],
      ),
    );
  }
}
