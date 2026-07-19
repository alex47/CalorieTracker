import 'package:calorie_tracker/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await DatabaseService.configureDatabase(db);
  await DatabaseService.createSchema(db, DatabaseService.schemaVersion);
  return db;
}
