import 'package:calorie_tracker/models/food_definition.dart';
import 'package:calorie_tracker/screens/add_entry_screen.dart';
import 'package:calorie_tracker/screens/foods_screen.dart';
import 'package:calorie_tracker/widgets/food_library_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_test_app.dart';

void main() {
  group('FoodsScreen', () {
    testWidgets('searches visible foods and refreshes on demand',
        (tester) async {
      final queries = <String>[];
      final visibleFlags = <bool>[];
      final foods = [_food(1, 'Apple'), _food(2, 'Banana')];
      await _pumpFoods(
        tester,
        loadFoods: ({required searchQuery, required visibleOnly}) async {
          queries.add(searchQuery);
          visibleFlags.add(visibleOnly);
          return foods
              .where(
                (food) =>
                    food.name.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .toList();
        },
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'app');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
      expect(queries.last, 'app');
      expect(visibleFlags, everyElement(isTrue));

      final callsBeforeRefresh = queries.length;
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pumpAndSettle();
      expect(queries.length, callsBeforeRefresh + 1);
      expect(queries.last, 'app');

      await tester.enterText(find.byType(TextField), 'pear');
      await tester.pumpAndSettle();
      expect(find.text('No foods found.'), findsOneWidget);
    });

    testWidgets('selects multiple foods, merges them, and reloads',
        (tester) async {
      var loadCount = 0;
      List<FoodDefinition>? mergedFoods;
      await _pumpFoods(
        tester,
        loadFoods: ({required searchQuery, required visibleOnly}) async {
          loadCount += 1;
          return [_food(1, 'Apple'), _food(2, 'Banana')];
        },
        openMerge: (foods) async {
          mergedFoods = foods;
          return true;
        },
      );

      await tester.longPress(find.text('Apple'));
      await tester.longPress(find.text('Banana'));
      await tester.pump();
      expect(find.byTooltip('Merge foods'), findsOneWidget);

      await tester.tap(find.byTooltip('Merge foods'));
      await tester.pumpAndSettle();
      expect(mergedFoods?.map((food) => food.id), [1, 2]);
      expect(find.byTooltip('Merge foods'), findsNothing);
      expect(loadCount, 2);
    });

    testWidgets('back clears selection and editor results control refresh',
        (tester) async {
      var loadCount = 0;
      final editedFoods = <FoodDefinition?>[];
      var editorChanged = false;
      await _pumpFoods(
        tester,
        loadFoods: ({required searchQuery, required visibleOnly}) async {
          loadCount += 1;
          return [_food(1, 'Apple'), _food(2, 'Banana')];
        },
        openFoodEditor: (food) async {
          editedFoods.add(food);
          return editorChanged;
        },
      );

      await tester.longPress(find.text('Apple'));
      await tester.longPress(find.text('Banana'));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byTooltip('Merge foods'), findsNothing);

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(editedFoods.single?.id, 1);
      expect(loadCount, 1);

      editorChanged = true;
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(editedFoods.last, isNull);
      expect(loadCount, 2);
    });
  });

  group('AddEntryScreen', () {
    testWidgets('adds an existing food with its standard amount and returns',
        (tester) async {
      bool? routeResult;
      DateTime? addedDate;
      int? addedFoodId;
      double? addedMultiplier;
      await _openAddEntry(
        tester,
        onResult: (result) => routeResult = result,
        screen: AddEntryScreen(
          date: DateTime(2026, 7, 19),
          loadFoods: _singleFoodLoader,
          addExistingFood: ({
            required date,
            required foodId,
            required multiplier,
          }) async {
            addedDate = date;
            addedFoodId = foodId;
            addedMultiplier = multiplier;
          },
        ),
      );

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      expect(routeResult, isTrue);
      expect(DateUtils.dateOnly(addedDate!), DateTime(2026, 7, 19));
      expect(addedFoodId, 1);
      expect(addedMultiplier, 100);
      expect(find.text('Open add entry'), findsOneWidget);
    });

    testWidgets('shows add failures, reloads, and remains on screen',
        (tester) async {
      var loadCount = 0;
      await _openAddEntry(
        tester,
        screen: AddEntryScreen(
          date: DateTime(2026, 7, 19),
          loadFoods: ({required searchQuery, required visibleOnly}) async {
            loadCount += 1;
            return [_food(1, 'Apple')];
          },
          addExistingFood: ({
            required date,
            required foodId,
            required multiplier,
          }) async {
            throw StateError('add failed');
          },
        ),
      );

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      expect(find.textContaining('add failed'), findsOneWidget);
      expect(find.text('Add food'), findsOneWidget);
      expect(loadCount, 2);
    });

    testWidgets('returns only when add-new reports a saved food',
        (tester) async {
      bool? routeResult;
      var shouldReturnSaved = false;
      final openedDates = <DateTime>[];
      await _openAddEntry(
        tester,
        onResult: (result) => routeResult = result,
        screen: AddEntryScreen(
          date: DateTime(2026, 7, 18),
          loadFoods: _singleFoodLoader,
          openAddNew: (date) async {
            openedDates.add(date);
            return shouldReturnSaved;
          },
        ),
      );

      await tester.tap(find.text('Add new'));
      await tester.pumpAndSettle();
      expect(routeResult, isNull);
      expect(find.text('Add food'), findsOneWidget);

      shouldReturnSaved = true;
      await tester.tap(find.text('Add new'));
      await tester.pumpAndSettle();
      expect(routeResult, isTrue);
      expect(openedDates.map(DateUtils.dateOnly), [
        DateTime(2026, 7, 18),
        DateTime(2026, 7, 18),
      ]);
    });
  });
}

Future<void> _pumpFoods(
  WidgetTester tester, {
  required FoodLibraryLoadOperation loadFoods,
  FoodEditorOperation? openFoodEditor,
  FoodMergeNavigationOperation? openMerge,
}) async {
  await _setViewport(tester);
  await tester.pumpWidget(
    localizedTestApp(
      home: FoodsScreen(
        loadFoods: loadFoods,
        openFoodEditor: openFoodEditor,
        openMerge: openMerge,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAddEntry(
  WidgetTester tester, {
  required AddEntryScreen screen,
  ValueChanged<bool?>? onResult,
}) async {
  await _setViewport(tester);
  await tester.pumpWidget(
    localizedTestApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => screen),
                );
                onResult?.call(result);
              },
              child: const Text('Open add entry'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open add entry'));
  await tester.pumpAndSettle();
}

Future<List<FoodDefinition>> _singleFoodLoader({
  required String searchQuery,
  required bool visibleOnly,
}) async {
  return [_food(1, 'Apple')];
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

FoodDefinition _food(int id, String name) {
  return FoodDefinition(
    id: id,
    name: name,
    standardUnit: 'g',
    standardUnitAmount: 100,
    standardCalories: 100,
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
    createdAtIso: '2026-01-01T00:00:00.000',
    updatedAtIso: '2026-01-01T00:00:00.000',
    isVisibleInLibrary: true,
    usageCount: id,
  );
}
