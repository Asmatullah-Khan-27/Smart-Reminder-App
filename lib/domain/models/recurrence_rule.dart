import 'dart:convert';

enum RecurrenceFrequency {
  oneTime,
  daily,
  weekly,
  selectedWeekdays,
  monthly,
  customInterval,
}

enum CustomIntervalUnit {
  hours,
  days,
  weeks,
  months,
}

class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final int interval;
  final List<int> weekdays; // ISO 8601: 1 (Monday) .. 7 (Sunday)
  final int? dayOfMonth; // 1 .. 31
  final CustomIntervalUnit customUnit;
  final DateTime? endDate;
  final int? maxOccurrences;

  const RecurrenceRule({
    this.frequency = RecurrenceFrequency.oneTime,
    this.interval = 1,
    this.weekdays = const <int>[],
    this.dayOfMonth,
    this.customUnit = CustomIntervalUnit.days,
    this.endDate,
    this.maxOccurrences,
  });

  factory RecurrenceRule.oneTime() => const RecurrenceRule(
        frequency: RecurrenceFrequency.oneTime,
      );

  factory RecurrenceRule.daily({int interval = 1, DateTime? endDate}) =>
      RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: interval < 1 ? 1 : interval,
        endDate: endDate,
      );

  factory RecurrenceRule.weekly({
    int interval = 1,
    List<int> weekdays = const <int>[],
    DateTime? endDate,
  }) =>
      RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: interval < 1 ? 1 : interval,
        weekdays: List<int>.unmodifiable(
          (weekdays.toSet().where((d) => d >= 1 && d <= 7).toList()..sort()),
        ),
        endDate: endDate,
      );

  factory RecurrenceRule.selectedWeekdays({
    required List<int> weekdays,
    DateTime? endDate,
  }) {
    final normalized = weekdays
        .toSet()
        .where((d) => d >= 1 && d <= 7)
        .toList()
      ..sort();
    return RecurrenceRule(
      frequency: RecurrenceFrequency.selectedWeekdays,
      interval: 1,
      weekdays: List<int>.unmodifiable(normalized),
      endDate: endDate,
    );
  }

  factory RecurrenceRule.monthly({
    int interval = 1,
    int? dayOfMonth,
    DateTime? endDate,
  }) =>
      RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        interval: interval < 1 ? 1 : interval,
        dayOfMonth: dayOfMonth?.clamp(1, 31),
        endDate: endDate,
      );

  factory RecurrenceRule.custom({
    required int interval,
    required CustomIntervalUnit unit,
    DateTime? endDate,
  }) =>
      RecurrenceRule(
        frequency: RecurrenceFrequency.customInterval,
        interval: interval < 1 ? 1 : interval,
        customUnit: unit,
        endDate: endDate,
      );

  bool get isRecurring => frequency != RecurrenceFrequency.oneTime;

  bool get isAdvancedRecurrence =>
      frequency == RecurrenceFrequency.selectedWeekdays ||
      frequency == RecurrenceFrequency.monthly ||
      frequency == RecurrenceFrequency.customInterval ||
      interval > 1 ||
      endDate != null;

  void validate() {
    if (interval < 1) {
      throw ArgumentError.value(interval, 'interval', 'Interval must be >= 1');
    }
    if (frequency == RecurrenceFrequency.selectedWeekdays && weekdays.isEmpty) {
      throw ArgumentError(
        'Selected weekdays recurrence requires at least one weekday (1..7).',
      );
    }
    for (final day in weekdays) {
      if (day < 1 || day > 7) {
        throw ArgumentError.value(day, 'weekdays', 'Weekday must be 1..7.');
      }
    }
    if (dayOfMonth != null && (dayOfMonth! < 1 || dayOfMonth! > 31)) {
      throw ArgumentError.value(
        dayOfMonth,
        'dayOfMonth',
        'dayOfMonth must be between 1 and 31.',
      );
    }
  }

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<int>? weekdays,
    int? dayOfMonth,
    CustomIntervalUnit? customUnit,
    DateTime? endDate,
    bool clearEndDate = false,
    int? maxOccurrences,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      customUnit: customUnit ?? this.customUnit,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'frequency': frequency.name,
      'interval': interval,
      'weekdays': weekdays,
      'dayOfMonth': dayOfMonth,
      'customUnit': customUnit.name,
      'endDate': endDate?.toIso8601String(),
      'maxOccurrences': maxOccurrences,
    };
  }

  String toJsonString() => jsonEncode(toMap());

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    final freqName = map['frequency'] as String? ?? 'oneTime';
    final frequency = RecurrenceFrequency.values.firstWhere(
      (e) => e.name == freqName,
      orElse: () => RecurrenceFrequency.oneTime,
    );
    final unitName = map['customUnit'] as String? ?? 'days';
    final customUnit = CustomIntervalUnit.values.firstWhere(
      (e) => e.name == unitName,
      orElse: () => CustomIntervalUnit.days,
    );
    final rawWeekdays = map['weekdays'];
    final List<int> parsedWeekdays;
    if (rawWeekdays is List) {
      parsedWeekdays = rawWeekdays
          .map((e) => (e as num).toInt())
          .where((d) => d >= 1 && d <= 7)
          .toSet()
          .toList()
        ..sort();
    } else {
      parsedWeekdays = const <int>[];
    }

    final rawEnd = map['endDate'] as String?;
    return RecurrenceRule(
      frequency: frequency,
      interval: ((map['interval'] as num?)?.toInt() ?? 1).clamp(1, 10000),
      weekdays: List<int>.unmodifiable(parsedWeekdays),
      dayOfMonth: (map['dayOfMonth'] as num?)?.toInt(),
      customUnit: customUnit,
      endDate: rawEnd != null && rawEnd.isNotEmpty
          ? DateTime.tryParse(rawEnd)
          : null,
      maxOccurrences: (map['maxOccurrences'] as num?)?.toInt(),
    );
  }

  factory RecurrenceRule.fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return RecurrenceRule.oneTime();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RecurrenceRule.fromMap(decoded);
      }
    } catch (_) {
      // Fallback to oneTime if corrupted
    }
    return RecurrenceRule.oneTime();
  }

  String toHumanReadable() {
    switch (frequency) {
      case RecurrenceFrequency.oneTime:
        return 'One-time';
      case RecurrenceFrequency.daily:
        return interval == 1 ? 'Daily' : 'Every $interval days';
      case RecurrenceFrequency.weekly:
        if (weekdays.isEmpty) {
          return interval == 1 ? 'Weekly' : 'Every $interval weeks';
        }
        return '${interval == 1 ? "Weekly" : "Every $interval wks"} (${_formatWeekdays(weekdays)})';
      case RecurrenceFrequency.selectedWeekdays:
        if (weekdays.length == 5 &&
            weekdays.contains(1) &&
            weekdays.contains(2) &&
            weekdays.contains(3) &&
            weekdays.contains(4) &&
            weekdays.contains(5)) {
          return 'Every weekday (Mon–Fri)';
        }
        if (weekdays.length == 2 &&
            weekdays.contains(6) &&
            weekdays.contains(7)) {
          return 'Weekends (Sat, Sun)';
        }
        return 'Days: ${_formatWeekdays(weekdays)}';
      case RecurrenceFrequency.monthly:
        final dayLabel = dayOfMonth != null ? ' (day $dayOfMonth)' : '';
        return interval == 1
            ? 'Monthly$dayLabel'
            : 'Every $interval months$dayLabel';
      case RecurrenceFrequency.customInterval:
        final unitLabel = interval == 1
            ? customUnit.name.substring(0, customUnit.name.length - 1)
            : customUnit.name;
        return 'Every $interval $unitLabel';
    }
  }

  static String _formatWeekdays(List<int> days) {
    const names = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return days.map((d) => names[d] ?? '$d').join(', ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RecurrenceRule) return false;
    if (frequency != other.frequency ||
        interval != other.interval ||
        dayOfMonth != other.dayOfMonth ||
        customUnit != other.customUnit ||
        endDate != other.endDate ||
        maxOccurrences != other.maxOccurrences ||
        weekdays.length != other.weekdays.length) {
      return false;
    }
    for (int i = 0; i < weekdays.length; i++) {
      if (weekdays[i] != other.weekdays[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        frequency,
        interval,
        Object.hashAll(weekdays),
        dayOfMonth,
        customUnit,
        endDate,
        maxOccurrences,
      );
}

/// Deterministic, timezone-safe Recurrence Engine for calculating next occurrences.
class RecurrenceEngine {
  const RecurrenceEngine();

  /// Returns the number of days in a given [year] and [month] (1..12).
  static int daysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  /// Constructs a local [DateTime] preserving wall-clock time across DST changes
  /// and clamping the day to the valid range of the target month.
  static DateTime makeWallClockDateTime({
    required int year,
    required int month,
    required int preferredDay,
    required int hour,
    required int minute,
    int second = 0,
  }) {
    final maxDay = daysInMonth(year, month);
    final actualDay = preferredDay.clamp(1, maxDay);
    return DateTime(year, month, actualDay, hour, minute, second);
  }

  /// Calculates the next occurrence strictly after [referenceTime] based on
  /// [anchorDateTime] and [rule].
  ///
  /// For [RecurrenceFrequency.oneTime]:
  /// - If [anchorDateTime] is strictly after [referenceTime], returns [anchorDateTime].
  /// - Otherwise returns `null` (already passed).
  ///
  /// For recurring rules:
  /// - Advances from [anchorDateTime] until finding the first valid occurrence
  ///   strictly after [referenceTime].
  /// - If [rule.endDate] is set and the next occurrence exceeds [rule.endDate],
  ///   returns `null`.
  static DateTime? computeNextOccurrence({
    required DateTime anchorDateTime,
    required RecurrenceRule rule,
    required DateTime referenceTime,
    bool allowAnchorIfInFuture = true,
  }) {
    rule.validate();

    if (rule.frequency == RecurrenceFrequency.oneTime) {
      if (allowAnchorIfInFuture && anchorDateTime.isAfter(referenceTime)) {
        return _checkEndDate(anchorDateTime, rule.endDate);
      }
      return null;
    }

    if (allowAnchorIfInFuture && anchorDateTime.isAfter(referenceTime)) {
      if (_matchesRuleOnAnchor(anchorDateTime, rule)) {
        return _checkEndDate(anchorDateTime, rule.endDate);
      }
    }

    final int targetHour = anchorDateTime.hour;
    final int targetMinute = anchorDateTime.minute;
    final int targetSecond = anchorDateTime.second;
    final int safeInterval = rule.interval < 1 ? 1 : rule.interval;

    switch (rule.frequency) {
      case RecurrenceFrequency.oneTime:
        return null;

      case RecurrenceFrequency.daily:
        return _nextDaily(
          anchor: anchorDateTime,
          reference: referenceTime,
          intervalDays: safeInterval,
          hour: targetHour,
          minute: targetMinute,
          second: targetSecond,
          endDate: rule.endDate,
        );

      case RecurrenceFrequency.weekly:
        if (rule.weekdays.isEmpty) {
          return _nextDaily(
            anchor: anchorDateTime,
            reference: referenceTime,
            intervalDays: safeInterval * 7,
            hour: targetHour,
            minute: targetMinute,
            second: targetSecond,
            endDate: rule.endDate,
          );
        }
        return _nextSelectedWeekdays(
          anchor: anchorDateTime,
          reference: referenceTime,
          weekdays: rule.weekdays,
          intervalWeeks: safeInterval,
          hour: targetHour,
          minute: targetMinute,
          second: targetSecond,
          endDate: rule.endDate,
        );

      case RecurrenceFrequency.selectedWeekdays:
        return _nextSelectedWeekdays(
          anchor: anchorDateTime,
          reference: referenceTime,
          weekdays: rule.weekdays,
          intervalWeeks: 1,
          hour: targetHour,
          minute: targetMinute,
          second: targetSecond,
          endDate: rule.endDate,
        );

      case RecurrenceFrequency.monthly:
        final preferredDay = rule.dayOfMonth ?? anchorDateTime.day;
        return _nextMonthly(
          anchor: anchorDateTime,
          reference: referenceTime,
          intervalMonths: safeInterval,
          preferredDay: preferredDay,
          hour: targetHour,
          minute: targetMinute,
          second: targetSecond,
          endDate: rule.endDate,
        );

      case RecurrenceFrequency.customInterval:
        switch (rule.customUnit) {
          case CustomIntervalUnit.hours:
            return _nextHourly(
              anchor: anchorDateTime,
              reference: referenceTime,
              intervalHours: safeInterval,
              endDate: rule.endDate,
            );
          case CustomIntervalUnit.days:
            return _nextDaily(
              anchor: anchorDateTime,
              reference: referenceTime,
              intervalDays: safeInterval,
              hour: targetHour,
              minute: targetMinute,
              second: targetSecond,
              endDate: rule.endDate,
            );
          case CustomIntervalUnit.weeks:
            return _nextDaily(
              anchor: anchorDateTime,
              reference: referenceTime,
              intervalDays: safeInterval * 7,
              hour: targetHour,
              minute: targetMinute,
              second: targetSecond,
              endDate: rule.endDate,
            );
          case CustomIntervalUnit.months:
            return _nextMonthly(
              anchor: anchorDateTime,
              reference: referenceTime,
              intervalMonths: safeInterval,
              preferredDay: rule.dayOfMonth ?? anchorDateTime.day,
              hour: targetHour,
              minute: targetMinute,
              second: targetSecond,
              endDate: rule.endDate,
            );
        }
    }
  }

  /// Computes the next occurrence after an item is completed or dismissed at [completedAt].
  static DateTime? computeNextAfterCompletion({
    required DateTime currentScheduled,
    required RecurrenceRule rule,
    required DateTime completedAt,
  }) {
    if (!rule.isRecurring) {
      return null;
    }
    final baseline =
        completedAt.isAfter(currentScheduled) ? completedAt : currentScheduled;
    return computeNextOccurrence(
      anchorDateTime: currentScheduled,
      rule: rule,
      referenceTime: baseline,
      allowAnchorIfInFuture: false,
    );
  }

  static bool _matchesRuleOnAnchor(DateTime anchor, RecurrenceRule rule) {
    if (rule.frequency == RecurrenceFrequency.selectedWeekdays ||
        (rule.frequency == RecurrenceFrequency.weekly &&
            rule.weekdays.isNotEmpty)) {
      return rule.weekdays.contains(anchor.weekday);
    }
    if (rule.frequency == RecurrenceFrequency.monthly &&
        rule.dayOfMonth != null) {
      final maxDay = daysInMonth(anchor.year, anchor.month);
      final expectedDay = rule.dayOfMonth!.clamp(1, maxDay);
      return anchor.day == expectedDay;
    }
    return true;
  }

  static DateTime? _nextHourly({
    required DateTime anchor,
    required DateTime reference,
    required int intervalHours,
    required DateTime? endDate,
  }) {
    final stepMs = Duration(hours: intervalHours).inMilliseconds;
    final anchorMs = anchor.millisecondsSinceEpoch;
    final refMs = reference.millisecondsSinceEpoch;
    if (anchorMs > refMs) {
      return _checkEndDate(anchor, endDate);
    }
    final diffMs = refMs - anchorMs;
    final steps = (diffMs ~/ stepMs) + 1;
    final next = DateTime.fromMillisecondsSinceEpoch(anchorMs + steps * stepMs);
    return _checkEndDate(next, endDate);
  }

  static DateTime? _nextDaily({
    required DateTime anchor,
    required DateTime reference,
    required int intervalDays,
    required int hour,
    required int minute,
    required int second,
    required DateTime? endDate,
  }) {
    // Use calendar days in UTC to avoid DST 23h/25h drift, then reconstruct local wall-clock time
    final anchorDayUtc = DateTime.utc(anchor.year, anchor.month, anchor.day);
    final refDayUtc =
        DateTime.utc(reference.year, reference.month, reference.day);
    int diffDays = refDayUtc.difference(anchorDayUtc).inDays;
    int steps = 0;
    if (diffDays > 0) {
      steps = diffDays ~/ intervalDays;
    }
    while (true) {
      final candidateUtc =
          anchorDayUtc.add(Duration(days: steps * intervalDays));
      final candidateLocal = DateTime(
        candidateUtc.year,
        candidateUtc.month,
        candidateUtc.day,
        hour,
        minute,
        second,
      );
      if (candidateLocal.isAfter(reference)) {
        return _checkEndDate(candidateLocal, endDate);
      }
      steps++;
    }
  }

  static DateTime? _nextSelectedWeekdays({
    required DateTime anchor,
    required DateTime reference,
    required List<int> weekdays,
    required int intervalWeeks,
    required int hour,
    required int minute,
    required int second,
    required DateTime? endDate,
  }) {
    final sortedDays = weekdays.toSet().where((d) => d >= 1 && d <= 7).toList()
      ..sort();
    if (sortedDays.isEmpty) return null;

    // Start searching from max(anchor date, reference date)
    final startBase = reference.isAfter(anchor) ? reference : anchor;
    final anchorMondayUtc = DateTime.utc(anchor.year, anchor.month, anchor.day)
        .subtract(Duration(days: anchor.weekday - 1));

    for (int offset = 0; offset <= 366 * 5; offset++) {
      final dayUtc = DateTime.utc(
        startBase.year,
        startBase.month,
        startBase.day,
      ).add(Duration(days: offset));

      final candidateLocal = DateTime(
        dayUtc.year,
        dayUtc.month,
        dayUtc.day,
        hour,
        minute,
        second,
      );

      if (!candidateLocal.isAfter(reference)) {
        continue;
      }
      if (!sortedDays.contains(candidateLocal.weekday)) {
        continue;
      }

      if (intervalWeeks > 1) {
        final candidateMondayUtc = DateTime.utc(
          candidateLocal.year,
          candidateLocal.month,
          candidateLocal.day,
        ).subtract(Duration(days: candidateLocal.weekday - 1));
        final weeksDiff =
            candidateMondayUtc.difference(anchorMondayUtc).inDays ~/ 7;
        if (weeksDiff < 0 || weeksDiff % intervalWeeks != 0) {
          continue;
        }
      }

      return _checkEndDate(candidateLocal, endDate);
    }
    return null;
  }

  static DateTime? _nextMonthly({
    required DateTime anchor,
    required DateTime reference,
    required int intervalMonths,
    required int preferredDay,
    required int hour,
    required int minute,
    required int second,
    required DateTime? endDate,
  }) {
    final anchorTotalMonths = anchor.year * 12 + (anchor.month - 1);
    final refTotalMonths = reference.year * 12 + (reference.month - 1);

    int steps = 0;
    if (refTotalMonths > anchorTotalMonths) {
      steps = (refTotalMonths - anchorTotalMonths) ~/ intervalMonths;
    }

    for (int i = 0; i < 1200; i++) {
      final totalMonths = anchorTotalMonths + (steps + i) * intervalMonths;
      final year = totalMonths ~/ 12;
      final month = (totalMonths % 12) + 1;
      final candidate = makeWallClockDateTime(
        year: year,
        month: month,
        preferredDay: preferredDay,
        hour: hour,
        minute: minute,
        second: second,
      );
      if (candidate.isAfter(reference)) {
        return _checkEndDate(candidate, endDate);
      }
    }
    return null;
  }

  static DateTime? _checkEndDate(DateTime candidate, DateTime? endDate) {
    if (endDate != null && candidate.isAfter(endDate)) {
      return null;
    }
    return candidate;
  }
}
