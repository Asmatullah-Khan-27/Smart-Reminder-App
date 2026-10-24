import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/alarm.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'alarm_form_screen.dart';
import 'privacy_permissions_screen.dart';

class AlarmListScreen extends StatelessWidget {
  final AppController controller;

  const AlarmListScreen({super.key, required this.controller});

  Future<void> _confirmDeleteAlarm(BuildContext context, Alarm alarm) async {
    if (controller.userPreferences.confirmBeforeDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Delete Alarm?'),
          content: Text(
            'Delete "${alarm.title}" and cancel its scheduled Android AlarmManager wake-up?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await controller.deleteAlarm(alarm.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted alarm "${alarm.title}".')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final alarms = controller.allAlarms;
        final use24h = controller.userPreferences.use24HourFormat;
        final timeFmt = DateFormat(use24h ? 'HH:mm' : 'h:mm a');
        final fullFmt = DateFormat(
          use24h ? 'EEE, MMM d • HH:mm' : 'EEE, MMM d • h:mm a',
        );
        final perm = controller.permissionStatus;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
          children: <Widget>[
            // Exact Alarm Reliability Banner
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderColor: perm.canScheduleExactAlarms
                  ? const Color(0xFF10B981).withValues(alpha: 0.45)
                  : Colors.amber.withValues(alpha: 0.65),
              child: Row(
                children: <Widget>[
                  Icon(
                    perm.canScheduleExactAlarms
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color: perm.canScheduleExactAlarms
                        ? const Color(0xFF10B981)
                        : Colors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          perm.canScheduleExactAlarms
                              ? 'Native Android AlarmManager: Exact Alarms Active'
                              : 'Inexact Fallback Active (Exact Alarm Permission Needed)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          perm.schedulingModeDescription,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PrivacyPermissionsScreen(
                            controller: controller,
                          ),
                        ),
                      );
                    },
                    child: const Text('Permissions'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (alarms.isEmpty)
              EmptyStateGlassCard(
                icon: Icons.alarm_add_rounded,
                title: 'No Alarms Configured',
                subtitle:
                    'Schedule a standard Ringtone Alarm or a Custom Spoken Voice Alarm (TTS).',
                actionLabel: 'Schedule Alarm',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlarmFormScreen(controller: controller),
                    ),
                  );
                },
              )
            else
              ...alarms.map((alarm) {
                final isVoice = alarm.alarmMode == AlarmMode.voice;
                final displayTime =
                    alarm.nextOccurrence ?? alarm.scheduledDateTime;
                final tone = RingtoneOption.byId(alarm.ringtoneIdentifier);

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlarmFormScreen(
                          controller: controller,
                          existingAlarm: alarm,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isVoice
                                  ? const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.22)
                                  : const Color(0xFF06B6D4)
                                      .withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isVoice
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFF06B6D4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  isVoice
                                      ? Icons.record_voice_over_rounded
                                      : Icons.music_note_rounded,
                                  size: 13,
                                  color: isVoice
                                      ? const Color(0xFFC4B5FD)
                                      : const Color(0xFF67E8F9),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  alarm.alarmMode.label,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            alarm.recurrenceRule.toHumanReadable(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: alarm.enabled,
                            onChanged: (bool val) {
                              controller.toggleAlarmEnabled(
                                alarm.id,
                                enabled: val,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            timeFmt.format(displayTime),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: alarm.enabled
                                      ? null
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.45),
                                ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alarm.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.enabled && alarm.nextOccurrence != null
                            ? 'Next trigger: ${fullFmt.format(alarm.nextOccurrence!)}'
                            : 'Disabled (Not currently scheduled)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: alarm.enabled
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      if (isVoice && alarm.customMessage.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '"${alarm.customMessage}" (${alarm.speechLanguage} • ${alarm.speechRate.toStringAsFixed(2)}x)',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          'Tone: ${tone.name} • Snooze: ${alarm.snoozeDuration}m',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (isVoice)
                            ActionChip(
                              avatar: const Icon(
                                Icons.volume_up_rounded,
                                size: 16,
                              ),
                              label: const Text('Test Voice'),
                              onPressed: () async {
                                final status =
                                    await controller.ttsService.speakText(
                                  text: alarm.customMessage,
                                  language: alarm.speechLanguage,
                                  rate: alarm.speechRate,
                                  pitch: alarm.speechPitch,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(status.message)),
                                  );
                                }
                              },
                            )
                          else
                            ActionChip(
                              avatar: const Icon(
                                Icons.music_note_rounded,
                                size: 16,
                              ),
                              label: const Text('Preview Tone'),
                              onPressed: () {
                                controller.nativeAlarmBridge.previewRingtone(
                                  alarm.ringtoneIdentifier,
                                );
                              },
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.snooze_rounded, size: 16),
                            label: Text('Snooze (+${alarm.snoozeDuration}m)'),
                            onPressed: () async {
                              await controller.snoozeAlarm(alarm.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Snoozed "${alarm.title}" by ${alarm.snoozeDuration} minutes.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.notifications_off_outlined,
                              size: 16,
                            ),
                            label: const Text('Dismiss Cycle'),
                            onPressed: () async {
                              await controller.dismissAlarm(alarm.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      alarm.recurrenceRule.isRecurring
                                          ? 'Dismissed current cycle; scheduled next recurring occurrence.'
                                          : 'Dismissed one-time alarm.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: const Text('Delete'),
                            onPressed: () =>
                                _confirmDeleteAlarm(context, alarm),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
