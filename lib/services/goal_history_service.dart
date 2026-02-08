import 'package:sqflite/sqflite.dart';

import '../models/daily_goals.dart';
import 'database_service.dart';

class GoalHistoryService {
  GoalHistoryService._();

  static final GoalHistoryService instance = GoalHistoryService._();

  String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  Future<void> upsertGoalsForDate({
    required DateTime date,
    required DailyGoals goals,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'goal_history',
      {
        'goal_date': _dayKey(date),
        'calories': goals.calories,
        'fat': goals.fat,
        'protein': goals.protein,
        'carbs': goals.carbs,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailyGoals> getEffectiveGoalsForDate({
    required DateTime date,
    required DailyGoals fallback,
  }) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'goal_history',
      where: 'goal_date <= ?',
      whereArgs: [_dayKey(date)],
      orderBy: 'goal_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return fallback;
    }
    return _goalsFromRow(rows.first, fallback);
  }

  Future<Map<String, DailyGoals>> getEffectiveGoalsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required DailyGoals fallback,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'goal_history',
      where: 'goal_date <= ?',
      whereArgs: [_dayKey(end)],
      orderBy: 'goal_date ASC',
    );

    final result = <String, DailyGoals>{};
    var cursor = 0;
    DailyGoals active = fallback;

    for (var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))) {
      final dateKey = _dayKey(date);
      while (cursor < rows.length) {
        final row = rows[cursor];
        final rowKey = (row['goal_date'] as String?) ?? '';
        if (rowKey.compareTo(dateKey) <= 0) {
          active = _goalsFromRow(row, active);
          cursor += 1;
          continue;
        }
        break;
      }
      result[dateKey] = active;
    }
    return result;
  }

  DailyGoals _goalsFromRow(Map<String, Object?> row, DailyGoals fallback) {
    return DailyGoals(
      calories: (row['calories'] as int?) ?? fallback.calories,
      fat: (row['fat'] as int?) ?? fallback.fat,
      protein: (row['protein'] as int?) ?? fallback.protein,
      carbs: (row['carbs'] as int?) ?? fallback.carbs,
    );
  }
}
