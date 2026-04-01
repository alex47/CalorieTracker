import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';
import '../utils/app_date_utils.dart';
import 'database_service.dart';
import 'food_library_service.dart';

class EntriesRepository {
  EntriesRepository._();

  static final EntriesRepository instance = EntriesRepository._();

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      return value;
    }
    return fallback;
  }

  Future<int> _createEntryRow({
    required DateTime date,
    required String prompt,
    required String response,
  }) async {
    final db = await DatabaseService.instance.database;
    return db.insert('entries', {
      'entry_date': AppDateUtils.dayOnly(date).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'prompt': prompt,
      'response': response,
    });
  }

  Future<int> _resolveFoodIdFromItem(
    DatabaseExecutor db,
    Map<String, dynamic> item, {
    required bool isVisibleInLibrary,
  }) async {
    final existingFoodId = (item['food_id'] as num?)?.toInt();
    if (existingFoodId != null && existingFoodId > 0) {
      return existingFoodId;
    }
    return FoodLibraryService.instance.ensureFoodInDatabase(
      db,
      name: _asString(item['name']).trim(),
      standardUnit: _asString(
        item['standard_unit'],
        fallback: _asString(item['standard_amount']),
      ).trim(),
      standardUnitAmount: _asDouble(item['standard_unit_amount'], fallback: 1.0),
      standardCalories: _asDouble(
        item['standard_calories'],
        fallback: _asDouble(item['calories']),
      ),
      standardFat: _asDouble(item['standard_fat'], fallback: _asDouble(item['fat'])),
      standardProtein: _asDouble(
        item['standard_protein'],
        fallback: _asDouble(item['protein']),
      ),
      standardCarbs: _asDouble(
        item['standard_carbs'],
        fallback: _asDouble(item['carbs']),
      ),
      notes: _asString(item['notes']),
      isVisibleInLibrary: isVisibleInLibrary,
    );
  }

  Future<int> createEntryGroup({
    required DateTime date,
    required String prompt,
    required String response,
    required List<Map<String, dynamic>> items,
    List<bool>? visibleInLibraryFlags,
  }) async {
    final db = await DatabaseService.instance.database;
    return db.transaction((txn) async {
      final entryId = await txn.insert('entries', {
        'entry_date': AppDateUtils.dayOnly(date).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'prompt': prompt,
        'response': response,
      });

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final visibleFlag =
            visibleInLibraryFlags != null && i < visibleInLibraryFlags.length
                ? visibleInLibraryFlags[i]
                : true;
        final foodId = await _resolveFoodIdFromItem(
          txn,
          item,
          isVisibleInLibrary: visibleFlag,
        );
        final multiplier = _asDouble(item['multiplier'], fallback: 1.0);
        await txn.insert('entry_items', {
          'entry_id': entryId,
          'food_id': foodId,
          'name': _asString(item['name']),
          'amount': _asString(item['amount']),
          'calories': _asDouble(item['calories']).round(),
          'fat': _asDouble(item['fat']),
          'protein': _asDouble(item['protein']),
          'carbs': _asDouble(item['carbs']),
          'standard_amount': _asString(item['standard_amount']),
          'standard_unit': _asString(item['standard_unit']),
          'standard_unit_amount': _asDouble(item['standard_unit_amount'], fallback: 1.0),
          'multiplier': multiplier > 0 ? multiplier : 1.0,
          'standard_calories': _asDouble(item['standard_calories']),
          'standard_fat': _asDouble(item['standard_fat']),
          'standard_protein': _asDouble(item['standard_protein']),
          'standard_carbs': _asDouble(item['standard_carbs']),
          'notes': _asString(item['notes']),
        });
      }

      return entryId;
    });
  }

  Future<void> addFoodToDate({
    required DateTime date,
    required int foodId,
    required double multiplier,
  }) async {
    final db = await DatabaseService.instance.database;
    final entryId = await _createEntryRow(
      date: date,
      prompt: 'Food library add',
      response: '',
    );
    await db.insert('entry_items', {
      'entry_id': entryId,
      'food_id': foodId,
      'name': '',
      'amount': '',
      'calories': 0,
      'fat': 0,
      'protein': 0,
      'carbs': 0,
      'standard_amount': '',
      'standard_unit': '',
      'standard_unit_amount': 1.0,
      'multiplier': multiplier > 0 ? multiplier : 1.0,
      'standard_calories': 0,
      'standard_fat': 0,
      'standard_protein': 0,
      'standard_carbs': 0,
      'notes': '',
    });
  }

  Future<List<FoodItem>> fetchItemsForDate(DateTime date) async {
    final db = await DatabaseService.instance.database;
    final start = AppDateUtils.dayOnly(date);
    final end = AppDateUtils.addCalendarDays(start, 1);
    final rows = await db.rawQuery(
      '''
      SELECT
        entry_items.id,
        entry_items.entry_id,
        entry_items.food_id,
        entry_items.multiplier,
        entries.entry_date,
        foods.name,
        foods.standard_unit,
        foods.standard_unit_amount,
        foods.standard_calories,
        foods.standard_fat,
        foods.standard_protein,
        foods.standard_carbs,
        foods.notes
      FROM entry_items
      INNER JOIN entries ON entry_items.entry_id = entries.id
      INNER JOIN foods ON entry_items.food_id = foods.id
      WHERE entries.entry_date >= ? AND entries.entry_date < ?
      ORDER BY entries.created_at DESC, entry_items.id DESC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return rows.map((row) {
      final standardUnitAmount = _asDouble(row['standard_unit_amount'], fallback: 1.0);
      final multiplier = _asDouble(row['multiplier'], fallback: 1.0);
      final standardCalories = _asDouble(row['standard_calories']);
      final standardFat = _asDouble(row['standard_fat']);
      final standardProtein = _asDouble(row['standard_protein']);
      final standardCarbs = _asDouble(row['standard_carbs']);
      return FoodItem.fromMap({
        'id': row['id'],
        'entry_id': row['entry_id'],
        'food_id': row['food_id'],
        'name': row['name'],
        'amount': '',
        'calories': FoodItem.computeCalories(
          standardCalories: standardCalories,
          multiplier: multiplier,
          standardUnitAmount: standardUnitAmount,
        ),
        'fat': FoodItem.computeMacro(
          standardMacro: standardFat,
          multiplier: multiplier,
          standardUnitAmount: standardUnitAmount,
        ),
        'protein': FoodItem.computeMacro(
          standardMacro: standardProtein,
          multiplier: multiplier,
          standardUnitAmount: standardUnitAmount,
        ),
        'carbs': FoodItem.computeMacro(
          standardMacro: standardCarbs,
          multiplier: multiplier,
          standardUnitAmount: standardUnitAmount,
        ),
        'standard_amount': '$standardUnitAmount ${row['standard_unit']}',
        'standard_unit': row['standard_unit'],
        'standard_unit_amount': standardUnitAmount,
        'multiplier': multiplier,
        'standard_calories': standardCalories,
        'standard_fat': standardFat,
        'standard_protein': standardProtein,
        'standard_carbs': standardCarbs,
        'notes': row['notes'],
      });
    }).toList(growable: false);
  }

  Future<void> updateEntryItemMultiplier({
    required int itemId,
    required double multiplier,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'entry_items',
      {
        'multiplier': multiplier > 0 ? multiplier : 1.0,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> updateEntryItem({
    required int itemId,
    required String name,
    required String amount,
    required String standardUnit,
    required double standardUnitAmount,
    required double multiplier,
    required double standardCalories,
    required double standardFat,
    required double standardProtein,
    required double standardCarbs,
    required String notes,
  }) async {
    final db = await DatabaseService.instance.database;
    final foodIdRows = await db.query(
      'entry_items',
      columns: ['food_id'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (foodIdRows.isEmpty) {
      throw StateError('Entry item not found.');
    }
    final foodId = (foodIdRows.first['food_id'] as num).toInt();
    await FoodLibraryService.instance.updateFood(
      foodId: foodId,
      name: name,
      standardUnit: standardUnit,
      standardUnitAmount: standardUnitAmount,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: notes,
      isVisibleInLibrary: true,
    );
    await updateEntryItemMultiplier(
      itemId: itemId,
      multiplier: multiplier,
    );
  }

  Future<void> deleteEntryItem(int itemId) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      'entry_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> copyItemToDate({
    required FoodItem item,
    required DateTime date,
  }) async {
    await addFoodToDate(
      date: date,
      foodId: item.foodId,
      multiplier: item.multiplier,
    );
  }

  Future<List<Map<String, dynamic>>> exportEntriesRows() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('entries');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> exportEntryItemsRows() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('entry_items');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}
