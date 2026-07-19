import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/services/database_service.dart';
import 'package:calorie_tracker/services/entries_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('EntriesRepository bulk actions', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.configureDatabase(db);
      await _createSchema(db);
      await _seedData(db);
    });

    tearDown(() => db.close());

    test('bulk copy inserts every selected item into one target entry',
        () async {
      await EntriesRepository.instance.copyItemsToDateInDatabase(
        db,
        items: [_item(id: 10, foodId: 1), _item(id: 11, foodId: 2)],
        date: DateTime(2026, 2, 2),
      );

      final targetEntry = await _targetEntry(db);
      final copiedRows = await db.query(
        'entry_items',
        where: 'entry_id = ?',
        whereArgs: [targetEntry['id']],
        orderBy: 'id ASC',
      );

      expect(copiedRows, hasLength(2));
      expect(
        copiedRows.map((row) => row['food_id']).toList(),
        [1, 2],
      );
      expect(
        copiedRows.map((row) => row['multiplier']).toList(),
        [150.0, 150.0],
      );
      expect(await _sourceItemIds(db), [10, 11, 12]);
    });

    test('bulk copy rolls back a mid-operation failure and retries cleanly',
        () async {
      await db.execute(
        '''
        CREATE TRIGGER fail_second_bulk_copy
        BEFORE INSERT ON entry_items
        WHEN NEW.entry_id != 1
          AND (
            SELECT COUNT(*)
            FROM entry_items
            WHERE entry_id = NEW.entry_id
          ) >= 1
        BEGIN
          SELECT RAISE(ABORT, 'injected copy failure');
        END
        ''',
      );
      final items = [_item(id: 10, foodId: 1), _item(id: 11, foodId: 2)];

      await expectLater(
        EntriesRepository.instance.copyItemsToDateInDatabase(
          db,
          items: items,
          date: DateTime(2026, 2, 2),
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await db.query('entries'), hasLength(1));
      expect(await _sourceItemIds(db), [10, 11, 12]);

      await db.execute('DROP TRIGGER fail_second_bulk_copy');
      await EntriesRepository.instance.copyItemsToDateInDatabase(
        db,
        items: items,
        date: DateTime(2026, 2, 2),
      );

      final targetEntry = await _targetEntry(db);
      expect(
        await db.query(
          'entry_items',
          where: 'entry_id = ?',
          whereArgs: [targetEntry['id']],
        ),
        hasLength(2),
      );
    });

    test('bulk delete removes every selected item', () async {
      await EntriesRepository.instance.deleteEntryItemsInDatabase(
        db,
        itemIds: [10, 11],
      );

      expect(await _sourceItemIds(db), [12]);
    });

    test('bulk delete rolls back a mid-operation failure', () async {
      await db.execute(
        '''
        CREATE TRIGGER fail_second_bulk_delete
        BEFORE DELETE ON entry_items
        WHEN OLD.id = 11
        BEGIN
          SELECT RAISE(ABORT, 'injected delete failure');
        END
        ''',
      );

      await expectLater(
        EntriesRepository.instance.deleteEntryItemsInDatabase(
          db,
          itemIds: [10, 11],
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _sourceItemIds(db), [10, 11, 12]);
    });
  });
}

FoodItem _item({
  required int id,
  required int foodId,
}) {
  return FoodItem(
    id: id,
    entryId: 1,
    foodId: foodId,
    name: 'Food $foodId',
    amount: '150 g',
    calories: 150,
    fat: 1,
    protein: 2,
    carbs: 3,
    standardUnit: 'g',
    standardUnitAmount: 100,
    multiplier: 150,
    standardCalories: 100,
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
  );
}

Future<Map<String, Object?>> _targetEntry(Database db) async {
  final rows = await db.query(
    'entries',
    where: 'entry_date = ?',
    whereArgs: ['2026-02-02T00:00:00.000'],
  );
  expect(rows, hasLength(1));
  return rows.single;
}

Future<List<int>> _sourceItemIds(Database db) async {
  final rows = await db.query(
    'entry_items',
    columns: ['id'],
    where: 'entry_id = ?',
    whereArgs: [1],
    orderBy: 'id ASC',
  );
  return rows.map((row) => (row['id'] as num).toInt()).toList();
}

Future<void> _seedData(Database db) async {
  for (var id = 1; id <= 3; id++) {
    await db.insert('foods', {
      'id': id,
      'name': 'Food $id',
      'standard_unit': 'g',
      'standard_unit_amount': 100.0,
      'standard_calories': 100.0,
      'standard_fat': 1.0,
      'standard_protein': 2.0,
      'standard_carbs': 3.0,
      'notes': '',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'is_visible_in_library': 1,
    });
  }
  await db.insert('entries', {
    'id': 1,
    'entry_date': '2026-01-01T00:00:00.000',
    'created_at': '2026-01-01T12:00:00.000',
    'prompt': 'Source entry',
    'response': '',
  });
  for (var id = 10; id <= 12; id++) {
    await db.insert('entry_items', {
      'id': id,
      'entry_id': 1,
      'food_id': id - 9,
      'name': '',
      'amount': '',
      'calories': 0,
      'fat': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'standard_amount': '',
      'standard_unit': '',
      'standard_unit_amount': 1.0,
      'multiplier': 150.0,
      'standard_calories': 0.0,
      'standard_fat': 0.0,
      'standard_protein': 0.0,
      'standard_carbs': 0.0,
      'notes': '',
    });
  }
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
}
