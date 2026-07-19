import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';
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
      for (final row in settingsRows)
        row['key'] as String: row['value'] as String,
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
    if (formatVersion != _formatVersion) {
      throw const FormatException('Unsupported backup format version.');
    }

    final settings = _readSettings(decoded['settings']);
    final foods = _readRows(decoded['foods']);
    final metabolicProfileHistory =
        _readRows(decoded['metabolic_profile_history']);
    final daySummaries = _readRows(decoded['day_summary']);
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
    final db = await DatabaseService.instance.database;
    return applyImportDataInDatabase(db, payload);
  }

  Future<ImportSummary> applyImportDataInDatabase(
    Database db,
    ImportPayload payload,
  ) async {
    _validateImportPayload(payload);
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
            'id': food['id'] as int,
            'name': food['name'] as String,
            'standard_unit': food['standard_unit'] as String,
            'standard_unit_amount':
                (food['standard_unit_amount'] as num).toDouble(),
            'standard_calories': (food['standard_calories'] as num).toDouble(),
            'standard_fat': (food['standard_fat'] as num).toDouble(),
            'standard_protein': (food['standard_protein'] as num).toDouble(),
            'standard_carbs': (food['standard_carbs'] as num).toDouble(),
            'notes': food['notes'] as String? ?? '',
            'created_at': food['created_at'] as String,
            'updated_at': food['updated_at'] as String,
            'is_visible_in_library':
                (food['is_visible_in_library'] as num).toInt(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
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
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final item in payload.entryItems) {
        await txn.insert(
          'entry_items',
          {
            'id': item['id'] as int,
            'entry_id': item['entry_id'] as int,
            'food_id': item['food_id'] as int,
            'name': item['name'] as String,
            'amount': item['amount'] as String,
            'calories': (item['calories'] as num).round(),
            'fat': (item['fat'] as num).toDouble(),
            'protein': (item['protein'] as num).toDouble(),
            'carbs': (item['carbs'] as num).toDouble(),
            'standard_amount': item['standard_amount'] as String,
            'standard_unit': item['standard_unit'] as String,
            'standard_unit_amount':
                (item['standard_unit_amount'] as num).toDouble(),
            'multiplier': (item['multiplier'] as num).toDouble(),
            'standard_calories': (item['standard_calories'] as num).toDouble(),
            'standard_fat': (item['standard_fat'] as num).toDouble(),
            'standard_protein': (item['standard_protein'] as num).toDouble(),
            'standard_carbs': (item['standard_carbs'] as num).toDouble(),
            'notes': item['notes'] as String? ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final setting in payload.settings.entries) {
        await txn.insert(
          'settings',
          {'key': setting.key, 'value': setting.value},
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final profile in payload.metabolicProfileHistory) {
        await txn.insert(
          'metabolic_profile_history',
          {
            'id': profile['id'] as int,
            'profile_date': profile['profile_date'] as String,
            'age': (profile['age'] as num).round(),
            'sex': profile['sex'] as String,
            'height_cm': (profile['height_cm'] as num).toDouble(),
            'weight_kg': (profile['weight_kg'] as num).toDouble(),
            'activity_level': profile['activity_level'] as String,
            'macro_preset_key': profile['macro_preset_key'] as String,
            'fat_ratio_percent': (profile['fat_ratio_percent'] as num).round(),
            'protein_ratio_percent':
                (profile['protein_ratio_percent'] as num).round(),
            'carbs_ratio_percent':
                (profile['carbs_ratio_percent'] as num).round(),
            'created_at': profile['created_at'] as String,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final summary in payload.daySummaries) {
        await txn.insert(
          'day_summary',
          {
            'summary_date': summary['summary_date'] as String,
            'language_code': summary['language_code'] as String,
            'model': summary['model'] as String,
            'source_hash': summary['source_hash'] as String,
            'summary_json': summary['summary_json'] as String,
            'created_at': summary['created_at'] as String,
            'updated_at': summary['updated_at'] as String,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
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
    final entryIds = _requireUniquePositiveIds(
      payload.entries,
      table: 'entries',
    );
    final foodIds = _requireUniquePositiveIds(
      payload.foods,
      table: 'foods',
    );
    _requireUniquePositiveIds(
      payload.entryItems,
      table: 'entry_items',
    );
    _requireUniquePositiveIds(
      payload.metabolicProfileHistory,
      table: 'metabolic_profile_history',
    );

    for (final entry in payload.entries) {
      _requireString(entry, 'entry_date', table: 'entries');
      _requireString(entry, 'created_at', table: 'entries');
      _requireString(entry, 'prompt', table: 'entries');
      _requireString(entry, 'response', table: 'entries');
    }

    for (final food in payload.foods) {
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
      _requireNum(food, 'is_visible_in_library', table: 'foods');
      if ((food['standard_unit_amount'] as num).toDouble() <= 0) {
        throw const FormatException(
          'Invalid "foods.standard_unit_amount" in backup payload.',
        );
      }
    }

    for (final item in payload.entryItems) {
      final entryId = _requirePositiveInt(
        item,
        'entry_id',
        table: 'entry_items',
      );
      final foodId = _requirePositiveInt(
        item,
        'food_id',
        table: 'entry_items',
      );
      _requireString(item, 'name', table: 'entry_items');
      _requireString(item, 'amount', table: 'entry_items');
      _requireNum(item, 'calories', table: 'entry_items');
      _requireNum(item, 'fat', table: 'entry_items');
      _requireNum(item, 'protein', table: 'entry_items');
      _requireNum(item, 'carbs', table: 'entry_items');
      _requireString(item, 'standard_amount', table: 'entry_items');
      _requireString(item, 'standard_unit', table: 'entry_items');
      _requireNum(item, 'standard_unit_amount', table: 'entry_items');
      _requireNum(item, 'multiplier', table: 'entry_items');
      _requireNum(item, 'standard_calories', table: 'entry_items');
      _requireNum(item, 'standard_fat', table: 'entry_items');
      _requireNum(item, 'standard_protein', table: 'entry_items');
      _requireNum(item, 'standard_carbs', table: 'entry_items');
      _requireOptionalString(item, 'notes', table: 'entry_items');
      if ((item['standard_unit_amount'] as num).toDouble() <= 0) {
        throw const FormatException(
          'Invalid "entry_items.standard_unit_amount" in backup payload.',
        );
      }
      if ((item['multiplier'] as num).toDouble() <= 0) {
        throw const FormatException(
          'Invalid "entry_items.multiplier" in backup payload.',
        );
      }
      if (!entryIds.contains(entryId)) {
        throw FormatException(
          'Invalid "entry_items.entry_id" reference in backup payload: '
          'entries.id $entryId does not exist.',
        );
      }
      if (!foodIds.contains(foodId)) {
        throw FormatException(
          'Invalid "entry_items.food_id" reference in backup payload: '
          'foods.id $foodId does not exist.',
        );
      }
    }

    for (final profile in payload.metabolicProfileHistory) {
      _requireString(profile, 'profile_date',
          table: 'metabolic_profile_history');
      _requireInt(profile, 'age', table: 'metabolic_profile_history');
      _requireString(profile, 'sex', table: 'metabolic_profile_history');
      _requireNum(profile, 'height_cm', table: 'metabolic_profile_history');
      _requireNum(profile, 'weight_kg', table: 'metabolic_profile_history');
      _requireString(profile, 'activity_level',
          table: 'metabolic_profile_history');
      _requireString(profile, 'macro_preset_key',
          table: 'metabolic_profile_history');
      _requireNum(profile, 'fat_ratio_percent',
          table: 'metabolic_profile_history');
      _requireNum(profile, 'protein_ratio_percent',
          table: 'metabolic_profile_history');
      _requireNum(profile, 'carbs_ratio_percent',
          table: 'metabolic_profile_history');
      _requireString(profile, 'created_at', table: 'metabolic_profile_history');
      _validateMacroRatios(profile);
    }

    for (final summary in payload.daySummaries) {
      _requireString(summary, 'summary_date', table: 'day_summary');
      _requireString(summary, 'language_code', table: 'day_summary');
      _requireString(summary, 'model', table: 'day_summary');
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
        throw const FormatException(
            'Invalid macro preset key in backup payload.');
      }
      return;
    }
    final fat = (row['fat_ratio_percent'] as num?)?.round() ?? 30;
    final protein = (row['protein_ratio_percent'] as num?)?.round() ?? 30;
    final carbs = (row['carbs_ratio_percent'] as num?)?.round() ?? 40;
    final values = [fat, protein, carbs];
    if (values.any((v) => v < 0 || v > 100)) {
      throw const FormatException(
          'Invalid macro ratio range in backup payload.');
    }
    if (fat + protein + carbs != 100) {
      throw const FormatException(
          'Macro ratios in backup payload must sum to 100.');
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

  int _requirePositiveInt(
    Map<String, dynamic> row,
    String key, {
    required String table,
  }) {
    final value = row[key];
    if (value is! int || value <= 0) {
      throw FormatException('Invalid "$table.$key" in backup payload.');
    }
    return value;
  }

  Set<int> _requireUniquePositiveIds(
    List<Map<String, dynamic>> rows, {
    required String table,
  }) {
    final ids = <int>{};
    for (final row in rows) {
      final id = _requirePositiveInt(row, 'id', table: table);
      if (!ids.add(id)) {
        throw FormatException(
          'Duplicate "$table.id" value $id in backup payload.',
        );
      }
    }
    return ids;
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

  Map<String, String> _readSettings(Object? rawSettings) {
    if (rawSettings is! Map<String, dynamic>) {
      throw const FormatException('Invalid settings payload.');
    }
    final settings = <String, String>{};
    for (final entry in rawSettings.entries) {
      if (entry.value is! String) {
        throw const FormatException('Invalid settings payload.');
      }
      settings[entry.key] = entry.value as String;
    }
    return settings;
  }

  List<Map<String, dynamic>> _readRows(Object? rawRows) {
    if (rawRows is! List) {
      throw const FormatException('Invalid row payload.');
    }
    return rawRows.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid row payload item.');
      }
      return item;
    }).toList(growable: false);
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
