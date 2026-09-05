import 'dart:async';

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
      expect(find.text('Recently added'), findsNothing);
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
          loadRecentFoods: () async => [],
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

      expect(find.text('Recently added'), findsNothing);
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
          loadRecentFoods: () async => [],
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

    for (final viewport in [const Size(360, 640), const Size(900, 1400)]) {
      for (final language in ['en', 'hu']) {
        testWidgets('recent foods add with defaults at $viewport in $language',
            (tester) async {
          final foods = List.generate(5, (i) => _food(i + 1, 'Food ${i + 1}'));
          DateTime? addedDate;
          int? addedId;
          double? quantity;
          bool? routeResult;
          await _openAddEntry(
            tester,
            viewport: viewport,
            locale: Locale(language),
            onResult: (result) => routeResult = result,
            screen: AddEntryScreen(
              date: DateTime(2026, 7, 18),
              loadFoods: ({required searchQuery, required visibleOnly}) async =>
                  foods,
              loadRecentFoods: () async => foods.reversed.toList(),
              addExistingFood: (
                  {required date, required foodId, required multiplier}) async {
                addedDate = date;
                addedId = foodId;
                quantity = multiplier;
              },
            ),
          );
          expect(tester.takeException(), isNull);
          final heading = find.text(language == 'en'
              ? 'Recently added'
              : 'Legutóbb hozzáadott ételek');
          expect(heading, findsOneWidget);
          expect(tester.getTopLeft(heading).dy,
              lessThan(tester.getTopLeft(find.byType(TextField)).dy));
          final recentFood = find.text('Food 5').first;
          await tester.ensureVisible(recentFood);
          await tester.tap(recentFood);
          await tester.pumpAndSettle();
          expect(addedDate, DateTime(2026, 7, 18));
          expect(addedId, 5);
          expect(quantity, 100);
          expect(routeResult, isTrue);
        });
      }
    }

    testWidgets(
        'search filters the full list while recent foods remain available',
        (tester) async {
      var recentLoads = 0;
      await _openAddEntry(
        tester,
        screen: AddEntryScreen(
          loadRecentFoods: () async {
            recentLoads++;
            return [_food(1, 'Apple')];
          },
          loadFoods: ({required searchQuery, required visibleOnly}) async => [
            _food(1, 'Apple'),
            _food(2, 'Banana')
          ]
              .where((food) => food.name.toLowerCase().contains(searchQuery))
              .toList(),
        ),
      );
      expect(find.text('Apple'), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'banana');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(recentLoads, 1);
    });

    testWidgets(
        'recent load failures can retry while the regular list is usable',
        (tester) async {
      var attempts = 0;
      final pending = Completer<List<FoodDefinition>>();
      await _openAddEntry(
        tester,
        screen: AddEntryScreen(
          loadFoods: _singleFoodLoader,
          loadRecentFoods: () {
            attempts++;
            return attempts == 1
                ? Future.error(StateError('load failed'))
                : pending.future;
          },
        ),
      );
      expect(find.text('Apple'), findsOneWidget);
      await tester.tap(find.text('Could not load recent foods. Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete([_food(1, 'Apple')]);
      await tester.pumpAndSettle();
      expect(find.text('Recently added'), findsOneWidget);
      expect(find.text('Apple'), findsNWidgets(2));
      expect(attempts, 2);
    });

    testWidgets('a failed recent add follows the same error and reload path',
        (tester) async {
      var recentLoads = 0;
      await _openAddEntry(
        tester,
        screen: AddEntryScreen(
          loadFoods: _singleFoodLoader,
          loadRecentFoods: () async {
            recentLoads++;
            return [_food(1, 'Apple')];
          },
          addExistingFood: (
              {required date, required foodId, required multiplier}) async {
            throw StateError('add failed');
          },
        ),
      );
      await tester.tap(find.text('Apple').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('add failed'), findsOneWidget);
      expect(find.text('Recently added'), findsOneWidget);
      expect(recentLoads, 2);
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
          loadRecentFoods: () async => [],
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
  Size viewport = const Size(900, 1400),
  Locale locale = const Locale('en'),
}) async {
  await _setViewport(tester);
  tester.view.physicalSize = viewport;
  await tester.pumpWidget(
    localizedTestApp(
      locale: locale,
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
