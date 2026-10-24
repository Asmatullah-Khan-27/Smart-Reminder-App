import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/recurrence_rule.dart';
import 'glass_widgets.dart';

class RecurrenceSelectorWidget extends StatelessWidget {
  final RecurrenceRule rule;
  final bool isPremiumUnlocked;
  final ValueChanged<RecurrenceRule> onChanged;
  final VoidCallback onPremiumRequired;

  const RecurrenceSelectorWidget({
    super.key,
    required this.rule,
    required this.isPremiumUnlocked,
    required this.onChanged,
    required this.onPremiumRequired,
  });

  bool _requiresPremium(RecurrenceFrequency freq) {
    return freq == RecurrenceFrequency.selectedWeekdays ||
        freq == RecurrenceFrequency.monthly ||
        freq == RecurrenceFrequency.customInterval;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.repeat_rounded, size: 19, color: primary),
              const SizedBox(width: 8),
              Text(
                'Recurrence Schedule',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                rule.toHumanReadable(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RecurrenceFrequency.values.map((freq) {
              final locked = !isPremiumUnlocked && _requiresPremium(freq);
              final selected = rule.frequency == freq;
              return ChoiceChip(
                selected: selected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_labelForFreq(freq)),
                    if (locked) ...<Widget>[
                      const SizedBox(width: 4),
                      const Icon(Icons.workspace_premium, size: 14),
                    ],
                  ],
                ),
                onSelected: (_) {
                  if (locked) {
                    onPremiumRequired();
                    return;
                  }
                  if (freq == RecurrenceFrequency.selectedWeekdays &&
                      rule.weekdays.isEmpty) {
                    onChanged(
                      rule.copyWith(
                        frequency: freq,
                        weekdays: const <int>[1, 2, 3, 4, 5],
                      ),
                    );
                  } else if (freq == RecurrenceFrequency.monthly &&
                      rule.dayOfMonth == null) {
                    onChanged(
                      rule.copyWith(
                        frequency: freq,
                        dayOfMonth: DateTime.now().day,
                      ),
                    );
                  } else {
                    onChanged(rule.copyWith(frequency: freq));
                  }
                },
              );
            }).toList(),
          ),
          if (rule.frequency == RecurrenceFrequency.selectedWeekdays ||
              rule.frequency == RecurrenceFrequency.weekly) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Active Days of Week',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List<Widget>.generate(7, (index) {
                final day = index + 1;
                const labels = <String>[
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                final isSelected = rule.weekdays.contains(day);
                return FilterChip(
                  selected: isSelected,
                  label: Text(labels[index]),
                  onSelected: (bool value) {
                    final updated = rule.weekdays.toSet();
                    if (value) {
                      updated.add(day);
                    } else if (updated.length > 1 ||
                        rule.frequency != RecurrenceFrequency.selectedWeekdays) {
                      updated.remove(day);
                    }
                    final sorted = updated.toList()..sort();
                    onChanged(rule.copyWith(weekdays: sorted));
                  },
                );
              }),
            ),
          ],
          if (rule.frequency == RecurrenceFrequency.monthly) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Day of month (clamps on short months e.g. Feb 28/29):',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                DropdownButton<int>(
                  value: (rule.dayOfMonth ?? 1).clamp(1, 31),
                  items: List<DropdownMenuItem<int>>.generate(
                    31,
                    (i) => DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text('Day ${i + 1}'),
                    ),
                  ),
                  onChanged: (int? v) {
                    if (v != null) {
                      onChanged(rule.copyWith(dayOfMonth: v));
                    }
                  },
                ),
              ],
            ),
          ],
          if (rule.frequency == RecurrenceFrequency.customInterval) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Text('Every '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: rule.interval.clamp(1, 30),
                  items: List<DropdownMenuItem<int>>.generate(
                    30,
                    (i) => DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text('${i + 1}'),
                    ),
                  ),
                  onChanged: (int? val) {
                    if (val != null) {
                      onChanged(rule.copyWith(interval: val));
                    }
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<CustomIntervalUnit>(
                  value: rule.customUnit,
                  items: CustomIntervalUnit.values.map((u) {
                    return DropdownMenuItem<CustomIntervalUnit>(
                      value: u,
                      child: Text(u.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (CustomIntervalUnit? unit) {
                    if (unit != null) {
                      onChanged(rule.copyWith(customUnit: unit));
                    }
                  },
                ),
              ],
            ),
          ],
          if (!isPremiumUnlocked) ...<Widget>[
            const SizedBox(height: 10),
            InkWell(
              onTap: onPremiumRequired,
              child: Text(
                'Pro feature: Unlock Selected Weekdays, Monthly & Custom Intervals (${PremiumFeature.advancedRecurrence.title})',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _labelForFreq(RecurrenceFrequency freq) {
    switch (freq) {
      case RecurrenceFrequency.oneTime:
        return 'One-time';
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.selectedWeekdays:
        return 'Weekdays';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.customInterval:
        return 'Custom';
    }
  }
}
