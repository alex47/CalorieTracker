import 'dart:convert';

import 'package:calorie_tracker/services/data_transfer_service.dart';
import 'package:calorie_tracker/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/database_test_helper.dart';

void main() {
  sqfliteFfiInit();

  group('DataTransferService import integrity', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.configureDatabase(db);
      await _createSchema(db);
      await _seedExistingData(db);
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    test('valid payload replaces data with intact relationships', () async {
      final summary = await DataTransferService.instance
          .applyImportDataInDatabase(db, _validPayload());

      expect(summary.entriesCount, 1);
      expect(summary.itemsCount, 1);
      expect(await _ids(db, 'foods'), [20]);
      expect(await _ids(db, 'entries'), [10]);
      expect(await _ids(db, 'entry_items'), [30]);
      expect(
        await db.rawQuery(
          '''
          SELECT entry_items.id
          FROM entry_items
          INNER JOIN entries ON entries.id = entry_items.entry_id
          INNER JOIN foods ON foods.id = entry_items.food_id
          ''',
        ),
        hasLength(1),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });

    test('exports, encodes, decodes, and imports a complete round trip',
        () async {
      await db.insert('metabolic_profile_history', {
        'id': 2,
        'profile_date': '2025-01-01',
        'age': 30,
        'sex': 'male',
        'height_cm': 180.0,
        'weight_kg': 75.0,
        'activity_level': 'moderate',
        'macro_preset_key': 'balanced_default',
        'fat_ratio_percent': 30,
        'protein_ratio_percent': 20,
        'carbs_ratio_percent': 50,
        'created_at': '2025-01-01T00:00:00.000',
      });
      await db.insert('day_summary', {
        'summary_date': '2025-01-01',
        'language_code': 'en',
        'model': 'test-model',
        'source_hash': 'source-hash',
        'summary_json':
            '{"summary":"Stored","highlights":[],"issues":[],"suggestions":[]}',
        'created_at': '2025-01-01T00:00:00.000',
        'updated_at': '2025-01-01T00:00:00.000',
      });
      final service = DataTransferService.instance;
      final exported = await service.createExportPayloadInDatabase(
        db,
        includeApiKey: true,
        apiKey: '  test-secret  ',
        exportedAt: DateTime(2026, 7, 19, 12),
      );

      expect(exported['format_version'], 2);
      expect(exported['exported_at'], '2026-07-19T12:00:00.000');
      expect(exported['secure'], {'openai_api_key': 'test-secret'});

      final encoded = service.encodeExportPayload(exported);
      final decoded = service.decodeImportJson(encoded);
      expect(decoded.apiKeyFromBackup, 'test-secret');

      final expectedRows = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'foods',
        'entries',
        'entry_items',
        'settings',
        'metabolic_profile_history',
        'day_summary',
      ]) {
        final orderBy = _exportTableOrder(table);
        expectedRows[table] = await db.query(table, orderBy: orderBy);
      }
      await db.close();

      final target = await openTestDatabase();
      addTearDown(target.close);
      final result = await service.applyImportDataInDatabase(target, decoded);

      expect(result.entriesCount, 1);
      expect(result.itemsCount, 1);
      expect(result.apiKeyFromBackup, 'test-secret');
      for (final table in [
        'foods',
        'entries',
        'entry_items',
        'settings',
        'metabolic_profile_history',
        'day_summary',
      ]) {
        expect(
          await target.query(table, orderBy: _exportTableOrder(table)),
          expectedRows[table],
          reason: table,
        );
      }
      expect(await target.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });

    test('includes a secure key only when explicitly requested and non-empty',
        () async {
      final service = DataTransferService.instance;

      for (final scenario in [
        (include: false, key: 'secret'),
        (include: true, key: null),
        (include: true, key: ''),
        (include: true, key: '   '),
      ]) {
        final payload = await service.createExportPayloadInDatabase(
          db,
          includeApiKey: scenario.include,
          apiKey: scenario.key,
          exportedAt: DateTime(2026),
        );
        expect(payload, isNot(contains('secure')));
      }

      final included = await service.createExportPayloadInDatabase(
        db,
        includeApiKey: true,
        apiKey: '  secret  ',
        exportedAt: DateTime(2026),
      );
      expect(included['secure'], {'openai_api_key': 'secret'});
    });

    test('rejects malformed decoded backup structures', () {
      final service = DataTransferService.instance;

      expect(
        () => service.decodeImportJson('[]'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.decodeImportJson('{"format_version":1}'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Unsupported backup format version'),
          ),
        ),
      );
      expect(
        () => service.decodeImportJson(
          jsonEncode({
            'format_version': 2,
            'settings': [],
            'foods': [],
            'metabolic_profile_history': [],
            'day_summary': [],
            'entries': [],
            'entry_items': [],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.decodeImportJson(
          jsonEncode({
            'format_version': 2,
            'settings': <String, String>{},
            'foods': ['not a row'],
            'metabolic_profile_history': [],
            'day_summary': [],
            'entries': [],
            'entry_items': [],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    for (final scenario in [
      (
        name: 'food field',
        build: () {
          final payload = _validPayload();
          payload.foods.single['name'] = 42;
          return payload;
        },
        field: 'foods.name',
      ),
      (
        name: 'entry field',
        build: () {
          final payload = _validPayload();
          payload.entries.single['prompt'] = false;
          return payload;
        },
        field: 'entries.prompt',
      ),
      (
        name: 'entry-item field',
        build: () {
          final payload = _validPayload();
          payload.entryItems.single['calories'] = '400';
          return payload;
        },
        field: 'entry_items.calories',
      ),
      (
        name: 'profile field',
        build: () {
          final payload = _validPayload();
          payload.metabolicProfileHistory.single['age'] = 30.5;
          return payload;
        },
        field: 'metabolic_profile_history.age',
      ),
      (
        name: 'day-summary field',
        build: () {
          final payload = _validPayload();
          payload.daySummaries.single['summary_json'] = <String, dynamic>{};
          return payload;
        },
        field: 'day_summary.summary_json',
      ),
    ]) {
      test('rejects an invalid ${scenario.name} type without data loss',
          () async {
        await expectLater(
          DataTransferService.instance.applyImportDataInDatabase(
            db,
            scenario.build(),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(scenario.field),
            ),
          ),
        );
        await _expectExistingData(db);
      });
    }

    test('rejects unknown macro presets without changing existing data',
        () async {
      final payload = _validPayload();
      payload.metabolicProfileHistory.single['macro_preset_key'] = 'unknown';

      await expectLater(
        DataTransferService.instance.applyImportDataInDatabase(db, payload),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Invalid macro preset key'),
          ),
        ),
      );
      await _expectExistingData(db);
    });

    for (final scenario in [
      (fat: 30, protein: 30, carbs: 30, message: 'must sum to 100'),
      (fat: -1, protein: 41, carbs: 60, message: 'Invalid macro ratio range'),
    ]) {
      test('rejects invalid custom macro ratios: ${scenario.message}',
          () async {
        final payload = _validPayload();
        final profile = payload.metabolicProfileHistory.single;
        profile['macro_preset_key'] = '';
        profile['fat_ratio_percent'] = scenario.fat;
        profile['protein_ratio_percent'] = scenario.protein;
        profile['carbs_ratio_percent'] = scenario.carbs;

        await expectLater(
          DataTransferService.instance.applyImportDataInDatabase(db, payload),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(scenario.message),
            ),
          ),
        );
        await _expectExistingData(db);
      });
    }

    test('missing entry reference is rejected without changing existing data',
        () async {
      await expectLater(
        DataTransferService.instance.applyImportDataInDatabase(
          db,
          _validPayload(itemEntryId: 999),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('entries.id 999 does not exist'),
          ),
        ),
      );

      await _expectExistingData(db);
    });

    test('missing food reference is rejected without changing existing data',
        () async {
      await expectLater(
        DataTransferService.instance.applyImportDataInDatabase(
          db,
          _validPayload(itemFoodId: 999),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('foods.id 999 does not exist'),
          ),
        ),
      );

      await _expectExistingData(db);
    });

    test('duplicate IDs are rejected without changing existing data', () async {
      final payload = _validPayload();
      final duplicateFood = Map<String, dynamic>.from(payload.foods.single);

      await expectLater(
        DataTransferService.instance.applyImportDataInDatabase(
          db,
          ImportPayload(
            settings: payload.settings,
            foods: [payload.foods.single, duplicateFood],
            metabolicProfileHistory: payload.metabolicProfileHistory,
            daySummaries: payload.daySummaries,
            entries: payload.entries,
            entryItems: payload.entryItems,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Duplicate "foods.id" value 20'),
          ),
        ),
      );

      await _expectExistingData(db);
    });

    for (final table in [
      'entries',
      'entry_items',
      'metabolic_profile_history',
    ]) {
      test('duplicate $table IDs are rejected without changing existing data',
          () async {
        final payload = _validPayload();
        final rows = switch (table) {
          'entries' => payload.entries,
          'entry_items' => payload.entryItems,
          _ => payload.metabolicProfileHistory,
        };
        rows.add(Map<String, dynamic>.from(rows.single));

        await expectLater(
          DataTransferService.instance.applyImportDataInDatabase(db, payload),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('Duplicate "$table.id"'),
            ),
          ),
        );
        await _expectExistingData(db);
      });
    }

    test('duplicate day-summary dates roll back the import transaction',
        () async {
      final payload = _validPayload();
      payload.daySummaries.add(
        Map<String, dynamic>.from(payload.daySummaries.single)
          ..['source_hash'] = 'second',
      );

      await expectLater(
        DataTransferService.instance.applyImportDataInDatabase(db, payload),
        throwsA(isA<DatabaseException>()),
      );
      await _expectExistingData(db);
    });

    test('foreign-key enforcement rejects direct orphan inserts', () async {
      final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
      expect(foreignKeys.single.values.single, 1);

      await expectLater(
        db.insert(
          'entry_items',
          _entryItemRow(id: 99, entryId: 999, foodId: 1),
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _ids(db, 'entry_items'), [1]);
    });

    test('database failure rolls back the complete import transaction',
        () async {
      final payload = _validPayload();
      final duplicateDateProfile = Map<String, dynamic>.from(
        payload.metabolicProfileHistory.single,
      )..['id'] = 41;

      await expectLater(
        DataTransferService.instance.applyImportDataInDatabase(
          db,
          ImportPayload(
            settings: payload.settings,
            foods: payload.foods,
            metabolicProfileHistory: [
              payload.metabolicProfileHistory.single,
              duplicateDateProfile,
            ],
            daySummaries: payload.daySummaries,
            entries: payload.entries,
            entryItems: payload.entryItems,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      await _expectExistingData(db);
    });
  });
}

ImportPayload _validPayload({
  int itemEntryId = 10,
  int itemFoodId = 20,
}) {
  return ImportPayload(
    settings: const {'marker': 'imported'},
    foods: [
      {
        'id': 20,
        'name': 'Imported food',
        'standard_unit': 'g',
        'standard_unit_amount': 100.0,
        'standard_calories': 200.0,
        'standard_fat': 10.0,
        'standard_protein': 20.0,
        'standard_carbs': 30.0,
        'notes': '',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
        'is_visible_in_library': 1,
      },
    ],
    entries: [
      {
        'id': 10,
        'entry_date': '2026-01-01T00:00:00.000',
        'created_at': '2026-01-01T12:00:00.000',
        'prompt': 'Imported entry',
        'response': '',
      },
    ],
    entryItems: [
      _entryItemRow(
        id: 30,
        entryId: itemEntryId,
        foodId: itemFoodId,
      ),
    ],
    metabolicProfileHistory: [
      {
        'id': 40,
        'profile_date': '2026-01-01',
        'age': 30,
        'sex': 'male',
        'height_cm': 180.0,
        'weight_kg': 75.0,
        'activity_level': 'moderate',
        'macro_preset_key': 'balanced_default',
        'fat_ratio_percent': 30,
        'protein_ratio_percent': 20,
        'carbs_ratio_percent': 50,
        'created_at': '2026-01-01T00:00:00.000',
      },
    ],
    daySummaries: [
      {
        'summary_date': '2026-01-01',
        'language_code': 'en',
        'model': 'test-model',
        'source_hash': 'hash',
        'summary_json': '{}',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      },
    ],
  );
}

String _exportTableOrder(String table) {
  return switch (table) {
    'settings' => 'key ASC',
    'day_summary' => 'summary_date ASC',
    'metabolic_profile_history' => 'profile_date ASC',
    _ => 'id ASC',
  };
}

Map<String, dynamic> _entryItemRow({
  required int id,
  required int entryId,
  required int foodId,
}) {
  return {
    'id': id,
    'entry_id': entryId,
    'food_id': foodId,
    'name': 'Food item',
    'amount': '200 g',
    'calories': 400,
    'fat': 20.0,
    'protein': 40.0,
    'carbs': 60.0,
    'standard_amount': '100 g',
    'standard_unit': 'g',
    'standard_unit_amount': 100.0,
    'multiplier': 200.0,
    'standard_calories': 200.0,
    'standard_fat': 10.0,
    'standard_protein': 20.0,
    'standard_carbs': 30.0,
    'notes': '',
  };
}

Future<void> _expectExistingData(Database db) async {
  expect(await _ids(db, 'foods'), [1]);
  expect(await _ids(db, 'entries'), [1]);
  expect(await _ids(db, 'entry_items'), [1]);
  expect(
    await db.query(
      'settings',
      where: 'key = ? AND value = ?',
      whereArgs: ['marker', 'existing'],
    ),
    hasLength(1),
  );
  expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
}

Future<List<int>> _ids(Database db, String table) async {
  final rows = await db.query(table, columns: ['id'], orderBy: 'id ASC');
  return rows.map((row) => (row['id'] as num).toInt()).toList();
}

Future<void> _seedExistingData(Database db) async {
  await db.insert('foods', {
    'id': 1,
    'name': 'Existing food',
    'standard_unit': 'g',
    'standard_unit_amount': 100.0,
    'standard_calories': 100.0,
    'standard_fat': 1.0,
    'standard_protein': 2.0,
    'standard_carbs': 3.0,
    'notes': '',
    'created_at': '2025-01-01T00:00:00.000',
    'updated_at': '2025-01-01T00:00:00.000',
    'is_visible_in_library': 1,
  });
  await db.insert('entries', {
    'id': 1,
    'entry_date': '2025-01-01T00:00:00.000',
    'created_at': '2025-01-01T12:00:00.000',
    'prompt': 'Existing entry',
    'response': '',
  });
  await db.insert(
    'entry_items',
    _entryItemRow(id: 1, entryId: 1, foodId: 1),
  );
  await db.insert('settings', {'key': 'marker', 'value': 'existing'});
}

Future<void> _createSchema(Database db) async {
  await db.execute(
    '''
    CREATE TABLE foods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      standard_unit TEXT NOT NULL,
      standard_unit_amount REAL NOT NULL,
      standard_calories REAL NOT NULL,
      standard_fat REAL NOT NULL,
      standard_protein REAL NOT NULL,
      standard_carbs REAL NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      is_visible_in_library INTEGER NOT NULL
    )
    ''',
  );
  await db.execute(
    '''
    CREATE TABLE entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entry_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      prompt TEXT NOT NULL,
      response TEXT NOT NULL
    )
    ''',
  );
  await db.execute(
    '''
    CREATE TABLE entry_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entry_id INTEGER NOT NULL,
      food_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      amount TEXT NOT NULL,
      calories INTEGER NOT NULL,
      fat REAL NOT NULL,
      protein REAL NOT NULL,
      carbs REAL NOT NULL,
      standard_amount TEXT NOT NULL,
      standard_unit TEXT NOT NULL,
      standard_unit_amount REAL NOT NULL,
      multiplier REAL NOT NULL,
      standard_calories REAL NOT NULL,
      standard_fat REAL NOT NULL,
      standard_protein REAL NOT NULL,
      standard_carbs REAL NOT NULL,
      notes TEXT,
      FOREIGN KEY(entry_id) REFERENCES entries(id),
      FOREIGN KEY(food_id) REFERENCES foods(id)
    )
    ''',
  );
  await db.execute(
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  );
  await db.execute(
    '''
    CREATE TABLE metabolic_profile_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_date TEXT NOT NULL UNIQUE,
      age INTEGER NOT NULL,
      sex TEXT NOT NULL,
      height_cm REAL NOT NULL,
      weight_kg REAL NOT NULL,
      activity_level TEXT NOT NULL,
      macro_preset_key TEXT NOT NULL,
      fat_ratio_percent INTEGER NOT NULL,
      protein_ratio_percent INTEGER NOT NULL,
      carbs_ratio_percent INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
  );
  await db.execute(
    '''
    CREATE TABLE day_summary (
      summary_date TEXT PRIMARY KEY,
      language_code TEXT NOT NULL,
      model TEXT NOT NULL,
      source_hash TEXT NOT NULL,
      summary_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
  );
}
