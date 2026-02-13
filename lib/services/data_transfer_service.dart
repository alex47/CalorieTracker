import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

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
    required this.metabolicProfileHistory,
    required this.entries,
    required this.entryItems,
    this.apiKeyFromBackup,
  });

  final Map<String, String> settings;
  final List<Map<String, dynamic>> metabolicProfileHistory;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> entryItems;
  final String? apiKeyFromBackup;

  int get entriesCount => entries.length;
  int get itemsCount => entryItems.length;
}

class DataTransferService {
  DataTransferService._();

  static final DataTransferService instance = DataTransferService._();

  static const int _formatVersion = 1;

  Future<String?> exportData({
    required bool includeApiKey,
    String? apiKey,
  }) async {
    final db = await DatabaseService.instance.database;
    final entries = await db.query('entries');
    final entryItems = await db.query('entry_items');
    final settingsRows = await db.query('settings');
    final metabolicProfileHistory = await db.query('metabolic_profile_history');
    final settings = {
      for (final row in settingsRows) row['key'] as String: row['value'] as String,
    };

    final payload = {
      'format_version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'metabolic_profile_history': metabolicProfileHistory,
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
    if (decoded['format_version'] is! int || decoded['format_version'] != _formatVersion) {
      throw const FormatException('Unsupported backup format version.');
    }

    final settings = _readSettings(decoded['settings']);
    final metabolicProfileHistory = _readRows(decoded['metabolic_profile_history'] ?? const []);
    final entries = _readRows(decoded['entries']);
    final entryItems = _readRows(decoded['entry_items']);
    final apiKeyFromBackup = _readApiKeyFromBackup(decoded['secure']);

    return ImportPayload(
      settings: settings,
      metabolicProfileHistory: metabolicProfileHistory,
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
      await txn.delete('entries');
      await txn.delete('settings');
      await txn.delete('metabolic_profile_history');

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
        await txn.insert(
          'entry_items',
          {
            'id': item['id'] as int,
            'entry_id': item['entry_id'] as int,
            'name': item['name'] as String,
            'amount': item['amount'] as String,
            'calories': (item['calories'] as num).round(),
            'fat': (item['fat'] as num?)?.toDouble() ?? 0,
            'protein': (item['protein'] as num?)?.toDouble() ?? 0,
            'carbs': (item['carbs'] as num?)?.toDouble() ?? 0,
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
            'created_at': profile['created_at'] as String,
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

    for (final item in payload.entryItems) {
      _requireInt(item, 'id', table: 'entry_items');
      _requireInt(item, 'entry_id', table: 'entry_items');
      _requireString(item, 'name', table: 'entry_items');
      _requireString(item, 'amount', table: 'entry_items');
      _requireNum(item, 'calories', table: 'entry_items');
      _requireOptionalNum(item, 'fat', table: 'entry_items');
      _requireOptionalNum(item, 'protein', table: 'entry_items');
      _requireOptionalNum(item, 'carbs', table: 'entry_items');
      _requireOptionalString(item, 'notes', table: 'entry_items');
    }

    for (final profile in payload.metabolicProfileHistory) {
      _requireOptionalInt(profile, 'id', table: 'metabolic_profile_history');
      _requireString(profile, 'profile_date', table: 'metabolic_profile_history');
      _requireInt(profile, 'age', table: 'metabolic_profile_history');
      _requireString(profile, 'sex', table: 'metabolic_profile_history');
      _requireNum(profile, 'height_cm', table: 'metabolic_profile_history');
      _requireNum(profile, 'weight_kg', table: 'metabolic_profile_history');
      _requireString(profile, 'activity_level', table: 'metabolic_profile_history');
      _requireString(profile, 'created_at', table: 'metabolic_profile_history');
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
