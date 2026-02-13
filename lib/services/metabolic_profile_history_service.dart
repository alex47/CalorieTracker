import 'package:sqflite/sqflite.dart';

import '../models/metabolic_profile.dart';
import 'database_service.dart';

class MetabolicProfileHistoryService {
  MetabolicProfileHistoryService._();

  static final MetabolicProfileHistoryService instance = MetabolicProfileHistoryService._();

  String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  Future<void> upsertProfileForDate({
    required DateTime date,
    required MetabolicProfile profile,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'metabolic_profile_history',
      {
        'profile_date': _dayKey(date),
        'age': profile.age,
        'sex': profile.sex,
        'height_cm': profile.heightCm,
        'weight_kg': profile.weightKg,
        'activity_level': profile.activityLevel,
        'fat_ratio_percent': profile.fatRatioPercent,
        'protein_ratio_percent': profile.proteinRatioPercent,
        'carbs_ratio_percent': profile.carbsRatioPercent,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MetabolicProfile?> getEffectiveProfileForDate({
    required DateTime date,
  }) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'metabolic_profile_history',
      where: 'profile_date <= ?',
      whereArgs: [_dayKey(date)],
      orderBy: 'profile_date DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _profileFromRow(rows.first);
    }
    final earliestRows = await db.query(
      'metabolic_profile_history',
      orderBy: 'profile_date ASC',
      limit: 1,
    );
    if (earliestRows.isEmpty) {
      return null;
    }
    return _profileFromRow(earliestRows.first);
  }

  Future<Map<String, MetabolicProfile?>> getEffectiveProfileForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'metabolic_profile_history',
      where: 'profile_date <= ?',
      whereArgs: [_dayKey(end)],
      orderBy: 'profile_date ASC',
    );
    final earliestRows = await db.query(
      'metabolic_profile_history',
      orderBy: 'profile_date ASC',
      limit: 1,
    );
    final fallbackProfile = earliestRows.isNotEmpty ? _profileFromRow(earliestRows.first) : null;

    final result = <String, MetabolicProfile?>{};
    var cursor = 0;
    MetabolicProfile? active = fallbackProfile;

    for (var date = start; !date.isAfter(end); date = date.add(const Duration(days: 1))) {
      final dateKey = _dayKey(date);
      while (cursor < rows.length) {
        final row = rows[cursor];
        final rowKey = (row['profile_date'] as String?) ?? '';
        if (rowKey.compareTo(dateKey) <= 0) {
          active = _profileFromRow(row);
          cursor += 1;
          continue;
        }
        break;
      }
      result[dateKey] = active;
    }
    return result;
  }

  MetabolicProfile _profileFromRow(Map<String, Object?> row) {
    return MetabolicProfile(
      age: (row['age'] as int?) ?? 0,
      sex: (row['sex'] as String?) ?? 'male',
      heightCm: (row['height_cm'] as num?)?.toDouble() ?? 0,
      weightKg: (row['weight_kg'] as num?)?.toDouble() ?? 0,
      activityLevel: (row['activity_level'] as String?) ?? 'moderate',
      fatRatioPercent: ((row['fat_ratio_percent'] as num?)?.round()) ?? 30,
      proteinRatioPercent: ((row['protein_ratio_percent'] as num?)?.round()) ?? 30,
      carbsRatioPercent: ((row['carbs_ratio_percent'] as num?)?.round()) ?? 40,
    );
  }

  Future<List<Map<String, dynamic>>> exportProfileHistoryRows() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('metabolic_profile_history');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}
