import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/alarm_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/backup_service.dart';
import '../../domain/models/alarm.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/backup_bundle.dart';
import '../../domain/models/category.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../../platform/advertising_service.dart';
import '../../platform/entitlement_billing_service.dart';
import '../../platform/local_notification_service.dart';
import '../../platform/native_alarm_bridge.dart';
import '../../platform/tts_service.dart';
import '../../platform/voice_input_service.dart';
import '../../platform/widget_sync_bridge.dart';

enum ReminderSortOrder {
  scheduledAsc,
  scheduledDesc,
  priorityDesc,
  titleAsc;

  String get label {
    switch (this) {
      case ReminderSortOrder.scheduledAsc:
        return 'Time (Earliest First)';
      case ReminderSortOrder.scheduledDesc:
        return 'Time (Latest First)';
      case ReminderSortOrder.priorityDesc:
        return 'Priority (Critical First)';
      case ReminderSortOrder.titleAsc:
        return 'Title (A–Z)';
    }
  }
}

class AppController extends ChangeNotifier {
  static const String _seedKey = 'initial_sql_seed_v1';

  final AppDatabase database;
  late final ReminderRepository reminderRepository;
  late final AlarmRepository alarmRepository;
  late final CategoryRepository categoryRepository;
  late final SettingsRepository settingsRepository;
  late final BackupService backupService;
  late final NativeAlarmBridge nativeAlarmBridge;
  late final WidgetSyncBridge widgetSyncBridge;
  late final LocalNotificationService notificationService;
  late final TtsService ttsService;
  late final VoiceInputService voiceInputService;
  late final EntitlementBillingService entitlementService;
  late final AdvertisingService advertisingService;

  final Uuid _uuid = const Uuid();
  Timer? _themeScheduleTimer;

  bool _isLoading = true;
  String? _errorMessage;

  List<Reminder> _reminders = const <Reminder>[];
  List<Alarm> _alarms = const <Alarm>[];
  List<ReminderCategory> _categories = const <ReminderCategory>[];

  ThemeSettings _themeSettings = const ThemeSettings();
  SpeechSettings _speechSettings = const SpeechSettings();
  UserPreferences _userPreferences = const UserPreferences();
  PremiumEntitlement _entitlement = PremiumEntitlement(
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
  AdvertisingConfiguration _adConfig = const AdvertisingConfiguration();
  NativeAlarmPermissionStatus _permissionStatus =
      NativeAlarmPermissionStatus.fallbackDefault;
  WidgetSnapshotPayload? _lastWidgetSnapshot;

  // Dashboard & list filters
  String _searchQuery = '';
  String? _selectedCategoryId; // null = All
  ReminderSortOrder _sortOrder = ReminderSortOrder.scheduledAsc;

  AppController({
    AppDatabase? customDatabase,
  }) : database = customDatabase ?? AppDatabase() {
    reminderRepository = ReminderRepository(database);
    alarmRepository = AlarmRepository(database);
    categoryRepository = CategoryRepository(database);
    settingsRepository = SettingsRepository(database);
    backupService = BackupService(
      appDatabase: database,
      reminderRepository: reminderRepository,
      alarmRepository: alarmRepository,
      categoryRepository: categoryRepository,
      settingsRepository: settingsRepository,
    );
    nativeAlarmBridge = NativeAlarmBridge(
      onNativeAlarmAction: _handleNativeAlarmAction,
    );
    widgetSyncBridge = WidgetSyncBridge();
    notificationService = LocalNotificationService();
    ttsService = TtsService();
    voiceInputService = VoiceInputService();
    entitlementService = EntitlementBillingService(
      settingsRepository: settingsRepository,
    );
    advertisingService = AdvertisingService(
      settingsRepository: settingsRepository,
    );
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Reminder> get allReminders => _reminders;
  List<Alarm> get allAlarms => _alarms;
  List<ReminderCategory> get categories => _categories;

  ThemeSettings get themeSettings => _themeSettings;
  SpeechSettings get speechSettings => _speechSettings;
  UserPreferences get userPreferences => _userPreferences;
  PremiumEntitlement get entitlement => _entitlement;
  AdvertisingConfiguration get adConfig => _adConfig;
  NativeAlarmPermissionStatus get permissionStatus => _permissionStatus;
  WidgetSnapshotPayload? get lastWidgetSnapshot => _lastWidgetSnapshot;

  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  ReminderSortOrder get sortOrder => _sortOrder;

  bool get isPremiumActive => _entitlement.isActiveAt(DateTime.now());

  ThemeMode get effectiveThemeMode =>
      _themeSettings.resolveThemeMode(DateTime.now());

  bool isFeatureEntitled(PremiumFeature feature) =>
      _entitlement.canUseFeature(feature);

  ReminderCategory categoryById(String id) {
    for (final cat in _categories) {
      if (cat.id == id) return cat;
    }
    if (_categories.isNotEmpty) return _categories.first;
    return ReminderCategory.defaultCategories(DateTime.now()).first;
  }

  List<Reminder> get filteredReminders {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _reminders.where((r) {
      if (_selectedCategoryId != null && r.categoryId != _selectedCategoryId) {
        return false;
      }
      if (q.isNotEmpty) {
        final catName = categoryById(r.categoryId).name.toLowerCase();
        final matchTitle = r.title.toLowerCase().contains(q);
        final matchNotes = r.notes.toLowerCase().contains(q);
        final matchCat = catName.contains(q);
        if (!matchTitle && !matchNotes && !matchCat) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOrder) {
        case ReminderSortOrder.scheduledAsc:
          return a.scheduledDateTime.compareTo(b.scheduledDateTime);
        case ReminderSortOrder.scheduledDesc:
          return b.scheduledDateTime.compareTo(a.scheduledDateTime);
        case ReminderSortOrder.priorityDesc:
          final cmp = b.priority.weight.compareTo(a.priority.weight);
          if (cmp != 0) return cmp;
          return a.scheduledDateTime.compareTo(b.scheduledDateTime);
        case ReminderSortOrder.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return filtered;
  }

  List<Reminder> get todayReminders {
    final now = DateTime.now();
    return filteredReminders
        .where((r) => !r.completed && r.isTodayAt(now) && !r.isOverdueAt(now))
        .toList();
  }

  List<Reminder> get upcomingReminders {
    final now = DateTime.now();
    return filteredReminders
        .where((r) => !r.completed && r.isUpcomingAt(now) && !r.isTodayAt(now))
        .toList();
  }

  List<Reminder> get overdueReminders {
    final now = DateTime.now();
    return filteredReminders.where((r) => r.isOverdueAt(now)).toList();
  }

  List<Reminder> get completedReminders {
    return filteredReminders.where((r) => r.completed).toList();
  }

  List<Alarm> get activeAlarms {
    return _alarms.where((a) => a.enabled).toList();
  }

  Alarm? get nextScheduledAlarm {
    final enabledWithNext = _alarms
        .where((a) => a.enabled && a.nextOccurrence != null)
        .toList()
      ..sort((a, b) => a.nextOccurrence!.compareTo(b.nextOccurrence!));
    if (enabledWithNext.isEmpty) return null;
    return enabledWithNext.first;
  }

  Future<void> initialize({bool seedStarterRecordsIfEmpty = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await notificationService.initialize();
      if (seedStarterRecordsIfEmpty) {
        await _seedInitialDatabaseRecordsOnce();
      }
      await refreshAll();

      // Re-evaluate automatic Day/Night theme schedule every minute
      _themeScheduleTimer?.cancel();
      _themeScheduleTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) {
          if (_themeSettings.mode == ThemePreferenceMode.scheduled) {
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to initialize database or services: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _seedInitialDatabaseRecordsOnce() async {
    final db = await database.database;
    final rows = await db.query(
      AppDatabase.tableKeyValueStore,
      where: 'key = ?',
      whereArgs: <Object?>[_seedKey],
      limit: 1,
    );
    if (rows.isNotEmpty) return;

    final existingRemCount = await reminderRepository.getAllReminders();
    final existingAlarmCount = await alarmRepository.getAllAlarms();
    if (existingRemCount.isEmpty && existingAlarmCount.isEmpty) {
      final now = DateTime.now();
      // 1. Today's reminder
      await reminderRepository.createReminder(
        Reminder(
          id: _uuid.v4(),
          title: 'Architecture & Sprint Review Standup',
          notes:
              'Review Android AlarmManager exact alarm policies and SQLite migration v3 metrics.',
          scheduledDateTime: now.add(const Duration(hours: 2)),
          recurrenceRule: RecurrenceRule.selectedWeekdays(
            weekdays: const <int>[1, 2, 3, 4, 5],
          ),
          categoryId: 'work',
          priority: ReminderPriority.high,
          completed: false,
          notificationEnabled: true,
          snoozeDuration: 10,
          createdAt: now,
          updatedAt: now,
        ),
      );
      // 2. Upcoming reminder
      await reminderRepository.createReminder(
        Reminder(
          id: _uuid.v4(),
          title: 'Evening Cardio & Hydration Check',
          notes: '45-minute endurance session + electrolyte balance.',
          scheduledDateTime: now.add(const Duration(days: 1, hours: 3)),
          recurrenceRule: RecurrenceRule.daily(),
          categoryId: 'health',
          priority: ReminderPriority.medium,
          completed: false,
          notificationEnabled: true,
          snoozeDuration: 15,
          createdAt: now,
          updatedAt: now,
        ),
      );
      // 3. Overdue reminder
      await reminderRepository.createReminder(
        Reminder(
          id: _uuid.v4(),
          title: 'Submit Release Signing Keystore Checklist',
          notes: 'Verify Play App Signing & Amazon Appstore SHA-256 fingerprints.',
          scheduledDateTime: now.subtract(const Duration(hours: 3)),
          recurrenceRule: RecurrenceRule.oneTime(),
          categoryId: 'work',
          priority: ReminderPriority.critical,
          completed: false,
          notificationEnabled: true,
          snoozeDuration: 10,
          createdAt: now.subtract(const Duration(hours: 5)),
          updatedAt: now.subtract(const Duration(hours: 3)),
        ),
      );
      // 4. Completed reminder
      await reminderRepository.createReminder(
        Reminder(
          id: _uuid.v4(),
          title: 'Read Kotlin Coroutines & BroadcastReceiver Guide',
          notes: 'Completed chapter on goAsync() and WakeLock lifecycle.',
          scheduledDateTime: now.subtract(const Duration(hours: 6)),
          recurrenceRule: RecurrenceRule.oneTime(),
          categoryId: 'study',
          priority: ReminderPriority.low,
          completed: true,
          notificationEnabled: true,
          snoozeDuration: 10,
          createdAt: now.subtract(const Duration(hours: 8)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
      );

      // 5. Custom Voice Alarm (TTS)
      final tomorrowMorning = DateTime(
        now.year,
        now.month,
        now.day,
        7,
        0,
      ).isAfter(now)
          ? DateTime(now.year, now.month, now.day, 7, 0)
          : DateTime(now.year, now.month, now.day + 1, 7, 0);

      await alarmRepository.createAlarm(
        Alarm(
          id: _uuid.v4(),
          title: 'Morning Executive Voice Wake-Up',
          notes: 'Spoken Roman Urdu custom TTS wake-up alarm',
          alarmMode: AlarmMode.voice,
          customMessage: Alarm.defaultRomanUrduMessage,
          speechLanguage: 'ur-PK',
          speechRate: 0.5,
          speechPitch: 1.0,
          ringtoneIdentifier: 'aurora_chime',
          scheduledDateTime: tomorrowMorning,
          recurrenceRule: RecurrenceRule.daily(),
          snoozeDuration: 10,
          enabled: true,
          nextOccurrence: tomorrowMorning,
          createdAt: now,
          updatedAt: now,
        ),
        now: now,
      );

      // 6. Standard Ringtone Alarm
      final eveningAlarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        21,
        30,
      ).isAfter(now)
          ? DateTime(now.year, now.month, now.day, 21, 30)
          : DateTime(now.year, now.month, now.day + 1, 21, 30);

      await alarmRepository.createAlarm(
        Alarm(
          id: _uuid.v4(),
          title: 'Deep Focus Wind-Down Tone',
          notes: 'Prepare tomorrow priorities and disconnect screens',
          alarmMode: AlarmMode.ringtone,
          customMessage: '',
          speechLanguage: 'en-US',
          speechRate: 0.5,
          speechPitch: 1.0,
          ringtoneIdentifier: 'default_alarm',
          scheduledDateTime: eveningAlarmTime,
          recurrenceRule: RecurrenceRule.oneTime(),
          snoozeDuration: 5,
          enabled: true,
          nextOccurrence: eveningAlarmTime,
          createdAt: now,
          updatedAt: now,
        ),
        now: now,
      );
    }

    await db.insert(
      AppDatabase.tableKeyValueStore,
      <String, Object?>{
        'key': _seedKey,
        'valueJson': '{"seeded":true}',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> refreshAll() async {
    try {
      _errorMessage = null;
      _categories = await categoryRepository.getAllCategories();
      _reminders = await reminderRepository.getAllReminders();
      _alarms = await alarmRepository.getAllAlarms();
      _themeSettings = await settingsRepository.loadThemeSettings();
      _speechSettings = await settingsRepository.loadSpeechSettings();
      _userPreferences = await settingsRepository.loadUserPreferences();
      _entitlement = await settingsRepository.loadPremiumEntitlement();
      _adConfig = await settingsRepository.loadAdvertisingConfig();
      _permissionStatus = await nativeAlarmBridge.getPermissionStatus();

      // Reconcile native Android alarms & sync Home-Screen Widget
      final enabledAlarms = _alarms.where((a) => a.enabled).toList();
      await nativeAlarmBridge.reconcileAlarms(enabledAlarms);

      if (_userPreferences.autoSyncHomeWidget) {
        _lastWidgetSnapshot = await widgetSyncBridge.syncHomeScreenWidget(
          reminders: _reminders,
          alarms: _alarms,
          categories: _categories,
          use24HourFormat: _userPreferences.use24HourFormat,
        );
      }
    } catch (e) {
      _errorMessage = 'Error loading data from SQLite: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategoryId(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSortOrder(ReminderSortOrder order) {
    _sortOrder = order;
    notifyListeners();
  }

  String generateId() => _uuid.v4();

  // --- Reminder Operations ---
  Future<void> saveReminder(Reminder reminder, {required bool isNew}) async {
    if (isNew) {
      await reminderRepository.createReminder(reminder);
    } else {
      await reminderRepository.updateReminder(reminder);
    }
    if (reminder.notificationEnabled && !reminder.completed) {
      await notificationService.showImmediateReminderNotification(reminder);
    } else {
      await notificationService.cancelReminderNotification(reminder.id);
    }
    await refreshAll();
  }

  Future<Reminder> toggleReminderCompleted(
    String id, {
    required bool completed,
  }) async {
    final updated = await reminderRepository.completeOrAdvanceReminder(
      id,
      completed: completed,
    );
    if (updated.completed) {
      await notificationService.cancelReminderNotification(id);
    }
    await refreshAll();
    return updated;
  }

  Future<Reminder> snoozeReminder(String id, {int? minutes}) async {
    final updated = await reminderRepository.snoozeReminder(
      id,
      customMinutes: minutes,
    );
    await refreshAll();
    return updated;
  }

  Future<void> deleteReminder(String id) async {
    await reminderRepository.deleteReminder(id);
    await notificationService.cancelReminderNotification(id);
    await refreshAll();
  }

  // --- Alarm Operations ---
  Future<NativeAlarmScheduleResult> saveAlarm(
    Alarm alarm, {
    required bool isNew,
  }) async {
    advertisingService.setCriticalAlarmOperationInProgress(true);
    try {
      final Alarm persisted = isNew
          ? await alarmRepository.createAlarm(alarm)
          : await alarmRepository.updateAlarm(alarm);
      final scheduleRes = await nativeAlarmBridge.scheduleNativeAlarm(persisted);
      await refreshAll();
      return scheduleRes;
    } finally {
      advertisingService.setCriticalAlarmOperationInProgress(false);
    }
  }

  Future<void> toggleAlarmEnabled(String id, {required bool enabled}) async {
    advertisingService.setCriticalAlarmOperationInProgress(true);
    try {
      final updated = await alarmRepository.toggleAlarmEnabled(
        id,
        enabled: enabled,
      );
      if (updated.enabled) {
        await nativeAlarmBridge.scheduleNativeAlarm(updated);
      } else {
        await nativeAlarmBridge.cancelNativeAlarm(id);
      }
      await refreshAll();
    } finally {
      advertisingService.setCriticalAlarmOperationInProgress(false);
    }
  }

  Future<void> snoozeAlarm(String id, {int? minutes}) async {
    advertisingService.setCriticalAlarmOperationInProgress(true);
    try {
      final updated = await alarmRepository.snoozeAlarm(
        id,
        customMinutes: minutes,
      );
      await nativeAlarmBridge.scheduleNativeAlarm(updated);
      await refreshAll();
    } finally {
      advertisingService.setCriticalAlarmOperationInProgress(false);
    }
  }

  Future<void> dismissAlarm(String id) async {
    advertisingService.setCriticalAlarmOperationInProgress(true);
    try {
      final updated = await alarmRepository.dismissTriggeredAlarm(id);
      if (updated.enabled && updated.nextOccurrence != null) {
        await nativeAlarmBridge.scheduleNativeAlarm(updated);
      } else {
        await nativeAlarmBridge.cancelNativeAlarm(id);
      }
      await refreshAll();
    } finally {
      advertisingService.setCriticalAlarmOperationInProgress(false);
    }
  }

  Future<void> deleteAlarm(String id) async {
    await nativeAlarmBridge.cancelNativeAlarm(id);
    await alarmRepository.deleteAlarm(id);
    await refreshAll();
  }

  Future<void> _handleNativeAlarmAction(String action, String alarmId) async {
    if (action == 'dismiss') {
      await dismissAlarm(alarmId);
    } else if (action == 'snooze') {
      await snoozeAlarm(alarmId);
    } else {
      await refreshAll();
    }
  }

  // --- Category Operations ---
  Future<void> saveCategory(
    ReminderCategory category, {
    required bool isNew,
  }) async {
    if (isNew) {
      await categoryRepository.createCategory(category);
    } else {
      await categoryRepository.updateCategory(category);
    }
    await refreshAll();
  }

  Future<int> deleteCategoryAndReassign({
    required String categoryIdToDelete,
    required String reassignToCategoryId,
  }) async {
    final reassigned = await categoryRepository.deleteCategoryWithReassignment(
      categoryIdToDelete: categoryIdToDelete,
      reassignToCategoryId: reassignToCategoryId,
    );
    if (_selectedCategoryId == categoryIdToDelete) {
      _selectedCategoryId = null;
    }
    await refreshAll();
    return reassigned;
  }

  // --- Settings & Entitlement Operations ---
  Future<void> updateThemeSettings(ThemeSettings settings) async {
    _themeSettings = settings;
    await settingsRepository.saveThemeSettings(settings);
    notifyListeners();
  }

  Future<void> updateSpeechSettings(SpeechSettings settings) async {
    _speechSettings = settings;
    await settingsRepository.saveSpeechSettings(settings);
    notifyListeners();
  }

  Future<void> updateUserPreferences(UserPreferences preferences) async {
    _userPreferences = preferences;
    await settingsRepository.saveUserPreferences(preferences);
    await refreshAll();
  }

  Future<void> updateAdvertisingConfig(AdvertisingConfiguration config) async {
    _adConfig = await advertisingService.updateConfiguration(config);
    notifyListeners();
  }

  Future<void> setQaSandboxEntitlement({required bool enabled}) async {
    _entitlement = await entitlementService.setQaSandboxEntitlement(
      enabled: enabled,
    );
    notifyListeners();
  }

  Future<WidgetSnapshotPayload> forceSyncHomeWidget() async {
    _lastWidgetSnapshot = await widgetSyncBridge.syncHomeScreenWidget(
      reminders: _reminders,
      alarms: _alarms,
      categories: _categories,
      use24HourFormat: _userPreferences.use24HourFormat,
    );
    notifyListeners();
    return _lastWidgetSnapshot!;
  }

  // --- Backup & Restore ---
  Future<BackupBundle> exportBackupBundle() {
    return backupService.createBackupBundle();
  }

  Future<RestoreSummary> restoreBackupFromJson(
    String jsonContent, {
    required RestoreStrategy strategy,
    bool restoreSettings = true,
  }) async {
    final summary = await backupService.restoreFromJson(
      jsonContent,
      strategy: strategy,
      restoreSettings: restoreSettings,
    );
    await refreshAll();
    return summary;
  }

  @override
  void dispose() {
    _themeScheduleTimer?.cancel();
    ttsService.stop();
    voiceInputService.stopListening();
    super.dispose();
  }
}
