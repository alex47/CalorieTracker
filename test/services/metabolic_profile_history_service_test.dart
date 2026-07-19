import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/services/metabolic_profile_history_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('MetabolicProfileHistoryService profile identity', () {
    test('creating a profile on an occupied date fails without overwriting',
        () async {
      final db = await _openProfileDatabase();
      addTearDown(db.close);
      await MetabolicProfileHistoryService.instance.createProfileInDatabase(
        db,
        date: DateTime(2026, 1, 1),
        profile: _profile(weightKg: 70),
      );

      await expectLater(
        MetabolicProfileHistoryService.instance.createProfileInDatabase(
          db,
          date: DateTime(2026, 1, 1),
          profile: _profile(weightKg: 90),
        ),
        throwsA(isA<DatabaseException>()),
      );

      final rows = await db.query('metabolic_profile_history');
      expect(rows, hasLength(1));
      expect(rows.single['weight_kg'], 70);
    });

    test('updating to an unused date moves the original row', () async {
      final db = await _openProfileDatabase();
      addTearDown(db.close);
      final profileId =
          await MetabolicProfileHistoryService.instance.createProfileInDatabase(
        db,
        date: DateTime(2026, 1, 1),
        profile: _profile(weightKg: 70),
      );
      final createdAt = (await db.query(
        'metabolic_profile_history',
        where: 'id = ?',
        whereArgs: [profileId],
      ))
          .single['created_at'];

      await MetabolicProfileHistoryService.instance.updateProfileInDatabase(
        db,
        profileId: profileId,
        date: DateTime(2026, 2, 1),
        profile: _profile(weightKg: 75),
      );

      final rows = await db.query('metabolic_profile_history');
      expect(rows, hasLength(1));
      expect(rows.single['id'], profileId);
      expect(rows.single['profile_date'], '2026-02-01');
      expect(rows.single['weight_kg'], 75);
      expect(rows.single['created_at'], createdAt);
    });

    test('updating to an occupied date leaves both profiles unchanged',
        () async {
      final db = await _openProfileDatabase();
      addTearDown(db.close);
      final firstId =
          await MetabolicProfileHistoryService.instance.createProfileInDatabase(
        db,
        date: DateTime(2026, 1, 1),
        profile: _profile(weightKg: 70),
      );
      await MetabolicProfileHistoryService.instance.createProfileInDatabase(
        db,
        date: DateTime(2026, 2, 1),
        profile: _profile(weightKg: 80),
      );

      await expectLater(
        MetabolicProfileHistoryService.instance.updateProfileInDatabase(
          db,
          profileId: firstId,
          date: DateTime(2026, 2, 1),
          profile: _profile(weightKg: 90),
        ),
        throwsA(isA<DatabaseException>()),
      );

      final rows = await db.query(
        'metabolic_profile_history',
        orderBy: 'profile_date ASC',
      );
      expect(rows, hasLength(2));
      expect(rows[0]['profile_date'], '2026-01-01');
      expect(rows[0]['weight_kg'], 70);
      expect(rows[1]['profile_date'], '2026-02-01');
      expect(rows[1]['weight_kg'], 80);
    });

    test('deleting by id removes the original profile after a date edit',
        () async {
      final db = await _openProfileDatabase();
      addTearDown(db.close);
      final originalId =
          await MetabolicProfileHistoryService.instance.createProfileInDatabase(
        db,
        date: DateTime(2026, 1, 1),
        profile: _profile(weightKg: 70),
      );
      final occupiedId =
          await MetabolicProfileHistoryService.instance.createProfileInDatabase(
        db,
        date: DateTime(2026, 2, 1),
        profile: _profile(weightKg: 80),
      );

      await MetabolicProfileHistoryService.instance.deleteProfileInDatabase(
        db,
        originalId,
      );

      final rows = await db.query('metabolic_profile_history');
      expect(rows, hasLength(1));
      expect(rows.single['id'], occupiedId);
      expect(rows.single['profile_date'], '2026-02-01');
      expect(rows.single['weight_kg'], 80);
    });
  });
}

MetabolicProfile _profile({required double weightKg}) {
  return MetabolicProfile(
    age: 30,
    sex: 'male',
    heightCm: 180,
    weightKg: weightKg,
    activityLevel: 'moderate',
    fatRatioPercent: 30,
    proteinRatioPercent: 20,
    carbsRatioPercent: 50,
  );
}

Future<Database> _openProfileDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(
    '''
    CREATE TABLE metabolic_profile_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_date TEXT NOT NULL UNIQUE,
      age INTEGER NOT NULL,
      sex TEXT NOT NULL,
      height_cm REAL NOT NULL,
      weight_kg REAL NOT NULL,
      activity_level TEXT NOT NULL,
      macro_preset_key TEXT NOT NULL,
      fat_ratio_percent INTEGER NOT NULL,
      protein_ratio_percent INTEGER NOT NULL,
      carbs_ratio_percent INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
  );
  return db;
}
