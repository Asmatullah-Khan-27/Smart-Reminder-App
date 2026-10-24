import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/app_settings.dart';
import '../database/app_database.dart';

class SettingsRepository {
  static const String keyThemeSettings = 'theme_settings';
  static const String keySpeechSettings = 'speech_settings';
  static const String keyUserPreferences = 'user_preferences';
  static const String keyPremiumEntitlement = 'premium_entitlement';
  static const String keyAdvertisingConfig = 'advertising_config';

  final AppDatabase _appDatabase;

  SettingsRepository(this._appDatabase);

  Future<Map<String, dynamic>?> _readKeyMap(String key) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableKeyValueStore,
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final raw = rows.first['valueJson'] as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {}
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final fallback = prefs.getString('srva_$key');
      if (fallback != null && fallback.isNotEmpty) {
        final decoded = jsonDecode(fallback);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeKeyMap(String key, Map<String, dynamic> map) async {
    final encoded = jsonEncode(map);
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.tableKeyValueStore,
      <String, Object?>{
        'key': key,
        'valueJson': encoded,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('srva_$key', encoded);
    } catch (_) {}
  }

  Future<ThemeSettings> loadThemeSettings() async {
    final map = await _readKeyMap(keyThemeSettings);
    if (map == null) return const ThemeSettings();
    return ThemeSettings.fromMap(map);
  }

  Future<void> saveThemeSettings(ThemeSettings settings) async {
    await _writeKeyMap(keyThemeSettings, settings.toMap());
  }

  Future<SpeechSettings> loadSpeechSettings() async {
    final map = await _readKeyMap(keySpeechSettings);
    if (map == null) return const SpeechSettings();
    return SpeechSettings.fromMap(map);
  }

  Future<void> saveSpeechSettings(SpeechSettings settings) async {
    await _writeKeyMap(keySpeechSettings, settings.toMap());
  }

  Future<UserPreferences> loadUserPreferences() async {
    final map = await _readKeyMap(keyUserPreferences);
    if (map == null) return const UserPreferences();
    return UserPreferences.fromMap(map);
  }

  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await _writeKeyMap(keyUserPreferences, preferences.toMap());
  }

  Future<PremiumEntitlement> loadPremiumEntitlement() async {
    final map = await _readKeyMap(keyPremiumEntitlement);
    if (map == null) {
      return PremiumEntitlement(updatedAt: DateTime.now());
    }
    return PremiumEntitlement.fromMap(map);
  }

  Future<void> savePremiumEntitlement(PremiumEntitlement entitlement) async {
    await _writeKeyMap(keyPremiumEntitlement, entitlement.toMap());
  }

  Future<AdvertisingConfiguration> loadAdvertisingConfig() async {
    final map = await _readKeyMap(keyAdvertisingConfig);
    if (map == null) return const AdvertisingConfiguration();
    return AdvertisingConfiguration.fromMap(map);
  }

  Future<void> saveAdvertisingConfig(AdvertisingConfiguration config) async {
    await _writeKeyMap(keyAdvertisingConfig, config.toMap());
  }
}
