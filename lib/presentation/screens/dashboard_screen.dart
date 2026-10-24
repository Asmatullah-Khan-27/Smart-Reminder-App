import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/alarm.dart';
import '../../domain/models/reminder.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'alarm_form_screen.dart';
import 'categories_screen.dart';
import 'premium_upgrade_screen.dart';
import 'reminder_form_screen.dart';
import 'reminder_list_screen.dart';
import 'widget_info_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AppController controller;
  final void Function(int tabIndex)? onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.controller,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final ctrl = widget.controller;
        if (ctrl.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (ctrl.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyStateGlassCard(
                icon: Icons.error_outline_rounded,
                title: 'Database Error',
                subtitle: ctrl.errorMessage!,
                actionLabel: 'Retry SQLite Load',
                onAction: ctrl.refreshAll,
              ),
            ),
          );
        }

        final nextAlarm = ctrl.nextScheduledAlarm;
        final activeAlarms = ctrl.activeAlarms;
        final overdue = ctrl.overdueReminders;
        final today = ctrl.todayReminders;
        final upcoming = ctrl.upcomingReminders;
        final completed = ctrl.completedReminders;
        final use24h = ctrl.userPreferences.use24HourFormat;
        final timeFmt = DateFormat(use24h ? 'HH:mm' : 'h:mm a');
        final fullFmt = DateFormat(
          use24h ? 'EEE, MMM d • HH:mm' : 'EEE, MMM d • h:mm a',
        );

        return RefreshIndicator(
          onRefresh: ctrl.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            children: <Widget>[
              // Header Row with Free/Premium Status & Quick Actions
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Smart Command Center',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Text(
                          '${ctrl.allReminders.where((r) => !r.completed).length} active reminders • ${activeAlarms.length} active alarms in SQLite',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TierStatusBadge(
                    isPremium: ctrl.isPremiumActive,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PremiumUpgradeScreen(controller: ctrl),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick-Add Action Strip
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ReminderFormScreen(controller: ctrl),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: const Text('Quick Reminder'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReminderFormScreen(
                              controller: ctrl,
                              startWithVoiceInput: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('Voice Dictation'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AlarmFormScreen(
                              controller: ctrl,
                              initialMode: AlarmMode.voice,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                      ),
                      label: const Text('New Voice Alarm'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WidgetInfoScreen(controller: ctrl),
                          ),
                        );
                      },
                      icon: const Icon(Icons.widgets_outlined, size: 18),
                      label: const Text('Home Widget'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Next Scheduled Alarm Hero Card
              GlassCard(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.28),
                    Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.16),
                  ],
                ),
                onTap: () {
                  if (nextAlarm != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlarmFormScreen(
                          controller: ctrl,
                          existingAlarm: nextAlarm,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlarmFormScreen(controller: ctrl),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.alarm_on_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'NEXT SCHEDULED NATIVE ALARM',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        Text(
                          '${activeAlarms.length} Active',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (nextAlarm == null)
                      const Text(
                        'No active alarm scheduled. Tap here to schedule a Ringtone or Voice Alarm.',
                        style: TextStyle(fontSize: 13.5),
                      )
                    else ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            timeFmt.format(nextAlarm.nextOccurrence!),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              nextAlarm.title,
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
                        '${fullFmt.format(nextAlarm.nextOccurrence!)} • ${nextAlarm.alarmMode.label} (${nextAlarm.recurrenceRule.toHumanReadable()})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (nextAlarm.alarmMode == AlarmMode.voice &&
                          nextAlarm.customMessage.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Spoken TTS: "${nextAlarm.customMessage}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final res = await ctrl.ttsService.speakText(
                                  text: nextAlarm.customMessage,
                                  language: nextAlarm.speechLanguage,
                                  rate: nextAlarm.speechRate,
                                  pitch: nextAlarm.speechPitch,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                size: 16,
                              ),
                              label: const Text('Preview TTS'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search, Category Filter & Sort Controls
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: ctrl.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search SQLite reminders & notes...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  ctrl.setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<ReminderSortOrder>(
                    tooltip: 'Sort Order',
                    icon: const Icon(Icons.sort_rounded),
                    onSelected: ctrl.setSortOrder,
                    itemBuilder: (_) => ReminderSortOrder.values
                        .map(
                          (o) => CheckedPopupMenuItem<ReminderSortOrder>(
                            value: o,
                            checked: ctrl.sortOrder == o,
                            child: Text(o.label),
                          ),
                        )
                        .toList(),
                  ),
                  IconButton(
                    tooltip: 'Manage Categories',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CategoriesScreen(controller: ctrl),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category Filter Strip
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: ctrl.selectedCategoryId == null,
                        label: const Text('All'),
                        onSelected: (_) => ctrl.setSelectedCategoryId(null),
                      ),
                    ),
                    ...ctrl.categories.map((cat) {
                      final selected = ctrl.selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selected,
                          avatar: Icon(cat.icon, size: 15, color: cat.color),
                          label: Text(cat.name),
                          onSelected: (_) => ctrl.setSelectedCategoryId(
                            selected ? null : cat.id,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Summary Metric Grid (Responsive for Phones & Tablets)
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final crossAxisCount = constraints.maxWidth > 640 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.05,
                    children: <Widget>[
                      _MetricTile(
                        title: 'Overdue',
                        count: overdue.length,
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _MetricTile(
                        title: "Today's",
                        count: today.length,
                        icon: Icons.today_rounded,
                        color: const Color(0xFF6366F1),
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _MetricTile(
                        title: 'Upcoming',
                        count: upcoming.length,
                        icon: Icons.upcoming_rounded,
                        color: const Color(0xFF06B6D4),
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                      _MetricTile(
                        title: 'Completed',
                        count: completed.length,
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF10B981),
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                    ],
                  );
                },
              ),

              // Safe Test Ad Banner (hidden automatically when Pro is active)
              SafeTestAdBannerWidget(
                controller: ctrl,
                onUpgradeTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PremiumUpgradeScreen(controller: ctrl),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Section 1: Overdue Reminders
              if (overdue.isNotEmpty) ...<Widget>[
                _SectionHeader(
                  title: 'Overdue Reminders (${overdue.length})',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 8),
                ...overdue.map(
                  (r) => _DashboardReminderCard(
                    controller: ctrl,
                    reminder: r,
                    formattedDate: fullFmt.format(r.scheduledDateTime),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Section 2: Today's Reminders
              _SectionHeader(
                title: "Today's Reminders (${today.length})",
                icon: Icons.wb_sunny_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              if (today.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No remaining reminders scheduled for today.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                )
              else
                ...today.map(
                  (r) => _DashboardReminderCard(
                    controller: ctrl,
                    reminder: r,
                    formattedDate: fullFmt.format(r.scheduledDateTime),
                  ),
                ),
              const SizedBox(height: 12),

              // Section 3: Upcoming Reminders
              _SectionHeader(
                title: 'Upcoming Reminders (${upcoming.length})',
                icon: Icons.event_available_rounded,
                color: const Color(0xFF06B6D4),
              ),
              const SizedBox(height: 8),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No future reminders matching current filters.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                )
              else
                ...upcoming.map(
                  (r) => _DashboardReminderCard(
                    controller: ctrl,
                    reminder: r,
                    formattedDate: fullFmt.format(r.scheduledDateTime),
                  ),
                ),
              const SizedBox(height: 12),

              // Section 4: Active Alarms Summary
              _SectionHeader(
                title: 'Active Scheduled Alarms (${activeAlarms.length})',
                icon: Icons.alarm_rounded,
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 8),
              if (activeAlarms.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No active alarms enabled.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                )
              else
                ...activeAlarms.map((alarm) {
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AlarmFormScreen(
                            controller: ctrl,
                            existingAlarm: alarm,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: <Widget>[
                        Icon(
                          alarm.alarmMode == AlarmMode.voice
                              ? Icons.record_voice_over_rounded
                              : Icons.music_note_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                alarm.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${alarm.alarmMode.label} • ${alarm.recurrenceRule.toHumanReadable()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          timeFmt.format(
                            alarm.nextOccurrence ?? alarm.scheduledDateTime,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),

              // Section 5: Completed Reminders
              _SectionHeader(
                title: 'Completed Reminders (${completed.length})',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 8),
              if (completed.isEmpty)
                const GlassCard(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'No completed reminders yet.',
                    style: TextStyle(fontSize: 13),
                  ),
                )
              else
                ...completed.take(5).map(
                      (r) => _DashboardReminderCard(
                        controller: ctrl,
                        reminder: r,
                        formattedDate: fullFmt.format(r.scheduledDateTime),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DashboardReminderCard extends StatelessWidget {
  final AppController controller;
  final Reminder reminder;
  final String formattedDate;

  const _DashboardReminderCard({
    required this.controller,
    required this.reminder,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final category = controller.categoryById(reminder.categoryId);
    final isOverdue = reminder.isOverdueAt(DateTime.now());

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor:
          isOverdue ? Colors.redAccent.withValues(alpha: 0.5) : null,
      onTap: () {
        ReminderListScreen.showReminderDetailsSheet(
          context: context,
          controller: controller,
          reminder: reminder,
        );
      },
      child: Row(
        children: <Widget>[
          Checkbox(
            value: reminder.completed,
            onChanged: (bool? v) {
              if (v != null) {
                controller.toggleReminderCompleted(
                  reminder.id,
                  completed: v,
                );
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration:
                        reminder.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    CategoryPill(category: category),
                    PriorityBadge(priority: reminder.priority),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isOverdue ? Colors.redAccent : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Snooze +${reminder.snoozeDuration}m',
            onPressed: () async {
              await controller.snoozeReminder(reminder.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Snoozed "${reminder.title}" by ${reminder.snoozeDuration} min.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.snooze_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
