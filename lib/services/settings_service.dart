import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import 'database_service.dart';

class SettingsService {
  SettingsService._();

  static const _apiKeyKey = 'openai_api_key';
  static const _modelKey = 'model';
  static const _dailyGoalKey = 'daily_goal';

  static final SettingsService instance = SettingsService._();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AppSettings _settings = const AppSettings(
    model: 'gpt-5-mini',
    dailyGoal: 2000,
  );

  AppSettings get settings => _settings;

  Future<void> initialize() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('settings');
    final settingsMap = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    _settings = AppSettings(
      model: settingsMap[_modelKey] ?? 'gpt-5-mini',
      dailyGoal: int.tryParse(settingsMap[_dailyGoalKey] ?? '') ?? 2000,
    );
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    final db = await DatabaseService.instance.database;
    await db.insert(
      'settings',
      {'key': _modelKey, 'value': settings.model},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'settings',
      {'key': _dailyGoalKey, 'value': settings.dailyGoal.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> setApiKey(String value) async {
    await _secureStorage.write(key: _apiKeyKey, value: value);
  }
}
