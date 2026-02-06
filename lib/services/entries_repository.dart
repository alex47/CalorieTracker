import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';
import 'database_service.dart';

class EntriesRepository {
  EntriesRepository._();

  static final EntriesRepository instance = EntriesRepository._();

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
        await txn.insert('entry_items', {
          'entry_id': entryId,
          'name': item['name'] as String,
          'amount': item['amount'] as String,
          'calories': (item['calories'] as num).round(),
          'notes': item['notes'] as String? ?? '',
        });
      }

      return entryId;
    });
  }

  Future<List<FoodItem>> fetchItemsForDate(DateTime date) async {
    final db = await DatabaseService.instance.database;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
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
}
