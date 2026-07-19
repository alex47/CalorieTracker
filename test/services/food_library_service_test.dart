import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/services/entries_repository.dart';
import 'package:calorie_tracker/services/food_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/database_test_helper.dart';

void main() {
  sqfliteFfiInit();

  group('FoodLibraryService CRUD and lookup', () {
    late Database db;

    setUp(() async {
      db = await openTestDatabase();
    });

    tearDown(() => db.close());

    test('creates, sorts, searches, and filters foods by visibility', () async {
      final service = FoodLibraryService.instance;
      final hiddenAppleId = await _createFullFood(
        db,
        name: 'Apple',
        visible: false,
      );
      final bananaId = await _createFullFood(db, name: 'banana');
      await _createFullFood(db, name: 'Apple pie');

      final visible = await service.fetchFoodsInDatabase(db);
      expect(visible.map((food) => food.name), ['Apple pie', 'banana']);

      final all = await service.fetchFoodsInDatabase(db, visibleOnly: false);
      expect(all.map((food) => food.name), ['Apple', 'Apple pie', 'banana']);

      final search = await service.fetchFoodsInDatabase(
        db,
        searchQuery: ' APP ',
        visibleOnly: false,
      );
      expect(search.map((food) => food.name), ['Apple', 'Apple pie']);

      expect(
        await service.fetchFoodsInDatabase(db, searchQuery: 'pear'),
        isEmpty,
      );
      expect(
        (await service.fetchFoodByIdInDatabase(db, hiddenAppleId))?.name,
        'Apple',
      );
      expect(await service.fetchFoodByIdInDatabase(db, 9999), isNull);

      await EntriesRepository.instance.addFoodToDateInDatabase(
        db,
        date: DateTime(2026, 7, 18),
        foodId: bananaId,
        multiplier: 100,
      );
      await EntriesRepository.instance.addFoodToDateInDatabase(
        db,
        date: DateTime(2026, 7, 19),
        foodId: bananaId,
        multiplier: 100,
      );
      expect(
        (await service.fetchFoodByIdInDatabase(db, bananaId))?.usageCount,
        2,
      );
    });

    test('updates all editable fields while retaining food identity', () async {
      final service = FoodLibraryService.instance;
      final foodId = await _createFullFood(db, name: 'Original');

      await service.updateFoodInDatabase(
        db,
        foodId: foodId,
        name: 'Updated',
        standardUnit: 'piece',
        standardUnitAmount: 2,
        standardCalories: 300,
        standardFat: 4,
        standardProtein: 5,
        standardCarbs: 6,
        notes: 'Changed',
        isVisibleInLibrary: false,
      );

      final food = await service.fetchFoodByIdInDatabase(db, foodId);
      expect(food, isNotNull);
      expect(food!.id, foodId);
      expect(food.name, 'Updated');
      expect(food.standardUnit, 'piece');
      expect(food.standardUnitAmount, 2);
      expect(food.standardCalories, 300);
      expect(food.standardFat, 4);
      expect(food.standardProtein, 5);
      expect(food.standardCarbs, 6);
      expect(food.notes, 'Changed');
      expect(food.isVisibleInLibrary, isFalse);
      expect(food.createdAtIso, isNotEmpty);
      expect(food.updatedAtIso, isNotEmpty);
    });

    test('deduplicates normalized definitions and restores visibility',
        () async {
      final service = FoodLibraryService.instance;
      final originalId = await service.createFoodInDatabase(
        db,
        name: ' Apple ',
        standardUnit: ' G ',
        standardUnitAmount: 100,
        standardCalories: 52,
        standardFat: 0.2,
        standardProtein: 0.3,
        standardCarbs: 14,
        notes: ' fresh ',
        isVisibleInLibrary: false,
      );

      final ensuredId = await service.ensureFoodInDatabase(
        db,
        name: 'apple',
        standardUnit: 'g',
        standardUnitAmount: 100,
        standardCalories: 52,
        standardFat: 0.2,
        standardProtein: 0.3,
        standardCarbs: 14,
        notes: 'fresh',
      );

      expect(ensuredId, originalId);
      expect(await db.query('foods'), hasLength(1));
      expect(
        (await service.fetchFoodByIdInDatabase(db, originalId))
            ?.isVisibleInLibrary,
        isTrue,
      );

      final distinctId = await service.ensureFoodInDatabase(
        db,
        name: 'apple',
        standardUnit: 'g',
        standardUnitAmount: 100,
        standardCalories: 53,
        standardFat: 0.2,
        standardProtein: 0.3,
        standardCarbs: 14,
        notes: 'fresh',
      );
      expect(distinctId, isNot(originalId));
      expect(await db.query('foods'), hasLength(2));
    });
  });

  group('FoodLibraryService merge conversion', () {
    test('same units use factor 1 regardless of reference amounts', () {
      final factor = FoodLibraryService.defaultQuantityConversionFactor(
        sourceUnit: ' G ',
        targetUnit: 'g',
      );

      expect(factor, 1.0);
    });

    test('different units require a manual factor', () {
      final factor = FoodLibraryService.defaultQuantityConversionFactor(
        sourceUnit: 'kg',
        targetUnit: 'g',
      );

      expect(factor, isNull);
    });

    for (final scenario in [
      (
        name: '100 g into 1 g',
        sourceUnitAmount: 100.0,
        sourceCalories: 200.0,
        targetUnitAmount: 1.0,
        targetCalories: 2.0,
      ),
      (
        name: '1 g into 100 g',
        sourceUnitAmount: 1.0,
        sourceCalories: 2.0,
        targetUnitAmount: 100.0,
        targetCalories: 200.0,
      ),
    ]) {
      test('${scenario.name} preserves quantity and nutrition totals',
          () async {
        final db = await _openMergeDatabase();
        addTearDown(db.close);
        await _insertFood(
          db,
          id: 1,
          unit: 'g',
          unitAmount: scenario.targetUnitAmount,
          calories: scenario.targetCalories,
        );
        await _insertFood(
          db,
          id: 2,
          unit: 'g',
          unitAmount: scenario.sourceUnitAmount,
          calories: scenario.sourceCalories,
        );
        await _insertEntryItem(db, foodId: 2, multiplier: 200);

        final caloriesBefore = FoodItem.computeCalories(
          standardCalories: scenario.sourceCalories,
          multiplier: 200,
          standardUnitAmount: scenario.sourceUnitAmount,
        );

        await FoodLibraryService.instance.mergeFoodsInDatabase(
          db,
          targetFoodId: 1,
          sources: const [
            FoodMergeSource(sourceFoodId: 2, conversionFactor: 1),
          ],
        );

        final merged = (await db.rawQuery(
          '''
          SELECT
            entry_items.food_id,
            entry_items.multiplier,
            foods.standard_unit_amount,
            foods.standard_calories
          FROM entry_items
          INNER JOIN foods ON foods.id = entry_items.food_id
          ''',
        ))
            .single;
        final caloriesAfter = FoodItem.computeCalories(
          standardCalories: (merged['standard_calories'] as num).toDouble(),
          multiplier: (merged['multiplier'] as num).toDouble(),
          standardUnitAmount:
              (merged['standard_unit_amount'] as num).toDouble(),
        );

        expect(merged['food_id'], 1);
        expect(merged['multiplier'], 200);
        expect(caloriesAfter, caloriesBefore);
        expect(
          await db.query('foods', where: 'id = ?', whereArgs: [2]),
          isEmpty,
        );
      });
    }

    for (final scenario in [
      (
        name: 'kg to g',
        sourceUnit: 'kg',
        sourceCalories: 2000.0,
        sourceMultiplier: 0.25,
        targetUnit: 'g',
        targetUnitAmount: 100.0,
        targetCalories: 200.0,
        factor: 1000.0,
        expectedMultiplier: 250.0,
      ),
      (
        name: 'l to ml',
        sourceUnit: 'l',
        sourceCalories: 600.0,
        sourceMultiplier: 0.5,
        targetUnit: 'ml',
        targetUnitAmount: 100.0,
        targetCalories: 60.0,
        factor: 1000.0,
        expectedMultiplier: 500.0,
      ),
    ]) {
      test('manual ${scenario.name} factor preserves nutrition totals',
          () async {
        final db = await _openMergeDatabase();
        addTearDown(db.close);
        await _insertFood(
          db,
          id: 1,
          unit: scenario.targetUnit,
          unitAmount: scenario.targetUnitAmount,
          calories: scenario.targetCalories,
        );
        await _insertFood(
          db,
          id: 2,
          unit: scenario.sourceUnit,
          unitAmount: 1,
          calories: scenario.sourceCalories,
        );
        await _insertEntryItem(
          db,
          foodId: 2,
          multiplier: scenario.sourceMultiplier,
        );

        final caloriesBefore = FoodItem.computeCalories(
          standardCalories: scenario.sourceCalories,
          multiplier: scenario.sourceMultiplier,
          standardUnitAmount: 1,
        );

        await FoodLibraryService.instance.mergeFoodsInDatabase(
          db,
          targetFoodId: 1,
          sources: [
            FoodMergeSource(
              sourceFoodId: 2,
              conversionFactor: scenario.factor,
            ),
          ],
        );

        final merged = (await db.rawQuery(
          '''
          SELECT
            entry_items.food_id,
            entry_items.multiplier,
            foods.standard_unit_amount,
            foods.standard_calories
          FROM entry_items
          INNER JOIN foods ON foods.id = entry_items.food_id
          ''',
        ))
            .single;
        final caloriesAfter = FoodItem.computeCalories(
          standardCalories: (merged['standard_calories'] as num).toDouble(),
          multiplier: (merged['multiplier'] as num).toDouble(),
          standardUnitAmount:
              (merged['standard_unit_amount'] as num).toDouble(),
        );

        expect(merged['food_id'], 1);
        expect(merged['multiplier'], scenario.expectedMultiplier);
        expect(caloriesAfter, caloriesBefore);
      });
    }
  });
}

Future<int> _createFullFood(
  DatabaseExecutor db, {
  required String name,
  bool visible = true,
}) {
  return FoodLibraryService.instance.createFoodInDatabase(
    db,
    name: name,
    standardUnit: 'g',
    standardUnitAmount: 100,
    standardCalories: 100,
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
    isVisibleInLibrary: visible,
  );
}

Future<Database> _openMergeDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(
    '''
    CREATE TABLE foods (
      id INTEGER PRIMARY KEY,
      standard_unit TEXT NOT NULL,
      standard_unit_amount REAL NOT NULL,
      standard_calories REAL NOT NULL
    )
    ''',
  );
  await db.execute(
    '''
    CREATE TABLE entry_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      food_id INTEGER NOT NULL,
      multiplier REAL NOT NULL
    )
    ''',
  );
  return db;
}

Future<void> _insertFood(
  Database db, {
  required int id,
  required String unit,
  required double unitAmount,
  required double calories,
}) {
  return db.insert('foods', {
    'id': id,
    'standard_unit': unit,
    'standard_unit_amount': unitAmount,
    'standard_calories': calories,
  });
}

Future<void> _insertEntryItem(
  Database db, {
  required int foodId,
  required double multiplier,
}) {
  return db.insert('entry_items', {
    'food_id': foodId,
    'multiplier': multiplier,
  });
}
