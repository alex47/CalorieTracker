import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/services/entries_repository.dart';
import 'package:calorie_tracker/services/food_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/database_test_helper.dart';

void main() {
  sqfliteFfiInit();

  group('EntriesRepository database behavior', () {
    late Database db;

    setUp(() async {
      db = await openTestDatabase();
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

    test('food definition edits recalculate linked historical entries',
        () async {
      final before = await EntriesRepository.instance
          .fetchItemsForDateInDatabase(db, DateTime(2026, 1, 1));
      final original = before.singleWhere((item) => item.foodId == 1);
      expect(original.name, 'Food 1');
      expect(original.calories, 150);
      expect(original.fat, 1.5);
      expect(original.protein, 3);
      expect(original.carbs, 4.5);

      await FoodLibraryService.instance.updateFoodInDatabase(
        db,
        foodId: 1,
        name: 'Updated Food 1',
        standardUnit: 'g',
        standardUnitAmount: 100,
        standardCalories: 200,
        standardFat: 4,
        standardProtein: 8,
        standardCarbs: 12,
        notes: 'Updated definition',
        isVisibleInLibrary: true,
      );

      final after = await EntriesRepository.instance
          .fetchItemsForDateInDatabase(db, DateTime(2026, 1, 1));
      final updated = after.singleWhere((item) => item.foodId == 1);
      expect(updated.name, 'Updated Food 1');
      expect(updated.multiplier, 150);
      expect(updated.calories, 300);
      expect(updated.fat, 6);
      expect(updated.protein, 12);
      expect(updated.carbs, 18);
      expect(updated.notes, 'Updated definition');
    });

    test('single adds reuse one library entry and normalize multipliers',
        () async {
      final repository = EntriesRepository.instance;
      final targetDate = DateTime(2026, 2, 2, 23);

      await repository.addFoodToDateInDatabase(
        db,
        date: targetDate,
        foodId: 1,
        multiplier: 200,
      );
      await repository.addFoodToDateInDatabase(
        db,
        date: targetDate,
        foodId: 2,
        multiplier: 0,
      );

      final targetEntries = await db.query(
        'entries',
        where: 'entry_date = ?',
        whereArgs: ['2026-02-02T00:00:00.000'],
      );
      expect(targetEntries, hasLength(1));
      expect(targetEntries.single['prompt'], 'Food library add');

      final items = await repository.fetchItemsForDateInDatabase(
        db,
        DateTime(2026, 2, 2),
      );
      expect(items.map((item) => item.foodId), [2, 1]);
      expect(items.map((item) => item.multiplier), [1, 200]);
    });

    test('fetches only the requested date in newest-first order', () async {
      final repository = EntriesRepository.instance;
      final sourceItems = await repository.fetchItemsForDateInDatabase(
        db,
        DateTime(2026, 1, 1, 23, 59),
      );
      expect(sourceItems.map((item) => item.id), [12, 11, 10]);

      await repository.addFoodToDateInDatabase(
        db,
        date: DateTime(2026, 1, 2),
        foodId: 1,
        multiplier: 50,
      );
      final nextDay = await repository.fetchItemsForDateInDatabase(
        db,
        DateTime(2026, 1, 2),
      );
      expect(nextDay, hasLength(1));
      expect(nextDay.single.foodId, 1);
      expect(nextDay.single.calories, 50);

      expect(
        await repository.fetchItemsForDateInDatabase(
          db,
          DateTime(2025, 12, 31),
        ),
        isEmpty,
      );
    });

    test('updates one multiplier and rejects an unknown item', () async {
      final repository = EntriesRepository.instance;

      await repository.updateEntryItemMultiplierInDatabase(
        db,
        itemId: 10,
        multiplier: 250,
      );
      var item = (await repository.fetchItemsForDateInDatabase(
        db,
        DateTime(2026, 1, 1),
      ))
          .singleWhere((candidate) => candidate.id == 10);
      expect(item.multiplier, 250);
      expect(item.calories, 250);

      await repository.updateEntryItemMultiplierInDatabase(
        db,
        itemId: 10,
        multiplier: -5,
      );
      item = (await repository.fetchItemsForDateInDatabase(
        db,
        DateTime(2026, 1, 1),
      ))
          .singleWhere((candidate) => candidate.id == 10);
      expect(item.multiplier, 1);

      await expectLater(
        repository.updateEntryItemMultiplierInDatabase(
          db,
          itemId: 999,
          multiplier: 1,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('single delete removes exactly one item and rejects a repeat',
        () async {
      final repository = EntriesRepository.instance;

      await repository.deleteEntryItemInDatabase(db, 11);
      expect(await _sourceItemIds(db), [10, 12]);

      await expectLater(
        repository.deleteEntryItemInDatabase(db, 11),
        throwsA(isA<StateError>()),
      );
      expect(await _sourceItemIds(db), [10, 12]);
    });

    test('single copy retains the food and multiplier and reuses target entry',
        () async {
      final repository = EntriesRepository.instance;
      final source = _item(id: 10, foodId: 1);

      await repository.copyItemToDateInDatabase(
        db,
        item: source,
        date: DateTime(2026, 2, 2),
      );
      await repository.copyItemToDateInDatabase(
        db,
        item: _item(id: 11, foodId: 2),
        date: DateTime(2026, 2, 2),
      );

      final entries = await db.query(
        'entries',
        where: 'entry_date = ?',
        whereArgs: ['2026-02-02T00:00:00.000'],
      );
      expect(entries, hasLength(1));
      final copied = await repository.fetchItemsForDateInDatabase(
        db,
        DateTime(2026, 2, 2),
      );
      expect(copied.map((item) => item.foodId), [2, 1]);
      expect(copied.map((item) => item.multiplier), [150, 150]);
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
