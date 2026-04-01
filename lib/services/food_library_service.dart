import 'package:sqflite/sqflite.dart';

import '../models/food_definition.dart';
import 'database_service.dart';

class FoodMergeSource {
  const FoodMergeSource({
    required this.sourceFoodId,
    required this.conversionFactor,
  });

  final int sourceFoodId;
  final double conversionFactor;
}

class FoodLibraryService {
  FoodLibraryService._();

  static final FoodLibraryService instance = FoodLibraryService._();

  String _signature({
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
  }) {
    return [
      name.trim().toLowerCase(),
      standardUnit.trim().toLowerCase(),
      standardUnitAmount.toStringAsFixed(6),
      standardCalories.toStringAsFixed(6),
      standardFat.toStringAsFixed(6),
      standardProtein.toStringAsFixed(6),
      standardCarbs.toStringAsFixed(6),
      notes.trim(),
    ].join('|');
  }

  Future<List<FoodDefinition>> fetchFoods({
    String searchQuery = '',
    bool visibleOnly = true,
  }) async {
    final db = await DatabaseService.instance.database;
    final trimmedSearch = searchQuery.trim().toLowerCase();
    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    if (visibleOnly) {
      whereParts.add('foods.is_visible_in_library = 1');
    }
    if (trimmedSearch.isNotEmpty) {
      whereParts.add('LOWER(foods.name) LIKE ?');
      whereArgs.add('%$trimmedSearch%');
    }
    final whereClause = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      SELECT
        foods.*,
        COUNT(entry_items.id) AS usage_count
      FROM foods
      LEFT JOIN entry_items ON entry_items.food_id = foods.id
      $whereClause
      GROUP BY foods.id
      ORDER BY LOWER(foods.name) ASC, foods.id ASC
      ''',
      whereArgs,
    );
    return rows.map(FoodDefinition.fromMap).toList(growable: false);
  }

  Future<FoodDefinition?> fetchFoodById(int foodId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        foods.*,
        COUNT(entry_items.id) AS usage_count
      FROM foods
      LEFT JOIN entry_items ON entry_items.food_id = foods.id
      WHERE foods.id = ?
      GROUP BY foods.id
      LIMIT 1
      ''',
      [foodId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return FoodDefinition.fromMap(rows.first);
  }

  Future<int> createFood({
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
    bool isVisibleInLibrary = true,
  }) async {
    final db = await DatabaseService.instance.database;
    return createFoodInDatabase(
      db,
      name: name,
      standardUnit: standardUnit,
      standardUnitAmount: standardUnitAmount,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: notes,
      isVisibleInLibrary: isVisibleInLibrary,
    );
  }

  Future<int> createFoodInDatabase(
    DatabaseExecutor db, {
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
    bool isVisibleInLibrary = true,
  }) {
    final nowIso = DateTime.now().toIso8601String();
    return db.insert(
      'foods',
      {
        'name': name,
        'standard_unit': standardUnit,
        'standard_unit_amount': standardUnitAmount,
        'standard_calories': standardCalories,
        'standard_fat': standardFat,
        'standard_protein': standardProtein,
        'standard_carbs': standardCarbs,
        'notes': notes,
        'created_at': nowIso,
        'updated_at': nowIso,
        'is_visible_in_library': isVisibleInLibrary ? 1 : 0,
      },
    );
  }

  Future<int> ensureFood({
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
    bool isVisibleInLibrary = true,
  }) async {
    final db = await DatabaseService.instance.database;
    return ensureFoodInDatabase(
      db,
      name: name,
      standardUnit: standardUnit,
      standardUnitAmount: standardUnitAmount,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: notes,
      isVisibleInLibrary: isVisibleInLibrary,
    );
  }

  Future<int> ensureFoodInDatabase(
    DatabaseExecutor db, {
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
    bool isVisibleInLibrary = true,
  }) async {
    final rows = await db.query('foods');
    final targetSignature = _signature(
      name: name,
      standardUnit: standardUnit,
      standardUnitAmount: standardUnitAmount,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: notes,
    );
    for (final row in rows) {
      final existing = FoodDefinition.fromMap(row);
      final existingSignature = _signature(
        name: existing.name,
        standardUnit: existing.standardUnit,
        standardUnitAmount: existing.standardUnitAmount,
        standardCalories: existing.standardCalories,
        standardFat: existing.standardFat,
        standardProtein: existing.standardProtein,
        standardCarbs: existing.standardCarbs,
        notes: existing.notes,
      );
      if (existingSignature == targetSignature) {
        if (isVisibleInLibrary && !existing.isVisibleInLibrary) {
          await updateFoodInDatabase(
            db,
            foodId: existing.id,
            name: existing.name,
            standardUnit: existing.standardUnit,
            standardUnitAmount: existing.standardUnitAmount,
            standardCalories: existing.standardCalories,
            standardFat: existing.standardFat,
            standardProtein: existing.standardProtein,
            standardCarbs: existing.standardCarbs,
            notes: existing.notes,
            isVisibleInLibrary: true,
          );
        }
        return existing.id;
      }
    }
    return createFoodInDatabase(
      db,
      name: name,
      standardUnit: standardUnit,
      standardUnitAmount: standardUnitAmount,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: notes,
      isVisibleInLibrary: isVisibleInLibrary,
    );
  }

  Future<void> updateFood({
    required int foodId,
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
    required bool isVisibleInLibrary,
  }) async {
    final db = await DatabaseService.instance.database;
    await updateFoodInDatabase(
      db,
      foodId: foodId,
      name: name,
      standardUnit: standardUnit,
      standardUnitAmount: standardUnitAmount,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: notes,
      isVisibleInLibrary: isVisibleInLibrary,
    );
  }

  Future<void> updateFoodInDatabase(
    DatabaseExecutor db, {
    required int foodId,
    required String name,
    required String standardUnit,
    required double standardUnitAmount,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
    required bool isVisibleInLibrary,
  }) {
    return db.update(
      'foods',
      {
        'name': name,
        'standard_unit': standardUnit,
        'standard_unit_amount': standardUnitAmount,
        'standard_calories': standardCalories,
        'standard_fat': standardFat,
        'standard_protein': standardProtein,
        'standard_carbs': standardCarbs,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
        'is_visible_in_library': isVisibleInLibrary ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [foodId],
    );
  }

  Future<void> mergeFoods({
    required int targetFoodId,
    required List<FoodMergeSource> sources,
  }) async {
    final db = await DatabaseService.instance.database;
    final normalizedSources = <int, double>{};
    for (final source in sources) {
      if (source.sourceFoodId == targetFoodId) {
        throw ArgumentError('Target food cannot also be a merge source.');
      }
      if (source.conversionFactor <= 0) {
        throw ArgumentError('Conversion factor must be greater than 0.');
      }
      if (normalizedSources.containsKey(source.sourceFoodId)) {
        throw ArgumentError('Duplicate merge source: ${source.sourceFoodId}.');
      }
      normalizedSources[source.sourceFoodId] = source.conversionFactor;
    }
    if (normalizedSources.isEmpty) {
      return;
    }
    await db.transaction((txn) async {
      for (final entry in normalizedSources.entries) {
        await txn.rawUpdate(
          '''
          UPDATE entry_items
          SET multiplier = multiplier * ?
          WHERE food_id = ?
          ''',
          [entry.value, entry.key],
        );
        await txn.update(
          'entry_items',
          {'food_id': targetFoodId},
          where: 'food_id = ?',
          whereArgs: [entry.key],
        );
      }
      final sourceIds = normalizedSources.keys.toList(growable: false);
      final placeholders = List.filled(sourceIds.length, '?').join(', ');
      await txn.delete(
        'foods',
        where: 'id IN ($placeholders)',
        whereArgs: sourceIds,
      );
    });
  }

  Future<List<Map<String, dynamic>>> exportFoodRows() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('foods');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }
}
