import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<void> initialize() async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await openDatabase(
      join(await getDatabasesPath(), 'calorie_tracker.db'),
      version: 8,
      onCreate: (db, version) async {
        await db.execute(
          '''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            prompt TEXT NOT NULL,
            response TEXT NOT NULL
          )
          ''',
        );
        await db.execute(
          '''
          CREATE TABLE entry_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            amount TEXT NOT NULL,
            calories INTEGER NOT NULL,
            fat REAL NOT NULL DEFAULT 0,
            protein REAL NOT NULL DEFAULT 0,
            carbs REAL NOT NULL DEFAULT 0,
            notes TEXT,
            FOREIGN KEY(entry_id) REFERENCES entries(id)
          )
          ''',
        );
        await db.execute(
          '''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
          ''',
        );
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
            macro_preset_key TEXT NOT NULL DEFAULT 'balanced_default',
            fat_ratio_percent INTEGER NOT NULL DEFAULT 30,
            protein_ratio_percent INTEGER NOT NULL DEFAULT 30,
            carbs_ratio_percent INTEGER NOT NULL DEFAULT 40,
            created_at TEXT NOT NULL
          )
          ''',
        );
        await db.execute(
          '''
          CREATE TABLE day_summary (
            summary_date TEXT PRIMARY KEY,
            language_code TEXT NOT NULL,
            model TEXT NOT NULL,
            source_hash TEXT NOT NULL,
            summary_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
          ''',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE entry_items ADD COLUMN fat REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE entry_items ADD COLUMN protein REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE entry_items ADD COLUMN carbs REAL NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
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
              created_at TEXT NOT NULL
            )
            ''',
          );
        }
        if (oldVersion < 5) {
          await db.execute('DROP TABLE IF EXISTS goal_history');
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE metabolic_profile_history ADD COLUMN fat_ratio_percent INTEGER NOT NULL DEFAULT 30',
          );
          await db.execute(
            'ALTER TABLE metabolic_profile_history ADD COLUMN protein_ratio_percent INTEGER NOT NULL DEFAULT 30',
          );
          await db.execute(
            'ALTER TABLE metabolic_profile_history ADD COLUMN carbs_ratio_percent INTEGER NOT NULL DEFAULT 40',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            '''
            CREATE TABLE day_summary (
              summary_date TEXT PRIMARY KEY,
              language_code TEXT NOT NULL,
              model TEXT NOT NULL,
              source_hash TEXT NOT NULL,
              summary_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
            ''',
          );
        }
        if (oldVersion < 8) {
          await db.execute(
            "ALTER TABLE metabolic_profile_history ADD COLUMN macro_preset_key TEXT NOT NULL DEFAULT 'balanced_default'",
          );
          await db.execute(
            '''
            UPDATE metabolic_profile_history
            SET macro_preset_key = CASE
              WHEN fat_ratio_percent = 30 AND protein_ratio_percent = 20 AND carbs_ratio_percent = 50 THEN 'balanced_default'
              WHEN fat_ratio_percent = 30 AND protein_ratio_percent = 30 AND carbs_ratio_percent = 40 THEN 'fat_loss_higher_protein'
              WHEN fat_ratio_percent = 30 AND protein_ratio_percent = 35 AND carbs_ratio_percent = 35 THEN 'body_recomposition_training'
              WHEN fat_ratio_percent = 30 AND protein_ratio_percent = 15 AND carbs_ratio_percent = 55 THEN 'endurance_high_activity'
              WHEN fat_ratio_percent = 40 AND protein_ratio_percent = 35 AND carbs_ratio_percent = 25 THEN 'lower_carb_appetite_control'
              WHEN fat_ratio_percent = 20 AND protein_ratio_percent = 20 AND carbs_ratio_percent = 60 THEN 'high_carb_performance'
              ELSE 'balanced_default'
            END
            ''',
          );
        }
      },
    );
  }

  Future<Database> get database async {
    if (_database == null) {
      throw StateError('Database has not been initialized.');
    }
    return _database!;
  }
}
