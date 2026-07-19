import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:calorie_tracker/models/food_definition.dart';
import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/screens/add_entry_screen.dart';
import 'package:calorie_tracker/screens/food_definition_screen.dart';
import 'package:calorie_tracker/screens/food_item_detail_screen.dart';
import 'package:calorie_tracker/screens/home_screen.dart';
import 'package:calorie_tracker/screens/weekly_summary_screen.dart';
import 'package:calorie_tracker/services/data_transfer_service.dart';
import 'package:calorie_tracker/services/database_service.dart';
import 'package:calorie_tracker/services/entries_repository.dart';
import 'package:calorie_tracker/services/food_library_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('offline application journeys', () {
    late Database db;

    setUp(() async {
      db = await _openDatabase();
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    testWidgets(
        'launches empty, creates, logs, edits, and reloads food history',
        (tester) async {
      await _pumpHome(tester, db);
      expect(
        find.text('No entries for this day yet. Tap Add to log food.'),
        findsOneWidget,
      );

      await _pumpRoute(
        tester,
        FoodDefinitionScreen(
          saveFood: ({
            required existingFood,
            required name,
            required standardUnit,
            required standardUnitAmount,
            required standardCalories,
            required standardFat,
            required standardProtein,
            required standardCarbs,
            required notes,
          }) async {
            await FoodLibraryService.instance.createFoodInDatabase(
              db,
              name: name,
              standardUnit: standardUnit,
              standardUnitAmount: standardUnitAmount,
              standardCalories: standardCalories,
              standardFat: standardFat,
              standardProtein: standardProtein,
              standardCarbs: standardCarbs,
              notes: notes,
            );
          },
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Apple');
      await tester.enterText(fields.at(1), 'g');
      await tester.enterText(fields.at(2), '100');
      await tester.enterText(fields.at(3), '100');
      await tester.enterText(fields.at(4), '1');
      await tester.enterText(fields.at(5), '2');
      await tester.enterText(fields.at(6), '3');
      await _tapVisible(tester, find.text('Save'));
      await tester.pumpAndSettle();

      final foods = await FoodLibraryService.instance.fetchFoodsInDatabase(db);
      expect(foods, hasLength(1));
      expect(foods.single.name, 'Apple');

      await _pumpRoute(
        tester,
        AddEntryScreen(
          date: _today,
          loadFoods: ({
            required searchQuery,
            required visibleOnly,
          }) =>
              FoodLibraryService.instance.fetchFoodsInDatabase(
            db,
            searchQuery: searchQuery,
            visibleOnly: visibleOnly,
          ),
          addExistingFood: ({
            required date,
            required foodId,
            required multiplier,
          }) =>
              EntriesRepository.instance.addFoodToDateInDatabase(
            db,
            date: date,
            foodId: foodId,
            multiplier: multiplier,
          ),
        ),
      );
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      await _pumpHome(tester, db);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('100 g'), findsOneWidget);

      final loggedItem =
          (await EntriesRepository.instance.fetchItemsForDateInDatabase(
        db,
        _today,
      ))
              .single;
      await _pumpRoute(
        tester,
        FoodItemDetailScreen(
          item: loggedItem,
          itemDate: _today,
          saveItem: ({
            required item,
            required date,
            required isNew,
            required multiplier,
          }) =>
              EntriesRepository.instance.updateEntryItemMultiplierInDatabase(
            db,
            itemId: item.id,
            multiplier: multiplier,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '150');
      await _tapVisible(tester, find.text('Save'));
      await tester.pumpAndSettle();

      await _pumpHome(tester, db);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('150 g'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('copies foods, opens weekly totals, and round-trips a backup',
        (tester) async {
      final appleId = await _createFood(db, 'Apple');
      final bananaId = await _createFood(db, 'Banana');
      final previousDay = DateTime(2026, 7, 19);
      await EntriesRepository.instance.addFoodToDateInDatabase(
        db,
        date: previousDay,
        foodId: appleId,
        multiplier: 100,
      );
      await EntriesRepository.instance.addFoodToDateInDatabase(
        db,
        date: previousDay,
        foodId: bananaId,
        multiplier: 100,
      );

      await _pumpHome(
        tester,
        db,
        copyItems: ({required items, required date}) {
          return EntriesRepository.instance.copyItemsToDateInDatabase(
            db,
            items: items,
            date: date,
          );
        },
      );
      await tester.drag(find.byType(PageView), const Offset(700, 0));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Apple'));
      await tester.longPress(find.text('Banana'));
      await tester.tap(find.text('Copy to today'));
      await tester.pumpAndSettle();

      final todayItems =
          await EntriesRepository.instance.fetchItemsForDateInDatabase(
        db,
        _today,
      );
      expect(todayItems.map((item) => item.name).toSet(), {'Apple', 'Banana'});
      expect(find.text('July 20, 2026'), findsOneWidget);

      await tester.pumpWidget(
        _testApp(
          WeeklySummaryScreen(
            anchorDate: DateTime(2026, 7, 13),
            now: () => _today,
            languageCode: 'en',
            loadItems: (date) =>
                EntriesRepository.instance.fetchItemsForDateInDatabase(
              db,
              date,
            ),
            loadProfiles: ({
              required startDate,
              required endDate,
            }) async =>
                _profilesForRange(startDate, endDate),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('July 13 - July 19'), findsOneWidget);
      expect(find.text('11060 kcal*'), findsOneWidget);

      final transfer = DataTransferService.instance;
      List<int>? virtualFile;
      final path = await transfer.exportDataInDatabase(
        db,
        includeApiKey: false,
        exportedAt: DateTime(2026, 7, 20, 12),
        writeFile: ({required suggestedName, required bytes}) async {
          virtualFile = List<int>.from(bytes);
          return suggestedName;
        },
      );
      expect(
        path,
        'calorie_tracker_export_2026-07-20T12-00-00.000.json',
      );
      final payload = await transfer.pickImportDataWithReader(
        () async => virtualFile,
      );
      expect(payload, isNotNull);

      await db.close();
      final importedDb = await _openDatabase();
      addTearDown(importedDb.close);
      final summary =
          await transfer.applyImportDataInDatabase(importedDb, payload!);
      expect(summary.entriesCount, 2);
      expect(summary.itemsCount, 4);
      expect(
        await FoodLibraryService.instance.fetchFoodsInDatabase(importedDb),
        hasLength(2),
      );
      expect(
        await EntriesRepository.instance.fetchItemsForDateInDatabase(
          importedDb,
          _today,
        ),
        hasLength(2),
      );
      expect(await importedDb.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });
  });
}

final _today = DateTime(2026, 7, 20, 12);

const _profile = MetabolicProfile(
  age: 30,
  sex: 'male',
  heightCm: 180,
  weightKg: 80,
  activityLevel: 'bmr',
  fatRatioPercent: 30,
  proteinRatioPercent: 20,
  carbsRatioPercent: 50,
);

Future<Database> _openDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await DatabaseService.configureDatabase(db);
  await DatabaseService.createSchema(db, DatabaseService.schemaVersion);
  return db;
}

Future<void> _pumpHome(
  WidgetTester tester,
  Database db, {
  HomeCopyItemsOperation? copyItems,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _testApp(
      HomeScreen(
        now: () => _today,
        languageCode: 'en',
        loadItems: (date) =>
            EntriesRepository.instance.fetchItemsForDateInDatabase(db, date),
        loadProfile: (_) async => _profile,
        copyItems: copyItems,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _testApp(
  Widget home, {
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(useMaterial3: true),
    home: home,
  );
}

Future<void> _pumpRoute(WidgetTester tester, Widget route) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    _testApp(const SizedBox.shrink(), navigatorKey: navigatorKey),
  );
  await tester.pump();
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => route),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<int> _createFood(Database db, String name) {
  return FoodLibraryService.instance.createFoodInDatabase(
    db,
    name: name,
    standardUnit: 'g',
    standardUnitAmount: 100,
    standardCalories: 100,
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
  );
}

Map<String, MetabolicProfile?> _profilesForRange(
  DateTime startDate,
  DateTime endDate,
) {
  final profiles = <String, MetabolicProfile?>{};
  for (var date = DateUtils.dateOnly(startDate);
      !date.isAfter(DateUtils.dateOnly(endDate));
      date = DateUtils.addDaysToDate(date, 1)) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    profiles['${date.year}-$month-$day'] = _profile;
  }
  return profiles;
}
