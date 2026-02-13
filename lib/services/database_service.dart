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
      version: 5,
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
            created_at TEXT NOT NULL
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
