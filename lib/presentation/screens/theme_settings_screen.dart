import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'premium_upgrade_screen.dart';

class ThemeSettingsScreen extends StatelessWidget {
  final AppController controller;

  const ThemeSettingsScreen({super.key, required this.controller});

  String _formatHourMinute(int hour, int minute) {
    final tod = TimeOfDay(hour: hour, minute: minute);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final suffix = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $suffix (${hour.toString().padLeft(2, '0')}:$m)';
  }

  void _openUpgrade(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumUpgradeScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final t = controller.themeSettings;
        final proUnlocked = controller.isFeatureEntitled(
          PremiumFeature.advancedThemes,
        );
        final isCurrentlyDay = t.isDaytimeAt(DateTime.now());

        return GlassScaffold(
          themeSettings: t,
          appBar: AppBar(
            title: const Text('Theme & Glass Design System'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Appearance Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<ThemePreferenceMode>(
                      groupValue: t.mode,
                      onChanged: (ThemePreferenceMode? val) {
                        if (val == null) return;
                        if (val == ThemePreferenceMode.scheduled &&
                            !proUnlocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Automatic Day/Night Schedule is a Pro feature.',
                              ),
                              action: SnackBarAction(
                                label: 'Unlock',
                                onPressed: () => _openUpgrade(context),
                              ),
                            ),
                          );
                          return;
                        }
                        controller.updateThemeSettings(t.copyWith(mode: val));
                      },
                      child: Column(
                        children: ThemePreferenceMode.values.map((mode) {
                          final requiresPro =
                              mode == ThemePreferenceMode.scheduled &&
                                  !proUnlocked;
                          return RadioListTile<ThemePreferenceMode>(
                            contentPadding: EdgeInsets.zero,
                            value: mode,
                            title: Row(
                              children: <Widget>[
                                Expanded(child: Text(mode.label)),
                                if (requiresPro)
                                  const Icon(
                                    Icons.workspace_premium,
                                    size: 17,
                                    color: Colors.amber,
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              mode == ThemePreferenceMode.scheduled
                                  ? 'Switches automatically between Light and Dark using local clock (no location permission required)'
                                  : 'Persist across app restarts',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Automatic Day / Night Schedule Configuration (supports midnight crossing)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.schedule_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Daytime & Nighttime Schedule Window',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isCurrentlyDay ? 'Currently: DAY' : 'Currently: NIGHT',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Supports schedules that cross midnight (e.g. Day 07:00 → Night 01:00 or Night 22:00 → Day 06:30).',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: const Text('Daytime (Light Theme) Starts'),
                      subtitle: Text(
                        _formatHourMinute(t.dayStartHour, t.dayStartMinute),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: t.dayStartHour,
                              minute: t.dayStartMinute,
                            ),
                          );
                          if (picked != null) {
                            await controller.updateThemeSettings(
                              t.copyWith(
                                dayStartHour: picked.hour,
                                dayStartMinute: picked.minute,
                              ),
                            );
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.nights_stay_outlined),
                      title: const Text('Nighttime (Dark Glass Theme) Starts'),
                      subtitle: Text(
                        _formatHourMinute(t.nightStartHour, t.nightStartMinute),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: t.nightStartHour,
                              minute: t.nightStartMinute,
                            ),
                          );
                          if (picked != null) {
                            await controller.updateThemeSettings(
                              t.copyWith(
                                nightStartHour: picked.hour,
                                nightStartMinute: picked.minute,
                              ),
                            );
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Glassmorphism Accent Presets
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Glassmorphism Palette Preset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RadioGroup<GlassThemeAccentPreset>(
                      groupValue: t.accentPreset,
                      onChanged: (GlassThemeAccentPreset? val) {
                        if (val == null) return;
                        if (val.isPremiumPreset && !proUnlocked) {
                          _openUpgrade(context);
                          return;
                        }
                        controller.updateThemeSettings(
                          t.copyWith(accentPreset: val),
                        );
                      },
                      child: Column(
                        children: GlassThemeAccentPreset.values.map((preset) {
                          final locked =
                              preset.isPremiumPreset && !proUnlocked;
                          return RadioListTile<GlassThemeAccentPreset>(
                            contentPadding: EdgeInsets.zero,
                            value: preset,
                            title: Row(
                              children: <Widget>[
                                Expanded(child: Text(preset.label)),
                                if (locked)
                                  const Icon(
                                    Icons.workspace_premium,
                                    size: 17,
                                    color: Colors.amber,
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
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
