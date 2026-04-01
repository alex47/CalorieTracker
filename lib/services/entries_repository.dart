
import '../models/food_item.dart';
import '../utils/app_date_utils.dart';
import 'database_service.dart';

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

  Map<String, Object?> _entryItemValues({
    required int entryId,
    required Map<String, dynamic> item,
  }) {
    final amount = _asString(item['amount']).trim();
    final standardUnit = _asString(
      item['standard_unit'],
      fallback: _asString(item['standard_amount'], fallback: amount),
    ).trim();
    final rawUnitAmount = _asDouble(item['standard_unit_amount'], fallback: 1.0);
    final standardUnitAmount = rawUnitAmount > 0 ? rawUnitAmount : 1.0;
    final rawMultiplier = _asDouble(item['multiplier'], fallback: 1.0);
    final multiplier = rawMultiplier > 0 ? rawMultiplier : 1.0;

    final baseCalories = _asDouble(
      item['standard_calories'],
      fallback: _asDouble(item['calories']),
    );
    final baseFat = _asDouble(
      item['standard_fat'],
      fallback: _asDouble(item['fat']),
    );
    final baseProtein = _asDouble(
      item['standard_protein'],
      fallback: _asDouble(item['protein']),
    );
    final baseCarbs = _asDouble(
      item['standard_carbs'],
      fallback: _asDouble(item['carbs']),
    );

    final calories = FoodItem.computeCalories(
      standardCalories: baseCalories,
      multiplier: multiplier,
      standardUnitAmount: standardUnitAmount,
    );
    final fat = FoodItem.computeMacro(
      standardMacro: baseFat,
      multiplier: multiplier,
      standardUnitAmount: standardUnitAmount,
    );
    final protein = FoodItem.computeMacro(
      standardMacro: baseProtein,
      multiplier: multiplier,
      standardUnitAmount: standardUnitAmount,
    );
    final carbs = FoodItem.computeMacro(
      standardMacro: baseCarbs,
      multiplier: multiplier,
      standardUnitAmount: standardUnitAmount,
    );

    return {
      'entry_id': entryId,
      'name': _asString(item['name']),
      'amount': amount,
      'calories': calories,
      'fat': fat,
      'protein': protein,
      'carbs': carbs,
      'standard_amount': standardUnit.isEmpty ? amount : '$standardUnitAmount $standardUnit',
      'standard_unit': standardUnit.isEmpty ? amount : standardUnit,
      'standard_unit_amount': standardUnitAmount,
      'multiplier': multiplier,
      'standard_calories': baseCalories,
      'standard_fat': baseFat,
      'standard_protein': baseProtein,
      'standard_carbs': baseCarbs,
      'notes': _asString(item['notes']),
    };
  }

  Future<int> createEntryGroup({
    required DateTime date,
    required String prompt,
    required String response,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await DatabaseService.instance.database;
    return db.transaction((txn) async {
      final entryId = await txn.insert('entries', {
        'entry_date': date.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'prompt': prompt,
        'response': response,
      });

      for (final item in items) {
        await txn.insert(
          'entry_items',
          _entryItemValues(entryId: entryId, item: item),
        );
      }

      return entryId;
    });
  }

  Future<List<FoodItem>> fetchItemsForDate(DateTime date) async {
    final db = await DatabaseService.instance.database;
    final start = AppDateUtils.dayOnly(date);
    final end = AppDateUtils.addCalendarDays(start, 1);
    final rows = await db.rawQuery(
      '''
      SELECT entry_items.*
      FROM entry_items
      INNER JOIN entries ON entry_items.entry_id = entries.id
      WHERE entries.entry_date >= ? AND entries.entry_date < ?
      ORDER BY entries.created_at DESC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(FoodItem.fromMap).toList();
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
    final safeMultiplier = multiplier > 0 ? multiplier : 1.0;
    final safeStandardUnitAmount = standardUnitAmount > 0 ? standardUnitAmount : 1.0;
    final calories = FoodItem.computeCalories(
      standardCalories: standardCalories,
      multiplier: safeMultiplier,
      standardUnitAmount: safeStandardUnitAmount,
    );
    final fat = FoodItem.computeMacro(
      standardMacro: standardFat,
      multiplier: safeMultiplier,
      standardUnitAmount: safeStandardUnitAmount,
    );
    final protein = FoodItem.computeMacro(
      standardMacro: standardProtein,
      multiplier: safeMultiplier,
      standardUnitAmount: safeStandardUnitAmount,
    );
    final carbs = FoodItem.computeMacro(
      standardMacro: standardCarbs,
      multiplier: safeMultiplier,
      standardUnitAmount: safeStandardUnitAmount,
    );
    final db = await DatabaseService.instance.database;
    await db.update(
      'entry_items',
      {
        'name': name,
        'amount': amount,
        'calories': calories,
        'fat': fat,
        'protein': protein,
        'carbs': carbs,
        'standard_amount': '$safeStandardUnitAmount $standardUnit',
        'standard_unit': standardUnit,
        'standard_unit_amount': safeStandardUnitAmount,
        'multiplier': safeMultiplier,
        'standard_calories': standardCalories,
        'standard_fat': standardFat,
        'standard_protein': standardProtein,
        'standard_carbs': standardCarbs,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [itemId],
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
    final db = await DatabaseService.instance.database;
    final day = DateTime(date.year, date.month, date.day);
    await db.transaction((txn) async {
      final entryId = await txn.insert('entries', {
        'entry_date': day.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'prompt': 'Copied from another day',
        'response': '',
      });
      await txn.insert('entry_items', {
        'entry_id': entryId,
        'name': item.name,
        'amount': item.amount,
        'calories': item.calories,
        'fat': item.fat,
        'protein': item.protein,
        'carbs': item.carbs,
        'standard_amount': item.standardAmountText,
        'standard_unit': item.standardUnit,
        'standard_unit_amount': item.standardUnitAmount,
        'multiplier': item.multiplier,
        'standard_calories': item.standardCalories,
        'standard_fat': item.standardFat,
        'standard_protein': item.standardProtein,
        'standard_carbs': item.standardCarbs,
        'notes': item.notes,
      });
    });
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
