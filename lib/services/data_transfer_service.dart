import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class ImportSummary {
  const ImportSummary({
    required this.entriesCount,
    required this.itemsCount,
  });

  final int entriesCount;
  final int itemsCount;
}

class DataTransferService {
  DataTransferService._();

  static final DataTransferService instance = DataTransferService._();

  static const int _formatVersion = 1;

  Future<String?> exportData() async {
    final db = await DatabaseService.instance.database;
    final entries = await db.query('entries');
    final entryItems = await db.query('entry_items');
    final settingsRows = await db.query('settings');
    final settings = {
      for (final row in settingsRows) row['key'] as String: row['value'] as String,
    };

    final payload = {
      'format_version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'entries': entries,
      'entry_items': entryItems,
    };

    final fileName = _exportFileName();
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
    );
    String? targetPath;
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [jsonTypeGroup],
    );
    if (location == null) {
      return null;
    }
    targetPath = location.path;

    final file = File(targetPath!);
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(encoded);
    return targetPath;
  }

  Future<ImportSummary?> importData() async {
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
    );
    XFile? file;
    file = await openFile(acceptedTypeGroups: [jsonTypeGroup]);
    if (file == null) {
      return null;
    }

    final rawJson = await file.readAsString();
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format.');
    }
    if (decoded['format_version'] is! int || decoded['format_version'] != _formatVersion) {
      throw const FormatException('Unsupported backup format version.');
    }

    final settings = _readSettings(decoded['settings']);
    final entries = _readRows(decoded['entries']);
    final entryItems = _readRows(decoded['entry_items']);

    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await txn.delete('entry_items');
      await txn.delete('entries');
      await txn.delete('settings');

      for (final entry in entries) {
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

      for (final item in entryItems) {
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

      for (final setting in settings.entries) {
        await txn.insert(
          'settings',
          {'key': setting.key, 'value': setting.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return ImportSummary(
      entriesCount: entries.length,
      itemsCount: entryItems.length,
    );
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

  String _exportFileName() {
    return 'calorie_tracker_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
  }
}
