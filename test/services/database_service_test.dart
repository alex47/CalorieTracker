import 'dart:io';

import 'package:calorie_tracker/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('DatabaseService schema lifecycle', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'calorie_tracker_database_test_',
      );
    });

    tearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    test('creates the complete current schema', () async {
      final db = await _openDatabase(
        path.join(tempDirectory.path, 'fresh.db'),
        version: DatabaseService.schemaVersion,
        onCreate: DatabaseService.createSchema,
      );

      try {
        expect(await db.getVersion(), DatabaseService.schemaVersion);

        final tables = await _objectNames(db, type: 'table');
        expect(
          tables,
          containsAll(<String>[
            'foods',
            'entries',
            'entry_items',
            'settings',
            'metabolic_profile_history',
            'day_summary',
          ]),
        );

        final entryItemColumns = await _columnNames(db, 'entry_items');
        expect(
          entryItemColumns,
          containsAll(<String>[
            'food_id',
            'standard_unit',
            'standard_unit_amount',
            'multiplier',
            'standard_calories',
            'standard_fat',
            'standard_protein',
            'standard_carbs',
          ]),
        );

        final foreignKeys = await db.rawQuery(
          'PRAGMA foreign_key_list(entry_items)',
        );
        expect(
          foreignKeys.map((row) => row['table']),
          containsAll(<Object?>['entries', 'foods']),
        );
        expect(
          await _objectNames(db, type: 'index'),
          contains('idx_entry_items_food_id'),
        );
      } finally {
        await db.close();
      }
    });

    test('migrates version 10 items to deduplicated version 11 foods',
        () async {
      final databasePath = path.join(tempDirectory.path, 'migration.db');
      var db = await _openDatabase(
        databasePath,
        version: 10,
        onCreate: _createVersion10Schema,
      );
      try {
        await _seedVersion10Data(db);
      } finally {
        await db.close();
      }

      db = await _openDatabase(
        databasePath,
        version: DatabaseService.schemaVersion,
        onUpgrade: DatabaseService.upgradeSchema,
      );
      try {
        expect(await db.getVersion(), DatabaseService.schemaVersion);

        final items = await db.query('entry_items', orderBy: 'id ASC');
        expect(items, hasLength(3));
        expect(items[0]['food_id'], isNotNull);
        expect(items[1]['food_id'], items[0]['food_id']);
        expect(items[2]['food_id'], isNot(items[0]['food_id']));
        expect(items[0]['amount'], '150 g');
        expect(items[0]['multiplier'], 1.5);

        final foods = await db.query('foods', orderBy: 'id ASC');
        expect(foods, hasLength(2));
        expect(foods[0]['name'], ' Oatmeal ');
        expect(foods[0]['standard_unit'], 'g');
        expect(foods[0]['standard_unit_amount'], 100.0);
        expect(foods[0]['standard_calories'], 380.0);
        expect(foods[0]['notes'], 'Breakfast');
        expect(foods[1]['name'], 'Banana');

        expect(
          await _objectNames(db, type: 'index'),
          contains('idx_entry_items_food_id'),
        );
      } finally {
        await db.close();
      }
    });
  });
}

Future<Database> _openDatabase(
  String databasePath, {
  required int version,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
}) {
  return databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: DatabaseService.configureDatabase,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );
}

Future<Set<String>> _objectNames(
  Database db, {
  required String type,
}) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ?',
    whereArgs: [type],
  );
  return rows.map((row) => row['name']! as String).toSet();
}

Future<Set<String>> _columnNames(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((row) => row['name']! as String).toSet();
}

Future<void> _createVersion10Schema(Database db, int version) async {
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
      name TEXT NOT NULL,
      amount TEXT NOT NULL,
      calories INTEGER NOT NULL,
      fat REAL NOT NULL DEFAULT 0,
      protein REAL NOT NULL DEFAULT 0,
      carbs REAL NOT NULL DEFAULT 0,
      standard_amount TEXT NOT NULL,
      standard_unit TEXT NOT NULL DEFAULT '',
      standard_unit_amount REAL NOT NULL DEFAULT 1.0,
      multiplier REAL NOT NULL DEFAULT 1.0,
      standard_calories REAL NOT NULL DEFAULT 0,
      standard_fat REAL NOT NULL DEFAULT 0,
      standard_protein REAL NOT NULL DEFAULT 0,
      standard_carbs REAL NOT NULL DEFAULT 0,
      notes TEXT,
      FOREIGN KEY(entry_id) REFERENCES entries(id)
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
      macro_preset_key TEXT NOT NULL DEFAULT 'balanced_default',
      fat_ratio_percent INTEGER NOT NULL DEFAULT 30,
      protein_ratio_percent INTEGER NOT NULL DEFAULT 30,
      carbs_ratio_percent INTEGER NOT NULL DEFAULT 40,
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

Future<void> _seedVersion10Data(Database db) async {
  await db.insert('entries', <String, Object?>{
    'id': 1,
    'entry_date': '2026-01-01T00:00:00.000',
    'created_at': '2026-01-01T12:00:00.000',
    'prompt': 'Version 10 entry',
    'response': '',
  });

  await db.insert(
    'entry_items',
    _version10Item(
      id: 101,
      name: ' Oatmeal ',
      notes: 'Breakfast',
    ),
  );
  await db.insert(
    'entry_items',
    _version10Item(
      id: 102,
      name: 'oatmeal',
      standardUnit: 'g',
      notes: 'Breakfast ',
    ),
  );
  await db.insert(
    'entry_items',
    _version10Item(
      id: 103,
      name: 'Banana',
      standardUnit: 'piece',
      standardUnitAmount: 1,
      standardCalories: 105,
      notes: '',
    ),
  );
}

Map<String, Object?> _version10Item({
  required int id,
  required String name,
  String standardUnit = ' g ',
  double standardUnitAmount = 100,
  double standardCalories = 380,
  required String notes,
}) {
  return <String, Object?>{
    'id': id,
    'entry_id': 1,
    'name': name,
    'amount': '150 g',
    'calories': 570,
    'fat': 10.5,
    'protein': 19.5,
    'carbs': 101.4,
    'standard_amount': '100 g',
    'standard_unit': standardUnit,
    'standard_unit_amount': standardUnitAmount,
    'multiplier': 1.5,
    'standard_calories': standardCalories,
    'standard_fat': 7.0,
    'standard_protein': 13.0,
    'standard_carbs': 67.6,
    'notes': notes,
  };
}
