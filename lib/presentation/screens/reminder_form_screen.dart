import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/recurrence_selector_widget.dart';
import 'premium_upgrade_screen.dart';

class ReminderFormScreen extends StatefulWidget {
  final AppController controller;
  final Reminder? existingReminder;
  final bool startWithVoiceInput;

  const ReminderFormScreen({
    super.key,
    required this.controller,
    this.existingReminder,
    this.startWithVoiceInput = false,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late DateTime _scheduledDateTime;
  late String _categoryId;
  late ReminderPriority _priority;
  late RecurrenceRule _recurrenceRule;
  late int _snoozeDuration;
  late bool _notificationEnabled;
  late String _selectedVoiceLocale;

  bool _isVoiceListening = false;
  String? _voiceStatusBanner;
  bool _dictatingIntoNotes = false;

  bool get _isEditing => widget.existingReminder != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReminder;
    final prefs = widget.controller.userPreferences;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _scheduledDateTime = existing?.scheduledDateTime ??
        DateTime.now().add(const Duration(hours: 1));
    _categoryId = existing?.categoryId ?? prefs.defaultCategoryId;
    _priority = existing?.priority ?? prefs.defaultPriority;
    _recurrenceRule = existing?.recurrenceRule ?? RecurrenceRule.oneTime();
    _snoozeDuration = existing?.snoozeDuration ?? prefs.defaultSnoozeMinutes;
    _notificationEnabled = existing?.notificationEnabled ?? true;
    _selectedVoiceLocale = widget.controller.speechSettings.voiceInputLocale;

    if (widget.startWithVoiceInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleVoiceDictation(intoNotes: false);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.voiceInputService.stopListening();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openUpgradeScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumUpgradeScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _toggleVoiceDictation({required bool intoNotes}) async {
    if (!widget.controller.isFeatureEntitled(PremiumFeature.voiceInput)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Voice Input (Speech-to-Text) is a Premium feature. Enable Pro or QA Sandbox on the Upgrade screen.',
          ),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: _openUpgradeScreen,
          ),
        ),
      );
      return;
    }

    final voiceService = widget.controller.voiceInputService;
    if (_isVoiceListening) {
      await voiceService.stopListening();
      if (mounted) {
        setState(() {
          _isVoiceListening = false;
          _voiceStatusBanner = 'Voice recognition stopped. You can edit the text below.';
        });
      }
      return;
    }

    setState(() {
      _dictatingIntoNotes = intoNotes;
      _voiceStatusBanner = 'Initializing microphone & speech recognition...';
    });

    final state = await voiceService.startListening(
      localeId: _selectedVoiceLocale,
      onResult: (String recognized, bool isFinal) {
        if (!mounted) return;
        setState(() {
          if (_dictatingIntoNotes) {
            _notesController.text = recognized;
            _notesController.selection = TextSelection.fromPosition(
              TextPosition(offset: _notesController.text.length),
            );
          } else {
            _titleController.text = recognized;
            _titleController.selection = TextSelection.fromPosition(
              TextPosition(offset: _titleController.text.length),
            );
          }
          _isVoiceListening = !isFinal;
          _voiceStatusBanner = isFinal
              ? 'Voice capture complete. Feel free to edit the recognized text.'
              : 'Listening ($_selectedVoiceLocale)... "$recognized"';
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isVoiceListening = state.isListening;
      if (state.errorMessage != null) {
        _voiceStatusBanner = state.errorMessage;
      } else if (state.isListening) {
        _voiceStatusBanner =
            'Listening via microphone (${_dictatingIntoNotes ? "Notes" : "Title"})... Speak clearly.';
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime.isBefore(now) ? now : _scheduledDateTime,
      firstDate: now.subtract(const Duration(days: 365)),
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
    );
    if (picked != null && mounted) {
      setState(() {
        _scheduledDateTime = DateTime(
          _scheduledDateTime.year,
          _scheduledDateTime.month,
          _scheduledDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final now = DateTime.now();
      final existing = widget.existingReminder;
      final reminder = Reminder(
        id: existing?.id ?? widget.controller.generateId(),
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        scheduledDateTime: _scheduledDateTime,
        recurrenceRule: _recurrenceRule,
        categoryId: _categoryId,
        priority: _priority,
        completed: existing?.completed ?? false,
        notificationEnabled: _notificationEnabled,
        snoozeDuration: _snoozeDuration,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.controller.saveReminder(reminder, isNew: !_isEditing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Reminder updated in SQLite.'
                  : 'Reminder saved to SQLite & widget synced.',
            ),
          ),
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
    final categories = widget.controller.categories;
    final use24h = widget.controller.userPreferences.use24HourFormat;
    final dateFmt = DateFormat('EEE, MMM d, yyyy');
    final timeFmt = DateFormat(use24h ? 'HH:mm' : 'h:mm a');

    return GlassScaffold(
      themeSettings: widget.controller.themeSettings,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'Create Smart Reminder'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _saveReminder,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Voice Input Bar
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _isVoiceListening ? Icons.mic : Icons.mic_none_rounded,
                        color: _isVoiceListening
                            ? Colors.redAccent
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Speech-to-Text Voice Dictation',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedVoiceLocale,
                        underline: const SizedBox.shrink(),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'en_US',
                            child: Text('English (US)', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'ur_PK',
                            child: Text('Urdu (PK)', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'hi_IN',
                            child: Text('Hindi (IN)', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (String? val) {
                          if (val != null) {
                            setState(() => _selectedVoiceLocale = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: () => _toggleVoiceDictation(intoNotes: false),
                        icon: Icon(
                          _isVoiceListening && !_dictatingIntoNotes
                              ? Icons.stop_circle_outlined
                              : Icons.mic_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isVoiceListening && !_dictatingIntoNotes
                              ? 'Stop Dictating Title'
                              : 'Dictate Title',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _toggleVoiceDictation(intoNotes: true),
                        icon: Icon(
                          _isVoiceListening && _dictatingIntoNotes
                              ? Icons.stop_circle_outlined
                              : Icons.record_voice_over_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _isVoiceListening && _dictatingIntoNotes
                              ? 'Stop Dictating Notes'
                              : 'Dictate Notes',
                        ),
                      ),
                    ],
                  ),
                  if (_voiceStatusBanner != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _voiceStatusBanner!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Title & Notes
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Reminder Title *',
                      hintText: 'e.g. Call client or take evening vitamin',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (String? val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a reminder title.';
                      }
                      if (val.trim().length > 200) {
                        return 'Title must be 200 characters or fewer.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Details (Editable)',
                      hintText: 'Add context, checklist items, or spoken notes...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Date & Time Pickers
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Scheduled Date & Time',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Text(dateFmt.format(_scheduledDateTime)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time_rounded, size: 18),
                          label: Text(timeFmt.format(_scheduledDateTime)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Category & Priority
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final selected = cat.id == _categoryId;
                      return ChoiceChip(
                        selected: selected,
                        avatar: Icon(cat.icon, size: 16, color: cat.color),
                        label: Text(cat.name),
                        onSelected: (_) {
                          setState(() => _categoryId = cat.id);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Priority Level',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReminderPriority.values.map((p) {
                      return ChoiceChip(
                        selected: _priority == p,
                        label: Text(p.label),
                        onSelected: (_) {
                          setState(() => _priority = p);
                        },
                      );
                    }).toList(),
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
              onChanged: (RecurrenceRule updated) {
                setState(() => _recurrenceRule = updated);
              },
              onPremiumRequired: _openUpgradeScreen,
            ),
            const SizedBox(height: 14),

            // Notification & Snooze Settings
            GlassCard(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Local Notification',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Trigger high-priority reminder alert at scheduled time',
                    ),
                    value: _notificationEnabled,
                    onChanged: (bool value) {
                      setState(() => _notificationEnabled = value);
                    },
                  ),
                  const Divider(),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.snooze_rounded, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Default Snooze Duration',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _snoozeDuration,
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
                            setState(() => _snoozeDuration = v);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saveReminder,
              icon: const Icon(Icons.save_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _isEditing ? 'Update Reminder' : 'Create Reminder',
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
