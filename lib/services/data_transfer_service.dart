import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';
import 'database_service.dart';
import 'food_library_service.dart';
import 'macro_ratio_preset_catalog.dart';

class ImportSummary {
  const ImportSummary({
    required this.entriesCount,
    required this.itemsCount,
    this.apiKeyFromBackup,
  });

  final int entriesCount;
  final int itemsCount;
  final String? apiKeyFromBackup;
}

class ImportPayload {
  const ImportPayload({
    required this.settings,
    required this.foods,
    required this.metabolicProfileHistory,
    required this.daySummaries,
    required this.entries,
    required this.entryItems,
    this.apiKeyFromBackup,
  });

  final Map<String, String> settings;
  final List<Map<String, dynamic>> foods;
  final List<Map<String, dynamic>> metabolicProfileHistory;
  final List<Map<String, dynamic>> daySummaries;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> entryItems;
  final String? apiKeyFromBackup;

  int get entriesCount => entries.length;
  int get itemsCount => entryItems.length;
}

class DataTransferService {
  DataTransferService._();

  static final DataTransferService instance = DataTransferService._();

  static const int _formatVersion = 2;

  Future<String?> exportData({
    required bool includeApiKey,
    String? apiKey,
  }) async {
    final db = await DatabaseService.instance.database;
    final foods = await db.query('foods');
    final entries = await db.query('entries');
    final entryItems = await db.query('entry_items');
    final settingsRows = await db.query('settings');
    final metabolicProfileHistory = await db.query('metabolic_profile_history');
    final daySummaries = await db.query('day_summary');
    final settings = {
      for (final row in settingsRows) row['key'] as String: row['value'] as String,
    };

    final payload = {
      'format_version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'foods': foods,
      'metabolic_profile_history': metabolicProfileHistory,
      'day_summary': daySummaries,
      'entries': entries,
      'entry_items': entryItems,
      if (includeApiKey && apiKey != null && apiKey.trim().isNotEmpty)
        'secure': {
          'openai_api_key': apiKey.trim(),
        },
    };

    final fileName = _exportFileName();
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final encodedBytes = utf8.encode(encoded);
    if (Platform.isAndroid || Platform.isIOS) {
      return _exportWithAndroidSaveDialog(
        fileName: fileName,
        encodedJsonBytes: encodedBytes,
      );
    }

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [jsonTypeGroup],
    );
    if (location == null) {
      return null;
    }
    final targetPath = location.path;
    final file = File(targetPath);
    await file.writeAsBytes(encodedBytes, flush: true);
    return targetPath;
  }

  Future<ImportPayload?> pickImportData() async {
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
    );
    XFile? file;
    file = await openFile(acceptedTypeGroups: [jsonTypeGroup]);
    if (file == null) {
      return null;
    }

    final rawBytes = await file.readAsBytes();
    final rawJson = utf8.decode(rawBytes);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format.');
    }
    final formatVersion = decoded['format_version'];
    if (formatVersion is! int || (formatVersion != 1 && formatVersion != _formatVersion)) {
      throw const FormatException('Unsupported backup format version.');
    }

    final settings = _readSettings(decoded['settings']);
    final foods = formatVersion >= 2 ? _readRows(decoded['foods'] ?? const []) : const <Map<String, dynamic>>[];
    final metabolicProfileHistory = _readRows(decoded['metabolic_profile_history'] ?? const []);
    final daySummaries = _readRows(decoded['day_summary'] ?? const []);
    final entries = _readRows(decoded['entries']);
    final entryItems = _readRows(decoded['entry_items']);
    final apiKeyFromBackup = _readApiKeyFromBackup(decoded['secure']);

    return ImportPayload(
      settings: settings,
      foods: foods,
      metabolicProfileHistory: metabolicProfileHistory,
      daySummaries: daySummaries,
      entries: entries,
      entryItems: entryItems,
      apiKeyFromBackup: apiKeyFromBackup,
    );
  }

  Future<ImportSummary> applyImportData(ImportPayload payload) async {
    _validateImportPayload(payload);
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await txn.delete('entry_items');
      await txn.delete('foods');
      await txn.delete('entries');
      await txn.delete('settings');
      await txn.delete('metabolic_profile_history');
      await txn.delete('day_summary');

      for (final food in payload.foods) {
        await txn.insert(
          'foods',
          {
            'id': food['id'] as int?,
            'name': food['name'] as String,
            'standard_unit': food['standard_unit'] as String,
            'standard_unit_amount': (food['standard_unit_amount'] as num).toDouble(),
            'standard_calories': (food['standard_calories'] as num).toDouble(),
            'standard_fat': (food['standard_fat'] as num).toDouble(),
            'standard_protein': (food['standard_protein'] as num).toDouble(),
            'standard_carbs': (food['standard_carbs'] as num).toDouble(),
            'notes': food['notes'] as String? ?? '',
            'created_at': food['created_at'] as String,
            'updated_at': food['updated_at'] as String,
            'is_visible_in_library': ((food['is_visible_in_library'] as num?)?.toInt() ?? 1),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final entry in payload.entries) {
        await txn.insert(
          'entries',
          {
            'id': entry['id'] as int,
            'entry_date': entry['entry_date'] as String,
            'created_at': entry['created_at'] as String,
            'prompt': entry['prompt'] as String,
            'response': entry['response'] as String,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final item in payload.entryItems) {
        final foodId = (item['food_id'] as num?)?.toInt();
        final amount = item['amount'] as String;
        final multiplierRaw = (item['multiplier'] as num?)?.toDouble() ?? 1.0;
        final multiplier = multiplierRaw > 0 ? multiplierRaw : 1.0;
        final standardUnit = (item['standard_unit'] as String?)?.trim();
        final standardUnitAmountRaw = (item['standard_unit_amount'] as num?)?.toDouble() ?? 1.0;
        final standardUnitAmount = standardUnitAmountRaw > 0 ? standardUnitAmountRaw : 1.0;
        final legacyStandardAmount = (item['standard_amount'] as String?)?.trim();
        final ratio = FoodItem.multiplierRatio(
          multiplier: multiplier,
          standardUnitAmount: standardUnitAmount,
        );
        final standardCalories =
            (item['standard_calories'] as num?)?.toDouble() ?? ((item['calories'] as num).toDouble() / ratio);
        final standardFat =
            (item['standard_fat'] as num?)?.toDouble() ?? (((item['fat'] as num?)?.toDouble() ?? 0) / ratio);
        final standardProtein = (item['standard_protein'] as num?)?.toDouble() ??
            (((item['protein'] as num?)?.toDouble() ?? 0) / ratio);
        final standardCarbs =
            (item['standard_carbs'] as num?)?.toDouble() ?? (((item['carbs'] as num?)?.toDouble() ?? 0) / ratio);
        final calories = (standardCalories * ratio).round();
        final fat = standardFat * ratio;
        final protein = standardProtein * ratio;
        final carbs = standardCarbs * ratio;
        var resolvedFoodId = foodId;
        if (resolvedFoodId == null || resolvedFoodId <= 0) {
          resolvedFoodId = await FoodLibraryService.instance.ensureFoodInDatabase(
            txn,
            name: item['name'] as String,
            standardUnit: (standardUnit != null && standardUnit.isNotEmpty)
                ? standardUnit
                : amount,
            standardUnitAmount: standardUnitAmount,
            standardCalories: standardCalories,
            standardFat: standardFat,
            standardProtein: standardProtein,
            standardCarbs: standardCarbs,
            notes: item['notes'] as String? ?? '',
            isVisibleInLibrary: true,
          );
        }
        await txn.insert(
          'entry_items',
          {
            'id': item['id'] as int,
            'entry_id': item['entry_id'] as int,
            'food_id': resolvedFoodId,
            'name': item['name'] as String,
            'amount': amount,
            'calories': calories,
            'fat': fat,
            'protein': protein,
            'carbs': carbs,
            'standard_amount': (legacyStandardAmount != null && legacyStandardAmount.isNotEmpty)
                ? legacyStandardAmount
                : '$standardUnitAmount ${standardUnit ?? amount}',
            'standard_unit': (standardUnit != null && standardUnit.isNotEmpty)
                ? standardUnit
                : (legacyStandardAmount != null && legacyStandardAmount.isNotEmpty)
                    ? legacyStandardAmount
                    : amount,
            'standard_unit_amount': standardUnitAmount,
            'multiplier': multiplier,
            'standard_calories': standardCalories,
            'standard_fat': standardFat,
            'standard_protein': standardProtein,
            'standard_carbs': standardCarbs,
            'notes': item['notes'] as String? ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final setting in payload.settings.entries) {
        await txn.insert(
          'settings',
          {'key': setting.key, 'value': setting.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final profile in payload.metabolicProfileHistory) {
        final importedFat = (profile['fat_ratio_percent'] as num?)?.round() ?? 30;
        final importedProtein = (profile['protein_ratio_percent'] as num?)?.round() ?? 30;
        final importedCarbs = (profile['carbs_ratio_percent'] as num?)?.round() ?? 40;
        final presetKey = (profile['macro_preset_key'] as String?)?.trim();
        final resolvedPreset = (presetKey == null || presetKey.isEmpty)
            ? MacroRatioPresetCatalog.presetForKey(
                MacroRatioPresetCatalog.keyForRatios(
                  fatPercent: importedFat,
                  proteinPercent: importedProtein,
                  carbsPercent: importedCarbs,
                ),
              )
            : MacroRatioPresetCatalog.presetForKey(presetKey);
        await txn.insert(
          'metabolic_profile_history',
          {
            'id': profile['id'] as int?,
            'profile_date': profile['profile_date'] as String,
            'age': (profile['age'] as num).round(),
            'sex': profile['sex'] as String,
            'height_cm': (profile['height_cm'] as num).toDouble(),
            'weight_kg': (profile['weight_kg'] as num).toDouble(),
            'activity_level': profile['activity_level'] as String,
            'macro_preset_key': resolvedPreset.key,
            'fat_ratio_percent': resolvedPreset.fatPercent,
            'protein_ratio_percent': resolvedPreset.proteinPercent,
            'carbs_ratio_percent': resolvedPreset.carbsPercent,
            'created_at': profile['created_at'] as String,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final summary in payload.daySummaries) {
        await txn.insert(
          'day_summary',
          {
            'summary_date': summary['summary_date'] as String,
            'language_code': summary['language_code'] as String,
            'model': summary['model'] as String? ?? '',
            'source_hash': summary['source_hash'] as String,
            'summary_json': summary['summary_json'] as String,
            'created_at': summary['created_at'] as String,
            'updated_at': summary['updated_at'] as String,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return ImportSummary(
      entriesCount: payload.entriesCount,
      itemsCount: payload.itemsCount,
      apiKeyFromBackup: payload.apiKeyFromBackup,
    );
  }

  void _validateImportPayload(ImportPayload payload) {
    for (final entry in payload.entries) {
      _requireInt(entry, 'id', table: 'entries');
      _requireString(entry, 'entry_date', table: 'entries');
      _requireString(entry, 'created_at', table: 'entries');
      _requireString(entry, 'prompt', table: 'entries');
      _requireString(entry, 'response', table: 'entries');
    }

    for (final food in payload.foods) {
      _requireOptionalInt(food, 'id', table: 'foods');
      _requireString(food, 'name', table: 'foods');
      _requireString(food, 'standard_unit', table: 'foods');
      _requireNum(food, 'standard_unit_amount', table: 'foods');
      _requireNum(food, 'standard_calories', table: 'foods');
      _requireNum(food, 'standard_fat', table: 'foods');
      _requireNum(food, 'standard_protein', table: 'foods');
      _requireNum(food, 'standard_carbs', table: 'foods');
      _requireOptionalString(food, 'notes', table: 'foods');
      _requireString(food, 'created_at', table: 'foods');
      _requireString(food, 'updated_at', table: 'foods');
      _requireOptionalNum(food, 'is_visible_in_library', table: 'foods');
    }

    for (final item in payload.entryItems) {
      _requireInt(item, 'id', table: 'entry_items');
      _requireInt(item, 'entry_id', table: 'entry_items');
      _requireOptionalInt(item, 'food_id', table: 'entry_items');
      _requireString(item, 'name', table: 'entry_items');
      _requireString(item, 'amount', table: 'entry_items');
      _requireNum(item, 'calories', table: 'entry_items');
      _requireOptionalNum(item, 'fat', table: 'entry_items');
      _requireOptionalNum(item, 'protein', table: 'entry_items');
      _requireOptionalNum(item, 'carbs', table: 'entry_items');
      _requireOptionalString(item, 'standard_amount', table: 'entry_items');
      _requireOptionalString(item, 'standard_unit', table: 'entry_items');
      _requireOptionalNum(item, 'standard_unit_amount', table: 'entry_items');
      _requireOptionalNum(item, 'multiplier', table: 'entry_items');
      _requireOptionalNum(item, 'standard_calories', table: 'entry_items');
      _requireOptionalNum(item, 'standard_fat', table: 'entry_items');
      _requireOptionalNum(item, 'standard_protein', table: 'entry_items');
      _requireOptionalNum(item, 'standard_carbs', table: 'entry_items');
      _requireOptionalString(item, 'notes', table: 'entry_items');
      final multiplier = (item['multiplier'] as num?)?.toDouble();
      if (multiplier != null && multiplier <= 0) {
        throw const FormatException('Invalid "entry_items.multiplier" in backup payload.');
      }
    }

    for (final profile in payload.metabolicProfileHistory) {
      _requireOptionalInt(profile, 'id', table: 'metabolic_profile_history');
      _requireString(profile, 'profile_date', table: 'metabolic_profile_history');
      _requireInt(profile, 'age', table: 'metabolic_profile_history');
      _requireString(profile, 'sex', table: 'metabolic_profile_history');
      _requireNum(profile, 'height_cm', table: 'metabolic_profile_history');
      _requireNum(profile, 'weight_kg', table: 'metabolic_profile_history');
      _requireString(profile, 'activity_level', table: 'metabolic_profile_history');
      _requireOptionalString(profile, 'macro_preset_key', table: 'metabolic_profile_history');
      _requireOptionalNum(profile, 'fat_ratio_percent', table: 'metabolic_profile_history');
      _requireOptionalNum(profile, 'protein_ratio_percent', table: 'metabolic_profile_history');
      _requireOptionalNum(profile, 'carbs_ratio_percent', table: 'metabolic_profile_history');
      _requireString(profile, 'created_at', table: 'metabolic_profile_history');
      _validateMacroRatios(profile);
    }

    for (final summary in payload.daySummaries) {
      _requireString(summary, 'summary_date', table: 'day_summary');
      _requireString(summary, 'language_code', table: 'day_summary');
      _requireOptionalString(summary, 'model', table: 'day_summary');
      _requireString(summary, 'source_hash', table: 'day_summary');
      _requireString(summary, 'summary_json', table: 'day_summary');
      _requireString(summary, 'created_at', table: 'day_summary');
      _requireString(summary, 'updated_at', table: 'day_summary');
    }
  }

  void _validateMacroRatios(Map<String, dynamic> row) {
    final presetKey = (row['macro_preset_key'] as String?)?.trim();
    if (presetKey != null && presetKey.isNotEmpty) {
      final preset = MacroRatioPresetCatalog.presetForKey(presetKey);
      if (preset.key != presetKey) {
        throw const FormatException('Invalid macro preset key in backup payload.');
      }
      return;
    }
    final fat = (row['fat_ratio_percent'] as num?)?.round() ?? 30;
    final protein = (row['protein_ratio_percent'] as num?)?.round() ?? 30;
    final carbs = (row['carbs_ratio_percent'] as num?)?.round() ?? 40;
    final values = [fat, protein, carbs];
    if (values.any((v) => v < 0 || v > 100)) {
      throw const FormatException('Invalid macro ratio range in backup payload.');
    }
    if (fat + protein + carbs != 100) {
      throw const FormatException('Macro ratios in backup payload must sum to 100.');
    }
  }

  void _requireString(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value is! String) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
  }

  void _requireOptionalString(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value != null && value is! String) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
  }

  void _requireInt(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value is! int) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
  }

  void _requireOptionalInt(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value != null && value is! int) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
  }

  void _requireNum(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value is! num) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
  }

  void _requireOptionalNum(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value != null && value is! num) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
  }

  Map<String, String> _readSettings(Object? rawSettings) {
    if (rawSettings is! Map<String, dynamic>) {
      throw const FormatException('Invalid settings payload.');
    }
    final settings = <String, String>{};
    for (final entry in rawSettings.entries) {
      settings[entry.key] = entry.value.toString();
    }
    return settings;
  }

  List<Map<String, dynamic>> _readRows(Object? rawRows) {
    if (rawRows is! List) {
      throw const FormatException('Invalid row payload.');
    }
    return rawRows
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid row payload item.');
          }
          return item;
        })
        .toList(growable: false);
  }

  String? _readApiKeyFromBackup(Object? rawSecure) {
    if (rawSecure is! Map<String, dynamic>) {
      return null;
    }
    final rawKey = rawSecure['openai_api_key'];
    if (rawKey is! String) {
      return null;
    }
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _exportFileName() {
    return 'calorie_tracker_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
  }

  Future<String?> _exportWithAndroidSaveDialog({
    required String fileName,
    required List<int> encodedJsonBytes,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final sourceFile = File('${tempDir.path}/$fileName');
    await sourceFile.writeAsBytes(encodedJsonBytes, flush: true);
    try {
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: sourceFile.path,
          mimeTypesFilter: const ['application/json'],
        ),
      );
      return savedPath;
    } finally {
      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }
    }
  }
}
