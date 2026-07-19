import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/services/food_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

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
