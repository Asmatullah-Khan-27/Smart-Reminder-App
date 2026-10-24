import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/alarm.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/recurrence_rule.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/recurrence_selector_widget.dart';
import 'premium_upgrade_screen.dart';

class AlarmFormScreen extends StatefulWidget {
  final AppController controller;
  final Alarm? existingAlarm;
  final AlarmMode? initialMode;

  const AlarmFormScreen({
    super.key,
    required this.controller,
    this.existingAlarm,
    this.initialMode,
  });

  @override
  State<AlarmFormScreen> createState() => _AlarmFormScreenState();
}

class _AlarmFormScreenState extends State<AlarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _customMessageController;

  late DateTime _scheduledDateTime;
  late AlarmMode _alarmMode;
  late String _speechLanguage;
  late double _speechRate;
  late double _speechPitch;
  late String _ringtoneIdentifier;
  late RecurrenceRule _recurrenceRule;
  late int _snoozeDuration;
  late bool _enabled;

  bool get _isEditing => widget.existingAlarm != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAlarm;
    final speechDefaults = widget.controller.speechSettings;
    final now = DateTime.now();

    _titleController = TextEditingController(
      text: existing?.title ?? 'Morning Voice Wake-Up',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _customMessageController = TextEditingController(
      text: existing?.customMessage.isNotEmpty == true
          ? existing!.customMessage
          : Alarm.defaultRomanUrduMessage,
    );

    _scheduledDateTime =
        existing?.scheduledDateTime ?? now.add(const Duration(hours: 8));
    _alarmMode =
        existing?.alarmMode ?? widget.initialMode ?? AlarmMode.ringtone;
    _speechLanguage = existing?.speechLanguage ?? speechDefaults.defaultLanguage;
    _speechRate = existing?.speechRate ?? speechDefaults.defaultSpeechRate;
    _speechPitch = existing?.speechPitch ?? speechDefaults.defaultSpeechPitch;
    _ringtoneIdentifier = existing?.ringtoneIdentifier ?? 'default_alarm';
    _recurrenceRule = existing?.recurrenceRule ?? RecurrenceRule.oneTime();
    _snoozeDuration = existing?.snoozeDuration ??
        widget.controller.userPreferences.defaultSnoozeMinutes;
    _enabled = existing?.enabled ?? true;
  }

  @override
  void dispose() {
    widget.controller.ttsService.stop();
    widget.controller.nativeAlarmBridge.stopRingtonePreview();
    _titleController.dispose();
    _notesController.dispose();
    _customMessageController.dispose();
    super.dispose();
  }

  void _openUpgradeScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumUpgradeScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
    );
    if (picked != null && mounted) {
      final now = DateTime.now();
      DateTime candidate = DateTime(
        _scheduledDateTime.year,
        _scheduledDateTime.month,
        _scheduledDateTime.day,
        picked.hour,
        picked.minute,
      );
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      setState(() => _scheduledDateTime = candidate);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime.isBefore(now) ? now : _scheduledDateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() {
        _scheduledDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _scheduledDateTime.hour,
          _scheduledDateTime.minute,
        );
      });
    }
  }

  Future<void> _testVoiceNow() async {
    final text = _customMessageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a custom spoken message first.')),
      );
      return;
    }
    final status = await widget.controller.ttsService.speakText(
      text: text,
      language: _speechLanguage,
      rate: _speechRate,
      pitch: _speechPitch,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.message)),
      );
    }
  }

  Future<void> _saveAlarm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_alarmMode == AlarmMode.voice &&
        !widget.controller.isFeatureEntitled(
          PremiumFeature.customSpokenAlarms,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Custom Spoken Voice Alarms require Premium or QA Sandbox Entitlement.',
          ),
          action: SnackBarAction(
            label: 'Unlock Pro',
            onPressed: _openUpgradeScreen,
          ),
        ),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final existing = widget.existingAlarm;
      final alarm = Alarm(
        id: existing?.id ?? widget.controller.generateId(),
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        alarmMode: _alarmMode,
        customMessage: _alarmMode == AlarmMode.voice
            ? _customMessageController.text.trim()
            : _customMessageController.text.trim(),
        speechLanguage: _speechLanguage,
        speechRate: _speechRate,
        speechPitch: _speechPitch,
        ringtoneIdentifier: _ringtoneIdentifier,
        scheduledDateTime: _scheduledDateTime,
        recurrenceRule: _recurrenceRule,
        snoozeDuration: _snoozeDuration,
        enabled: _enabled,
        nextOccurrence: _scheduledDateTime,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final scheduleRes = await widget.controller.saveAlarm(
        alarm,
        isNew: !_isEditing,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(scheduleRes.statusMessage)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final use24h = widget.controller.userPreferences.use24HourFormat;
    final timeFmt = DateFormat(use24h ? 'HH:mm' : 'h:mm a');
    final dateFmt = DateFormat('EEE, MMM d, yyyy');
    final voiceEntitled = widget.controller.isFeatureEntitled(
      PremiumFeature.customSpokenAlarms,
    );

    return GlassScaffold(
      themeSettings: widget.controller.themeSettings,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Alarm' : 'Schedule Native Alarm'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _saveAlarm,
            icon: const Icon(Icons.alarm_add_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Time Display Hero Card
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                children: <Widget>[
                  InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        timeFmt.format(_scheduledDateTime),
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded, size: 17),
                        label: const Text('Change Time'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded, size: 17),
                        label: Text(dateFmt.format(_scheduledDateTime)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Alarm Mode Selector (Ringtone vs Voice Alarm TTS)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Alarm Execution Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!voiceEntitled)
                        TierStatusBadge(
                          isPremium: false,
                          onTap: _openUpgradeScreen,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<AlarmMode>(
                    segments: const <ButtonSegment<AlarmMode>>[
                      ButtonSegment<AlarmMode>(
                        value: AlarmMode.ringtone,
                        icon: Icon(Icons.music_note_rounded),
                        label: Text('Ringtone Mode'),
                      ),
                      ButtonSegment<AlarmMode>(
                        value: AlarmMode.voice,
                        icon: Icon(Icons.record_voice_over_rounded),
                        label: Text('Voice Alarm (TTS)'),
                      ),
                    ],
                    selected: <AlarmMode>{_alarmMode},
                    onSelectionChanged: (Set<AlarmMode> selection) {
                      final chosen = selection.first;
                      if (chosen == AlarmMode.voice && !voiceEntitled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Voice Alarm Mode is a Pro feature. You can unlock it or enable the QA Sandbox on the Upgrade screen.',
                            ),
                            action: SnackBarAction(
                              label: 'Upgrade',
                              onPressed: _openUpgradeScreen,
                            ),
                          ),
                        );
                      }
                      setState(() => _alarmMode = chosen);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Title & Notes
            GlassCard(
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Alarm Label *',
                      prefixIcon: Icon(Icons.label_important_outline_rounded),
                    ),
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Alarm title is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Subtitle (Optional)',
                      prefixIcon: Icon(Icons.short_text_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Conditional: Voice Alarm Configuration
            if (_alarmMode == AlarmMode.voice) ...<Widget>[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.spatial_audio_off_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Custom Spoken Alarm Message (TTS)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customMessageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message to Speak Aloud *',
                        hintText: Alarm.defaultRomanUrduMessage,
                      ),
                      validator: (String? v) {
                        if (_alarmMode == AlarmMode.voice &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Please enter the custom message for the Voice Alarm.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        ActionChip(
                          label: const Text('Use Roman Urdu Preset'),
                          onPressed: () {
                            setState(() {
                              _customMessageController.text =
                                  Alarm.defaultRomanUrduMessage;
                              _speechLanguage = 'ur-PK';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Use English Executive Preset'),
                          onPressed: () {
                            setState(() {
                              _customMessageController.text =
                                  'Good morning! It is time to wake up and begin your scheduled priorities.';
                              _speechLanguage = 'en-US';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: SpeechLanguageOption.supported
                              .any((e) => e.code == _speechLanguage)
                          ? _speechLanguage
                          : 'en-US',
                      decoration: const InputDecoration(
                        labelText: 'Speech Language & Accent',
                        prefixIcon: Icon(Icons.language_rounded),
                      ),
                      items: SpeechLanguageOption.supported.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt.code,
                          child: Text(opt.label),
                        );
                      }).toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setState(() => _speechLanguage = v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 110,
                          child: Text('Speech Rate'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _speechRate.clamp(0.25, 1.5),
                            min: 0.25,
                            max: 1.5,
                            divisions: 25,
                            label: '${_speechRate.toStringAsFixed(2)}x',
                            onChanged: (double v) {
                              setState(() => _speechRate = v);
                            },
                          ),
                        ),
                        Text('${_speechRate.toStringAsFixed(2)}x'),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 110,
                          child: Text('Speech Pitch'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _speechPitch.clamp(0.5, 2.0),
                            min: 0.5,
                            max: 2.0,
                            divisions: 30,
                            label: _speechPitch.toStringAsFixed(2),
                            onChanged: (double v) {
                              setState(() => _speechPitch = v);
                            },
                          ),
                        ),
                        Text(_speechPitch.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _testVoiceNow,
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('Test Voice (TTS)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => widget.controller.ttsService.stop(),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Ringtone Selection Card (Primary for Ringtone Mode, Fallback for Voice Mode)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _alarmMode == AlarmMode.ringtone
                        ? 'Ringtone Sound Selection'
                        : 'Fallback Ringtone (Played if TTS Voice Pack Unavailable)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioGroup<String>(
                    groupValue: _ringtoneIdentifier,
                    onChanged: (String? v) {
                      if (v != null) {
                        setState(() => _ringtoneIdentifier = v);
                      }
                    },
                    child: Column(
                      children: RingtoneOption.presets.map((tone) {
                        final selected = _ringtoneIdentifier == tone.id;
                        return RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: tone.id,
                          title: Text(
                            tone.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(tone.description),
                          secondary: IconButton(
                            tooltip: 'Preview Tone',
                            icon: const Icon(Icons.play_circle_outline_rounded),
                            onPressed: () {
                              widget.controller.nativeAlarmBridge
                                  .previewRingtone(tone.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Previewing "${tone.name}"...'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          selected: selected,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Recurrence Engine
            RecurrenceSelectorWidget(
              rule: _recurrenceRule,
              isPremiumUnlocked: widget.controller.isFeatureEntitled(
                PremiumFeature.advancedRecurrence,
              ),
              onChanged: (RecurrenceRule r) {
                setState(() => _recurrenceRule = r);
              },
              onPremiumRequired: _openUpgradeScreen,
            ),
            const SizedBox(height: 14),

            // Snooze & Enabled
            GlassCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.snooze_rounded),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Snooze Duration',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _snoozeDuration,
                        items: const <int>[5, 10, 15, 20, 30]
                            .map(
                              (m) => DropdownMenuItem<int>(
                                value: m,
                                child: Text('$m minutes'),
                              ),
                            )
                            .toList(),
                        onChanged: (int? v) {
                          if (v != null) {
                            setState(() => _snoozeDuration = v);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Alarm Immediately',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Registers exact wake-up intent with Android AlarmManager',
                    ),
                    value: _enabled,
                    onChanged: (bool val) {
                      setState(() => _enabled = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: _saveAlarm,
              icon: const Icon(Icons.alarm_on_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _isEditing ? 'Update Alarm' : 'Schedule Alarm',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
