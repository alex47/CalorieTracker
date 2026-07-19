import 'package:calorie_tracker/models/day_summary.dart';
import 'package:calorie_tracker/services/day_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/database_test_helper.dart';

void main() {
  group('DaySummaryService hashing', () {
    test('canonicalizes nested map keys before hashing', () {
      final service = DaySummaryService.instance;
      final first = service.computeSourceHash({
        'z': 3,
        'nested': {
          'beta': true,
          'alpha': 1,
        },
        'items': [
          {'name': 'Apple', 'calories': 52},
        ],
      });
      final reordered = service.computeSourceHash({
        'items': [
          {'calories': 52, 'name': 'Apple'},
        ],
        'nested': {
          'alpha': 1,
          'beta': true,
        },
        'z': 3,
      });

      expect(reordered, first);
      expect(first, hasLength(16));
      expect(first, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('retains list order and value types in the source hash', () {
      final service = DaySummaryService.instance;
      final original = service.computeSourceHash({
        'items': [1, 2],
        'enabled': true,
      });

      expect(
        service.computeSourceHash({
          'items': [2, 1],
          'enabled': true,
        }),
        isNot(original),
      );
      expect(
        service.computeSourceHash({
          'items': ['1', 2],
          'enabled': true,
        }),
        isNot(original),
      );
    });
  });

  group('DaySummaryService persistence', () {
    late Database db;

    setUp(() async {
      db = await openTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('returns null when a date has no stored summary', () async {
      expect(
        await DaySummaryService.instance.fetchForDateInDatabase(
          db,
          DateTime(2026, 7, 19),
        ),
        isNull,
      );
    });

    test('stores, fetches, and exports a summary', () async {
      const summary = DaySummary(
        summary: 'Balanced day.',
        highlights: ['Protein target met'],
        issues: [],
        suggestions: ['Add vegetables'],
      );
      final service = DaySummaryService.instance;

      await service.upsertInDatabase(
        db,
        date: DateTime(2026, 7, 19, 18),
        languageCode: 'en',
        model: 'test-model',
        sourceHash: 'source-one',
        summary: summary,
      );

      final stored = await service.fetchForDateInDatabase(
        db,
        DateTime(2026, 7, 19, 1),
      );
      expect(stored, isNotNull);
      expect(stored!.dateKey, '2026-07-19');
      expect(stored.languageCode, 'en');
      expect(stored.model, 'test-model');
      expect(stored.sourceHash, 'source-one');
      expect(stored.summary.toMap(), summary.toMap());
      expect(stored.createdAtIso, isNotEmpty);
      expect(stored.updatedAtIso, isNotEmpty);

      final rows = await service.exportSummaryRowsInDatabase(db);
      expect(rows, hasLength(1));
      expect(rows.single['summary_date'], '2026-07-19');
      expect(rows.single['source_hash'], 'source-one');
    });

    test('replaces the same day while retaining its creation timestamp',
        () async {
      const createdAt = '2026-01-02T03:04:05.000';
      await db.insert('day_summary', {
        'summary_date': '2026-07-19',
        'language_code': 'en',
        'model': 'old-model',
        'source_hash': 'old-hash',
        'summary_json':
            '{"summary":"Old","highlights":[],"issues":[],"suggestions":[]}',
        'created_at': createdAt,
        'updated_at': createdAt,
      });

      const replacement = DaySummary(
        summary: 'Replacement',
        highlights: ['New'],
        issues: ['Issue'],
        suggestions: [],
      );
      await DaySummaryService.instance.upsertInDatabase(
        db,
        date: DateTime(2026, 7, 19),
        languageCode: 'hu',
        model: 'new-model',
        sourceHash: 'new-hash',
        summary: replacement,
      );

      final rows = await db.query('day_summary');
      expect(rows, hasLength(1));
      final stored = await DaySummaryService.instance.fetchForDateInDatabase(
        db,
        DateTime(2026, 7, 19),
      );
      expect(stored!.createdAtIso, createdAt);
      expect(stored.updatedAtIso, isNot(createdAt));
      expect(stored.languageCode, 'hu');
      expect(stored.model, 'new-model');
      expect(stored.sourceHash, 'new-hash');
      expect(stored.summary.toMap(), replacement.toMap());
    });
  });
}
