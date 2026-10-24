import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/app_settings.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'reminder_form_screen.dart';

class WidgetInfoScreen extends StatelessWidget {
  final AppController controller;

  const WidgetInfoScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final snapshot = controller.lastWidgetSnapshot;
        final entitled = controller.isFeatureEntitled(
          PremiumFeature.homeScreenWidget,
        );

        return GlassScaffold(
          themeSettings: controller.themeSettings,
          appBar: AppBar(
            title: const Text('Native Android Home-Screen Widget'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Widget Architecture & Bridge Status
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.widgets_outlined, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SharedPreferences Snapshot Bridge',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TierStatusBadge(isPremium: entitled),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To avoid cross-process SQLite file locks between Flutter and the Android system launcher, Flutter serializes a compact JSON snapshot into Android SharedPreferences ("smart_reminder_widget_store") and broadcasts AppWidgetManager.ACTION_APPWIDGET_UPDATE to SmartReminderWidgetProvider.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            snapshot != null
                                ? 'Last synced: ${DateFormat("MMM d, h:mm:ss a").format(snapshot.syncedAt)}'
                                : 'Not yet synced in this session',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await controller.forceSyncHomeWidget();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Synchronized snapshot & triggered Android AppWidgetProvider update.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Sync Widget Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Live Visual Preview of the Native Android Widget
              GlassCard(
                padding: const EdgeInsets.all(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF0B132B),
                    Color(0xFF1E1B4B),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Smart Reminders (Home Widget Preview)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quick Add Action',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReminderFormScreen(
                                  controller: controller,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.add_circle_rounded,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Next Alarm: ${snapshot?.nextAlarmLabel ?? "No active alarm"}',
                      style: const TextStyle(
                        color: Color(0xFFA5B4FC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 18),
                    if (snapshot == null || snapshot.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No upcoming reminders — tap + to quick-add.',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      )
                    else
                      ...snapshot.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                item.isOverdue
                                    ? Icons.error_outline_rounded
                                    : Icons.circle,
                                size: item.isOverdue ? 15 : 8,
                                color: item.isOverdue
                                    ? Colors.redAccent
                                    : const Color(0xFF06B6D4),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.formattedTime,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Instructions for Adding on Android Launcher
              const GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'How to Pin to Your Android Home Screen',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Long-press an empty area on your Android Home Screen.\n'
                      '2. Select "Widgets" from the launcher menu.\n'
                      '3. Find "Smart Reminder & Voice Alarm" and drag the 4×2 widget onto your Home Screen.\n'
                      '4. Tap any reminder row in the widget to open that reminder directly, or tap "+" for Quick-Add.',
                      style: TextStyle(fontSize: 13, height: 1.45),
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
