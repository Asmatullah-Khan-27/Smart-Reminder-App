import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/backup_bundle.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';
import 'premium_upgrade_screen.dart';

class BackupExportScreen extends StatefulWidget {
  final AppController controller;

  const BackupExportScreen({super.key, required this.controller});

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  final TextEditingController _jsonEditorController = TextEditingController();
  RestoreStrategy _selectedStrategy = RestoreStrategy.mergeKeepExisting;
  bool _restoreSettings = true;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _jsonEditorController.dispose();
    super.dispose();
  }

  Future<void> _generateExportJson() async {
    final bundle = await widget.controller.exportBackupBundle();
    final pretty = bundle.toPrettyJson();
    setState(() {
      _jsonEditorController.text = pretty;
      _isError = false;
      _statusMessage =
          'Exported ${bundle.reminders.length} reminder(s), ${bundle.alarms.length} alarm(s), and ${bundle.categories.length} category(s) into versioned JSON (Schema v${bundle.schemaVersion}).';
    });
  }

  Future<void> _exportToFileOnDisk() async {
    try {
      final file = await widget.controller.backupService.exportBackupToFile();
      final bundle = await widget.controller.exportBackupBundle();
      setState(() {
        _jsonEditorController.text = bundle.toPrettyJson();
        _isError = false;
        _statusMessage = 'Saved local backup file to: ${file.path}';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = 'Could not write file to documents directory: $e';
      });
    }
  }

  void _validateCurrentJson() {
    try {
      final bundle = widget.controller.backupService.validateBackupJson(
        _jsonEditorController.text,
      );
      setState(() {
        _isError = false;
        _statusMessage =
            'Valid Backup Bundle (v${bundle.schemaVersion}): ${bundle.reminders.length} reminders, ${bundle.alarms.length} alarms, ${bundle.categories.length} categories.';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = 'Backup validation failed: $e';
      });
    }
  }

  Future<void> _confirmAndRestore() async {
    if (!widget.controller.isFeatureEntitled(PremiumFeature.backupAndRestore)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Backup & Restore is a Premium feature. Enable Pro or QA Sandbox on the Upgrade screen.',
          ),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PremiumUpgradeScreen(controller: widget.controller),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    // Validate before showing confirmation dialog
    final BackupBundle validated;
    try {
      validated = widget.controller.backupService.validateBackupJson(
        _jsonEditorController.text,
      );
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Restore aborted — invalid backup payload (existing SQLite records were not modified): $e';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Confirm Local Backup Restore'),
        content: Text(
          'Selected Mode: ${_selectedStrategy.title}\n\n'
          '${_selectedStrategy.description}\n\n'
          'Bundle contains ${validated.reminders.length} reminder(s), '
          '${validated.alarms.length} alarm(s), and ${validated.categories.length} category(s). '
          'Proceed with transactional SQLite restore?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final summary = await widget.controller.restoreBackupFromJson(
        _jsonEditorController.text,
        strategy: _selectedStrategy,
        restoreSettings: _restoreSettings,
      );
      setState(() {
        _isError = false;
        _statusMessage =
            'Restore Complete! Reminders (+${summary.remindersInserted} inserted, ${summary.remindersUpdated} updated, ${summary.remindersSkipped} skipped) • '
            'Alarms (+${summary.alarmsInserted} inserted, ${summary.alarmsUpdated} updated, ${summary.alarmsSkipped} skipped).';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Restore failed; SQLite transaction rolled back safely: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitled = widget.controller.isFeatureEntitled(
      PremiumFeature.backupAndRestore,
    );

    return GlassScaffold(
      themeSettings: widget.controller.themeSettings,
      appBar: AppBar(
        title: const Text('Local Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.shield_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '100% Offline Versioned Backup Engine',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TierStatusBadge(isPremium: entitled),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your personal reminder and alarm data never leaves your device. Backups use a versioned JSON schema (v2) with pre-import validation and atomic SQLite transactions.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _generateExportJson,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Generate Backup JSON'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportToFileOnDisk,
                      icon: const Icon(Icons.save_alt_rounded, size: 18),
                      label: const Text('Save Backup File'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (_jsonEditorController.text.isEmpty) {
                          await _generateExportJson();
                        }
                        await Clipboard.setData(
                          ClipboardData(text: _jsonEditorController.text),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Backup JSON copied to clipboard.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Restore Strategy Selector
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Restore & Duplicate ID Resolution Strategy',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Restoring a backup can either merge records or replace all current data depending on the operation selected below:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                RadioGroup<RestoreStrategy>(
                  groupValue: _selectedStrategy,
                  onChanged: (RestoreStrategy? val) {
                    if (val != null) {
                      setState(() => _selectedStrategy = val);
                    }
                  },
                  child: Column(
                    children: RestoreStrategy.values.map((strategy) {
                      return RadioListTile<RestoreStrategy>(
                        contentPadding: EdgeInsets.zero,
                        value: strategy,
                        title: Text(
                          strategy.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          strategy.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Restore Theme, Speech & User Preferences'),
                  value: _restoreSettings,
                  onChanged: (bool val) {
                    setState(() => _restoreSettings = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // JSON Inspector / Import Editor
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Backup JSON Payload (Export Preview / Paste to Import)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _jsonEditorController,
                  maxLines: 10,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Tap "Generate Backup JSON" above or paste a SMART_REMINDER_VOICE_ALARM_BACKUP JSON payload here...',
                  ),
                ),
                if (_statusMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isError ? Colors.redAccent : Colors.teal)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isError ? Colors.redAccent : Colors.tealAccent,
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _validateCurrentJson,
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Validate Payload'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirmAndRestore,
                        icon: const Icon(Icons.restore_page_rounded, size: 18),
                        label: const Text('Restore Backup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
