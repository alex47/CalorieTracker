import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/day_summary.dart';
import 'database_service.dart';

class StoredDaySummary {
  const StoredDaySummary({
    required this.dateKey,
    required this.languageCode,
    required this.model,
    required this.sourceHash,
    required this.summary,
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  final String dateKey;
  final String languageCode;
  final String model;
  final String sourceHash;
  final DaySummary summary;
  final String createdAtIso;
  final String updatedAtIso;
}

class DaySummaryService {
  DaySummaryService._();

  static final DaySummaryService instance = DaySummaryService._();

  String dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  Future<StoredDaySummary?> fetchForDate(DateTime date) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'day_summary',
      where: 'summary_date = ?',
      whereArgs: [dayKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final rawSummary = (row['summary_json'] as String?) ?? '{}';
    final parsedSummary = jsonDecode(rawSummary);
    if (parsedSummary is! Map<String, dynamic>) {
      return null;
    }
    return StoredDaySummary(
      dateKey: (row['summary_date'] as String?) ?? dayKey(date),
      languageCode: (row['language_code'] as String?) ?? 'en',
      model: (row['model'] as String?) ?? '',
      sourceHash: (row['source_hash'] as String?) ?? '',
      summary: DaySummary.fromMap(parsedSummary),
      createdAtIso: (row['created_at'] as String?) ?? '',
      updatedAtIso: (row['updated_at'] as String?) ?? '',
    );
  }

  Future<void> upsert({
    required DateTime date,
    required String languageCode,
    required String model,
    required String sourceHash,
    required DaySummary summary,
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final existing = await fetchForDate(date);
    await db.insert(
      'day_summary',
      {
        'summary_date': dayKey(date),
        'language_code': languageCode,
        'model': model,
        'source_hash': sourceHash,
        'summary_json': jsonEncode(summary.toMap()),
        'created_at': existing?.createdAtIso.isNotEmpty == true ? existing!.createdAtIso : nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> exportSummaryRows() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('day_summary');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  String computeSourceHash(Map<String, dynamic> payload) {
    final canonical = _canonicalJson(payload);
    // Deterministic FNV-1a 64-bit hash (hex).
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    for (final byte in utf8.encode(canonical)) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _canonicalJson(Object? value) {
    final normalized = _normalize(value);
    return jsonEncode(normalized);
  }

  Object? _normalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.map((entry) {
        return MapEntry(entry.key.toString(), _normalize(entry.value));
      }).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return {for (final entry in entries) entry.key: entry.value};
    }
    if (value is List) {
      return value.map(_normalize).toList(growable: false);
    }
    if (value is String || value is num || value is bool || value == null) {
      return value;
    }
    return value.toString();
  }
}
