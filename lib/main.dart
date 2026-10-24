import 'package:flutter/material.dart';
import 'presentation/screens/alarm_form_screen.dart';
import 'presentation/screens/alarm_list_screen.dart';
import 'presentation/screens/app_settings_screen.dart';
import 'presentation/screens/categories_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/premium_upgrade_screen.dart';
import 'presentation/screens/reminder_form_screen.dart';
import 'presentation/screens/reminder_list_screen.dart';
import 'presentation/state/app_controller.dart';
import 'presentation/theme/glass_theme.dart';
import 'presentation/widgets/glass_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  controller.initialize();
  runApp(SmartReminderVoiceAlarmApp(controller: controller));
}

class SmartReminderVoiceAlarmApp extends StatelessWidget {
  final AppController controller;

  const SmartReminderVoiceAlarmApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final themeSettings = controller.themeSettings;
        return MaterialApp(
          title: 'Smart Reminder & Voice Alarm',
          debugShowCheckedModeBanner: false,
          theme: GlassTheme.buildLightTheme(themeSettings),
          darkTheme: GlassTheme.buildDarkTheme(themeSettings),
          themeMode: controller.effectiveThemeMode,
          home: MainShellScreen(controller: controller),
        );
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final AppController controller;

  const MainShellScreen({super.key, required this.controller});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkInitialWidgetLaunchAction();
  }

  Future<void> _checkInitialWidgetLaunchAction() async {
    final actionMap = await widget.controller.widgetSyncBridge
        .consumeInitialWidgetLaunchAction();
    if (!mounted || actionMap == null) return;
    final action = actionMap['action'];
    final targetId = actionMap['targetId'];

    if (action == 'quick_add_reminder') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReminderFormScreen(controller: widget.controller),
        ),
      );
    } else if (action == 'open_reminder' && targetId != null) {
      final rem =
          await widget.controller.reminderRepository.getReminderById(targetId);
      if (mounted && rem != null) {
        await ReminderListScreen.showReminderDetailsSheet(
          context: context,
          controller: widget.controller,
          reminder: rem,
        );
      }
    }
  }

  String _titleForTab(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Smart Reminders';
      case 2:
        return 'Voice & Ringtone Alarms';
      case 3:
        return 'Settings & Modules';
      default:
        return 'Smart Reminder & Voice Alarm';
    }
  }

  Widget _buildActivePage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          controller: widget.controller,
          onNavigateTab: (int tab) => setState(() => _selectedIndex = tab),
        );
      case 1:
        return ReminderListScreen(controller: widget.controller);
      case 2:
        return AlarmListScreen(controller: widget.controller);
      case 3:
        return AppSettingsScreen(controller: widget.controller);
      default:
        return DashboardScreen(controller: widget.controller);
    }
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedIndex == 0 || _selectedIndex == 1) {
      return FloatingActionButton.extended(
        key: const Key('fab_new_reminder'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReminderFormScreen(controller: widget.controller),
            ),
          );
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Reminder'),
      );
    }
    if (_selectedIndex == 2) {
      return FloatingActionButton.extended(
        key: const Key('fab_new_alarm'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AlarmFormScreen(controller: widget.controller),
            ),
          );
        },
        icon: const Icon(Icons.alarm_add_rounded),
        label: const Text('New Alarm'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final isWideTablet = MediaQuery.of(context).size.width >= 720;

        return GlassScaffold(
          themeSettings: widget.controller.themeSettings,
          appBar: AppBar(
            title: Text(
              _titleForTab(_selectedIndex),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Categories',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CategoriesScreen(controller: widget.controller),
                    ),
                  );
                },
                icon: const Icon(Icons.category_outlined),
              ),
              IconButton(
                tooltip: 'Upgrade / Entitlements',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PremiumUpgradeScreen(controller: widget.controller),
                    ),
                  );
                },
                icon: Icon(
                  widget.controller.isPremiumActive
                      ? Icons.workspace_premium_rounded
                      : Icons.workspace_premium_outlined,
                  color: widget.controller.isPremiumActive
                      ? Colors.amber
                      : null,
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(),
          bottomNavigationBar: isWideTablet
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int idx) {
                    setState(() => _selectedIndex = idx);
                  },
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline_rounded),
                      selectedIcon: Icon(Icons.check_circle_rounded),
                      label: 'Reminders',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.alarm_outlined),
                      selectedIcon: Icon(Icons.alarm_on_rounded),
                      label: 'Alarms',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune_rounded),
                      selectedIcon: Icon(Icons.settings_suggest_rounded),
                      label: 'Settings',
                    ),
                  ],
                ),
          body: isWideTablet
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int idx) {
                        setState(() => _selectedIndex = idx);
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: const <NavigationRailDestination>[
                        NavigationRailDestination(
                          icon: Icon(Icons.space_dashboard_outlined),
                          selectedIcon: Icon(Icons.space_dashboard_rounded),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.check_circle_outline_rounded),
                          selectedIcon: Icon(Icons.check_circle_rounded),
                          label: Text('Reminders'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.alarm_outlined),
                          selectedIcon: Icon(Icons.alarm_on_rounded),
                          label: Text('Alarms'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_rounded),
                          selectedIcon: Icon(Icons.settings_suggest_rounded),
                          label: Text('Settings'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildActivePage()),
                  ],
                )
              : _buildActivePage(),
        );
      },
    );
  }
}
