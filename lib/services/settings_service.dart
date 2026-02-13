import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/app_defaults.dart';
import '../models/app_settings.dart';
import '../models/daily_goals.dart';
import 'database_service.dart';
import 'goal_history_service.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static const _languageCodeKey = 'language_code';
  static const _apiKeyKey = 'openai_api_key';
  static const _modelKey = 'model';
  static const _reasoningEffortKey = 'reasoning_effort';
  static const _maxOutputTokensKey = 'max_output_tokens';
  static const _openAiTimeoutSecondsKey = 'openai_timeout_seconds';
  static const _dailyGoalKey = 'daily_goal';
  static const _dailyFatGoalKey = 'daily_fat_goal';
  static const _dailyProteinGoalKey = 'daily_protein_goal';
  static const _dailyCarbsGoalKey = 'daily_carbs_goal';

  static final SettingsService instance = SettingsService._();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AppSettings _settings = const AppSettings(
    languageCode: AppDefaults.languageCode,
    model: AppDefaults.model,
    reasoningEffort: AppDefaults.reasoningEffort,
    maxOutputTokens: AppDefaults.maxOutputTokens,
    openAiTimeoutSeconds: AppDefaults.openAiRequestTimeoutSeconds,
    dailyGoal: AppDefaults.dailyCalories,
    dailyFatGoal: AppDefaults.dailyFatGrams,
    dailyProteinGoal: AppDefaults.dailyProteinGrams,
    dailyCarbsGoal: AppDefaults.dailyCarbsGrams,
  );

  AppSettings get settings => _settings;

  Future<void> initialize() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('settings');
    final settingsMap = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    _settings = AppSettings(
      languageCode: _parseLanguageCode(settingsMap[_languageCodeKey]),
      model: settingsMap[_modelKey] ?? AppDefaults.model,
      reasoningEffort: AppDefaults.reasoningEffortOptions.contains(settingsMap[_reasoningEffortKey])
          ? settingsMap[_reasoningEffortKey]!
          : AppDefaults.reasoningEffort,
      maxOutputTokens: _parseMaxOutputTokens(settingsMap[_maxOutputTokensKey]),
      openAiTimeoutSeconds: _parseOpenAiTimeoutSeconds(settingsMap[_openAiTimeoutSecondsKey]),
      dailyGoal: int.tryParse(settingsMap[_dailyGoalKey] ?? '') ?? AppDefaults.dailyCalories,
      dailyFatGoal: int.tryParse(settingsMap[_dailyFatGoalKey] ?? '') ?? AppDefaults.dailyFatGrams,
      dailyProteinGoal:
          int.tryParse(settingsMap[_dailyProteinGoalKey] ?? '') ?? AppDefaults.dailyProteinGrams,
      dailyCarbsGoal:
          int.tryParse(settingsMap[_dailyCarbsGoalKey] ?? '') ?? AppDefaults.dailyCarbsGrams,
    );
    final hasGoalHistory = await db.query('goal_history', limit: 1);
    if (hasGoalHistory.isEmpty) {
      await GoalHistoryService.instance.upsertGoalsForDate(
        date: DateTime.now(),
        goals: DailyGoals.fromSettings(_settings),
      );
    }
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    final previous = _settings;
    _settings = settings;
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await txn.insert(
        'settings',
        {'key': _languageCodeKey, 'value': settings.languageCode},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _modelKey, 'value': settings.model},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _reasoningEffortKey, 'value': settings.reasoningEffort},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _maxOutputTokensKey, 'value': settings.maxOutputTokens.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _openAiTimeoutSecondsKey, 'value': settings.openAiTimeoutSeconds.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _dailyGoalKey, 'value': settings.dailyGoal.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _dailyFatGoalKey, 'value': settings.dailyFatGoal.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _dailyProteinGoalKey, 'value': settings.dailyProteinGoal.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': _dailyCarbsGoalKey, 'value': settings.dailyCarbsGoal.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    final goalsChanged = previous.dailyGoal != settings.dailyGoal ||
        previous.dailyFatGoal != settings.dailyFatGoal ||
        previous.dailyProteinGoal != settings.dailyProteinGoal ||
        previous.dailyCarbsGoal != settings.dailyCarbsGoal;
    if (goalsChanged) {
      await GoalHistoryService.instance.upsertGoalsForDate(
        date: DateTime.now(),
        goals: DailyGoals.fromSettings(settings),
      );
    }
    notifyListeners();
  }

  Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> setApiKey(String value) async {
    await _secureStorage.write(key: _apiKeyKey, value: value);
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
  }

  Map<String, String> exportSettingsMap() {
    return {
      _languageCodeKey: _settings.languageCode,
      _modelKey: _settings.model,
      _reasoningEffortKey: _settings.reasoningEffort,
      _maxOutputTokensKey: _settings.maxOutputTokens.toString(),
      _openAiTimeoutSecondsKey: _settings.openAiTimeoutSeconds.toString(),
      _dailyGoalKey: _settings.dailyGoal.toString(),
      _dailyFatGoalKey: _settings.dailyFatGoal.toString(),
      _dailyProteinGoalKey: _settings.dailyProteinGoal.toString(),
      _dailyCarbsGoalKey: _settings.dailyCarbsGoal.toString(),
    };
  }

  int _parseMaxOutputTokens(String? rawValue) {
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null || parsed < AppDefaults.minOutputTokens) {
      return AppDefaults.maxOutputTokens;
    }
    return parsed;
  }

  int _parseOpenAiTimeoutSeconds(String? rawValue) {
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null || parsed <= 0) {
      return AppDefaults.openAiRequestTimeoutSeconds;
    }
    return parsed;
  }

  String _parseLanguageCode(String? rawValue) {
    final supportedLanguageCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    if (rawValue != null && supportedLanguageCodes.contains(rawValue)) {
      return rawValue;
    }
    return AppDefaults.languageCode;
  }
}
