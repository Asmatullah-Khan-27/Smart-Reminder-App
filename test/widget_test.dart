import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_reminder_alarm/data/database/app_database.dart';
import 'package:smart_reminder_alarm/main.dart';
import 'package:smart_reminder_alarm/presentation/state/app_controller.dart';

void main() {
  sqfliteFfiInit();

  testWidgets(
    'App renders Dashboard from SQLite and navigates across Reminders, Alarms, and Settings tabs',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      late AppDatabase db;
      late AppController controller;

      await tester.runAsync(() async {
        db = AppDatabase(
          customDatabaseFactory: databaseFactoryFfi,
          customDbPath: inMemoryDatabasePath,
        );
        controller = AppController(customDatabase: db);
        await controller.initialize(seedStarterRecordsIfEmpty: true);
      });

      await tester.pumpWidget(
        SmartReminderVoiceAlarmApp(controller: controller),
      );
      await tester.pumpAndSettle();

      // Verify Dashboard renders SQLite-loaded records & Next Scheduled Alarm
      expect(find.text('Smart Command Center'), findsOneWidget);
      expect(find.text('NEXT SCHEDULED NATIVE ALARM'), findsOneWidget);

      // Navigate to Reminders tab
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Reminders'), findsOneWidget);
      expect(find.text('Architecture & Sprint Review Standup'), findsOneWidget);

      // Navigate to Alarms tab
      await tester.tap(find.text('Alarms'));
      await tester.pumpAndSettle();
      expect(find.text('Voice & Ringtone Alarms'), findsOneWidget);
      expect(find.text('Morning Executive Voice Wake-Up'), findsOneWidget);

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Modules & Feature Configuration'), findsOneWidget);
      expect(
        find.text('Smart Reminder Pro & Store Billing'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        controller.dispose();
        await db.close();
      });
    },
  );
}
