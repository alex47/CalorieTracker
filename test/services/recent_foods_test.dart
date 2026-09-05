import 'package:calorie_tracker/services/entries_repository.dart';
import 'package:calorie_tracker/services/food_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/database_test_helper.dart';

void main() {
  final library = FoodLibraryService.instance;
  final repository = EntriesRepository.instance;
  late Database db;
  late List<int> foodIds;

  setUp(() async {
    db = await openTestDatabase();
    foodIds = [];
    for (var i = 1; i <= 6; i++) {
      foodIds.add(await library.createFoodInDatabase(
        db,
        name: 'Food $i',
        standardUnit: 'g',
        standardUnitAmount: 100,
        standardCalories: 200,
        standardFat: 1,
        standardProtein: 2,
        standardCarbs: 3,
        notes: '',
      ));
    }
  });
  tearDown(() => db.close());

  Future<void> add(int foodId, DateTime date) =>
      repository.addFoodToDateInDatabase(
        db,
        date: date,
        foodId: foodId,
        multiplier: 100,
        recordRecentAddition: true,
      );

  Future<List<int>> recentIds() async =>
      (await library.fetchRecentFoodsInDatabase(db))
          .map((food) => food.id)
          .toList();

  test('creation, untracked adds, and copies do not enter recent history',
      () async {
    expect(await recentIds(), isEmpty);
    await repository.addFoodToDateInDatabase(
      db,
      date: DateTime(2026, 7, 19),
      foodId: foodIds.first,
      multiplier: 250,
    );
    final items = await repository.fetchItemsForDateInDatabase(
      db,
      DateTime(2026, 7, 19),
    );
    await repository.copyItemsToDateInDatabase(
      db,
      items: items,
      date: DateTime(2026, 7, 20),
    );
    expect(await recentIds(), isEmpty);
  });

  test('keeps the newest five distinct foods in addition order across dates',
      () async {
    for (var i = 0; i < foodIds.length; i++) {
      await add(foodIds[i], DateTime(2026, 7, 20 - i));
    }
    expect(await recentIds(), foodIds.reversed.take(5));
    // Adding into an existing row moves the food to the top and keeps one row.
    await add(foodIds[1], DateTime(2026, 7, 19));
    expect(await recentIds(), [foodIds[1], ...foodIds.reversed.take(4)]);
    final items = await repository.fetchItemsForDateInDatabase(
      db,
      DateTime(2026, 7, 19),
    );
    expect(items, hasLength(1));
    expect(items.single.multiplier, 200);
    // Copying an already-recent food must not reorder the list either.
    final before = await recentIds();
    final copied = await repository.fetchItemsForDateInDatabase(
      db,
      DateTime(2026, 7, 15),
    );
    await repository.copyItemsToDateInDatabase(
      db,
      items: copied,
      date: DateTime(2026, 7, 19),
    );
    expect(await recentIds(), before);
  });

  test('history and the logged quantity roll back together on failure',
      () async {
    final date = DateTime(2026, 7, 20);
    await add(foodIds[0], date);
    await add(foodIds[1], date);
    final before = await recentIds();
    await db.execute('''
      CREATE TRIGGER fail_recent_update BEFORE UPDATE OF last_added_sequence
      ON foods BEGIN SELECT RAISE(ABORT, 'injected history failure'); END
    ''');
    await expectLater(add(foodIds[0], date), throwsA(isA<DatabaseException>()));
    await expectLater(add(foodIds[2], date), throwsA(isA<DatabaseException>()));
    expect(await recentIds(), before);
    final items = await repository.fetchItemsForDateInDatabase(db, date);
    expect(items, hasLength(2));
    expect(items.map((item) => item.multiplier), everyElement(100));
    await db.execute('DROP TRIGGER fail_recent_update');
    await add(foodIds[0], date);
    expect(await recentIds(), before.reversed);
  });

  test('recent foods use live definitions and exclude hidden or merged foods',
      () async {
    final date = DateTime(2026, 7, 20);
    await add(foodIds[0], date);
    await add(foodIds[1], date);
    await db.update(
      'foods',
      {'name': 'Updated', 'standard_unit_amount': 50},
      where: 'id = ?',
      whereArgs: [foodIds[1]],
    );
    final recent = await library.fetchRecentFoodsInDatabase(db);
    expect(recent.first.name, 'Updated');
    expect(recent.first.standardUnitAmount, 50);
    expect(recent.first.usageCount, 1);
    await db.update(
      'foods',
      {'is_visible_in_library': 0},
      where: 'id = ?',
      whereArgs: [foodIds[1]],
    );
    expect(await recentIds(), [foodIds[0]]);
    await library.mergeFoodsInDatabase(
      db,
      targetFoodId: foodIds[2],
      sources: [FoodMergeSource(sourceFoodId: foodIds[0], conversionFactor: 1)],
    );
    expect(await recentIds(), isEmpty);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
