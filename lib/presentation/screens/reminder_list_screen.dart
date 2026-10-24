import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/reminder.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'reminder_form_screen.dart';

class ReminderListScreen extends StatefulWidget {
  final AppController controller;
  final int initialSegment;

  const ReminderListScreen({
    super.key,
    required this.controller,
    this.initialSegment = 0,
  });

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();

  static Future<void> showReminderDetailsSheet({
    required BuildContext context,
    required AppController controller,
    required Reminder reminder,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _ReminderDetailsBottomSheet(
          controller: controller,
          reminder: reminder,
        );
      },
    );
  }
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  late int _segmentIndex;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _segmentIndex = widget.initialSegment;
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Reminder> _remindersForSegment() {
    switch (_segmentIndex) {
      case 1:
        return widget.controller.todayReminders;
      case 2:
        return widget.controller.upcomingReminders;
      case 3:
        return widget.controller.overdueReminders;
      case 4:
        return widget.controller.completedReminders;
      case 0:
      default:
        return widget.controller.filteredReminders;
    }
  }

  Future<void> _confirmDelete(Reminder reminder) async {
    if (widget.controller.userPreferences.confirmBeforeDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Delete Reminder?'),
          content: Text(
            'Are you sure you want to permanently delete "${reminder.title}"?',
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
    await widget.controller.deleteReminder(reminder.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${reminder.title}".')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final reminders = _remindersForSegment();
        final use24h = widget.controller.userPreferences.use24HourFormat;
        final dateFmt = DateFormat(
          use24h ? 'EEE, MMM d • HH:mm' : 'EEE, MMM d • h:mm a',
        );

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: widget.controller.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search reminders, notes, categories...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.controller.setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<ReminderSortOrder>(
                    tooltip: 'Sort Reminders',
                    icon: const Icon(Icons.sort_rounded),
                    onSelected: widget.controller.setSortOrder,
                    itemBuilder: (BuildContext context) {
                      return ReminderSortOrder.values.map((order) {
                        return CheckedPopupMenuItem<ReminderSortOrder>(
                          value: order,
                          checked: widget.controller.sortOrder == order,
                          child: Text(order.label),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: widget.controller.selectedCategoryId == null,
                      label: const Text('All Categories'),
                      onSelected: (_) =>
                          widget.controller.setSelectedCategoryId(null),
                    ),
                  ),
                  ...widget.controller.categories.map((cat) {
                    final selected =
                        widget.controller.selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        avatar: Icon(cat.icon, size: 15, color: cat.color),
                        label: Text(cat.name),
                        onSelected: (_) {
                          widget.controller.setSelectedCategoryId(
                            selected ? null : cat.id,
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Segment Tabs (All / Today / Upcoming / Overdue / Completed)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(
                      'All (${widget.controller.filteredReminders.length})',
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(
                      'Today (${widget.controller.todayReminders.length})',
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text(
                      'Upcoming (${widget.controller.upcomingReminders.length})',
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 3,
                    label: Text(
                      'Overdue (${widget.controller.overdueReminders.length})',
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 4,
                    label: Text(
                      'Done (${widget.controller.completedReminders.length})',
                    ),
                  ),
                ],
                selected: <int>{_segmentIndex},
                onSelectionChanged: (Set<int> selection) {
                  setState(() => _segmentIndex = selection.first);
                },
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: reminders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyStateGlassCard(
                          icon: Icons.task_alt_rounded,
                          title: 'No Reminders in This View',
                          subtitle:
                              'Create a new reminder with voice dictation or adjust your search/category filters.',
                          actionLabel: 'New Reminder',
                          onAction: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReminderFormScreen(
                                  controller: widget.controller,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: reminders.length,
                      itemBuilder: (BuildContext context, int index) {
                        final reminder = reminders[index];
                        final cat = widget.controller.categoryById(
                          reminder.categoryId,
                        );
                        final isOverdue = reminder.isOverdueAt(DateTime.now());

                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          borderColor: isOverdue
                              ? Colors.redAccent.withValues(alpha: 0.55)
                              : null,
                          onTap: () {
                            ReminderListScreen.showReminderDetailsSheet(
                              context: context,
                              controller: widget.controller,
                              reminder: reminder,
                            );
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Checkbox(
                                value: reminder.completed,
                                onChanged: (bool? val) async {
                                  if (val == null) return;
                                  final updated = await widget.controller
                                      .toggleReminderCompleted(
                                    reminder.id,
                                    completed: val,
                                  );
                                  if (context.mounted) {
                                    final msg = val &&
                                            !updated.completed &&
                                            reminder.recurrenceRule.isRecurring
                                        ? 'Completed cycle! Advanced recurring reminder to next occurrence.'
                                        : (val
                                            ? 'Reminder marked completed.'
                                            : 'Reminder reopened.');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            reminder.title,
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              decoration: reminder.completed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        PriorityBadge(
                                          priority: reminder.priority,
                                        ),
                                      ],
                                    ),
                                    if (reminder.notes.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        reminder.notes,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.72),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: <Widget>[
                                        CategoryPill(category: cat),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              isOverdue
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.schedule_rounded,
                                              size: 14,
                                              color: isOverdue
                                                  ? Colors.redAccent
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateFmt.format(
                                                reminder.scheduledDateTime,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isOverdue
                                                    ? Colors.redAccent
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (reminder.recurrenceRule.isRecurring)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              const Icon(
                                                Icons.repeat_rounded,
                                                size: 13,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                reminder.recurrenceRule
                                                    .toHumanReadable(),
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (String action) async {
                                  if (action == 'speak') {
                                    final status = await widget
                                        .controller.ttsService
                                        .speakText(
                                      text:
                                          '${reminder.title}. ${reminder.notes}',
                                      language: widget.controller.speechSettings
                                          .defaultLanguage,
                                      rate: widget.controller.speechSettings
                                          .defaultSpeechRate,
                                      pitch: widget.controller.speechSettings
                                          .defaultSpeechPitch,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(status.message)),
                                      );
                                    }
                                  } else if (action == 'snooze') {
                                    await widget.controller.snoozeReminder(
                                      reminder.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Snoozed "${reminder.title}" by ${reminder.snoozeDuration} min.',
                                          ),
                                        ),
                                      );
                                    }
                                  } else if (action == 'edit') {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ReminderFormScreen(
                                          controller: widget.controller,
                                          existingReminder: reminder,
                                        ),
                                      ),
                                    );
                                  } else if (action == 'delete') {
                                    await _confirmDelete(reminder);
                                  }
                                },
                                itemBuilder: (_) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'speak',
                                    child: ListTile(
                                      leading: Icon(Icons.volume_up_rounded),
                                      title: Text('Speak Reminder (TTS)'),
                                      dense: true,
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'snooze',
                                    child: ListTile(
                                      leading: const Icon(Icons.snooze_rounded),
                                      title: Text(
                                        'Snooze (+${reminder.snoozeDuration}m)',
                                      ),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit_rounded),
                                      title: Text('Edit'),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      title: Text('Delete'),
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ReminderDetailsBottomSheet extends StatelessWidget {
  final AppController controller;
  final Reminder reminder;

  const _ReminderDetailsBottomSheet({
    required this.controller,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    final category = controller.categoryById(reminder.categoryId);
    final dateFmt = DateFormat('EEEE, MMM d, yyyy • h:mm a');

    return Container(
      margin: const EdgeInsets.all(12),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CategoryPill(category: category),
                const SizedBox(width: 8),
                PriorityBadge(priority: reminder.priority),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reminder.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (reminder.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                reminder.notes,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(Icons.event_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateFmt.format(reminder.scheduledDateTime),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Icons.repeat_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Recurrence: ${reminder.recurrenceRule.toHumanReadable()}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Snooze',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[5, 10, 15, 30, 60].map((mins) {
                return ActionChip(
                  avatar: const Icon(Icons.snooze_rounded, size: 15),
                  label: Text('+$mins min'),
                  onPressed: () async {
                    await controller.snoozeReminder(
                      reminder.id,
                      minutes: mins,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Snoozed "${reminder.title}" by $mins minutes.',
                          ),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () async {
                    await controller.toggleReminderCompleted(
                      reminder.id,
                      completed: !reminder.completed,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: Icon(
                    reminder.completed
                        ? Icons.replay_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(
                    reminder.completed ? 'Reopen' : 'Mark Completed',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final res = await controller.ttsService.speakText(
                      text: '${reminder.title}. ${reminder.notes}',
                      language: controller.speechSettings.defaultLanguage,
                      rate: controller.speechSettings.defaultSpeechRate,
                      pitch: controller.speechSettings.defaultSpeechPitch,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message)),
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Speak (TTS)'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReminderFormScreen(
                          controller: controller,
                          existingReminder: reminder,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
