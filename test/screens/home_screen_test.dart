import 'dart:async';

import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/models/metric_type.dart';
import 'package:calorie_tracker/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_test_app.dart';

void main() {
  group('HomeScreen states', () {
    testWidgets('shows loading and then the empty state', (tester) async {
      final items = Completer<List<FoodItem>>();
      await _pumpHome(
        tester,
        loadItems: (_) => items.future,
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      items.complete([]);
      await tester.pumpAndSettle();

      expect(
        find.text('No entries for this day yet. Tap Add to log food.'),
        findsOneWidget,
      );
      expect(_button('Summarize').onPressed, isNull);
    });

    testWidgets('shows item-load failures in totals and the food table',
        (tester) async {
      await _pumpHome(
        tester,
        loadItems: (_) async => throw StateError('load failed'),
        settle: true,
      );

      expect(find.text('Failed to load daily totals.'), findsOneWidget);
      expect(find.text('Failed to load entries.'), findsOneWidget);
    });

    testWidgets('shows populated foods and the missing-target state',
        (tester) async {
      await _pumpHome(
        tester,
        loadItems: (_) async => [_food(1, 'Apple')],
        loadProfile: (_) async => null,
        settle: true,
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(
        find.text('Set your metabolic profile to track calorie deficit.'),
        findsOneWidget,
      );
      expect(_button('Summarize').onPressed, isNotNull);
    });

    for (final viewport in [
      (name: 'phone', size: const Size(390, 844)),
      (name: 'Linux desktop', size: const Size(1440, 900)),
    ]) {
      testWidgets('renders populated state at ${viewport.name} size',
          (tester) async {
        await _setViewport(tester, viewport.size);
        await _pumpHome(
          tester,
          loadItems: (_) async => [
            _food(1, 'Apple'),
            _food(2, 'Chicken breast'),
          ],
          settle: true,
          setDefaultViewport: false,
        );

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Chicken breast'), findsOneWidget);
        expect(find.text('Calories'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('HomeScreen dates and selection', () {
    testWidgets('long press enters selection and taps toggle until exit',
        (tester) async {
      await _pumpHome(
        tester,
        loadItems: (_) async => [
          _food(1, 'Apple'),
          _food(2, 'Banana'),
        ],
        settle: true,
      );

      await tester.longPress(find.text('Apple'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Copy to today'), findsOneWidget);
      expect(_button('Copy to today').onPressed, isNull);

      await tester.tap(find.text('Banana'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Apple'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Banana'));
      await tester.pump();
      expect(find.text('Calorie Tracker'), findsOneWidget);
      expect(find.text('Copy to today'), findsNothing);
    });

    testWidgets('selection and back behavior follow page changes',
        (tester) async {
      await _pumpHome(
        tester,
        loadItems: (date) async => [
          _food(
            1,
            date.day == _today.day ? 'Today food' : 'Previous food',
          ),
        ],
        settle: true,
      );

      await tester.longPress(find.text('Today food'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('July 20, 2026'), findsOneWidget);

      await tester.longPress(find.text('Today food'));
      await tester.pump();
      await _swipeToPreviousDay(tester);
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('July 19, 2026'), findsOneWidget);
      expect(find.text('Previous food'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('July 20, 2026'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('July 20, 2026'), findsOneWidget);
    });

    testWidgets('weekly date returns jump to past and clamp future to today',
        (tester) async {
      final returnedDates = <DateTime>[
        DateTime(2026, 7, 18),
        DateTime(2026, 7, 21),
      ];
      final anchors = <DateTime>[];
      await _pumpHome(
        tester,
        loadItems: (_) async => [],
        openWeeklySummary: (anchor) async {
          anchors.add(anchor);
          return returnedDates.removeAt(0);
        },
        settle: true,
      );

      await tester.tap(find.text('July 20, 2026'));
      await tester.pumpAndSettle();
      expect(find.text('July 18, 2026'), findsOneWidget);

      await tester.tap(find.text('July 18, 2026'));
      await tester.pumpAndSettle();
      expect(find.text('July 20, 2026'), findsOneWidget);
      expect(anchors.map((date) => date.day), [20, 18]);
    });
  });

  group('HomeScreen bulk actions', () {
    testWidgets('copies selected foods with a busy state and jumps to today',
        (tester) async {
      final copyCompleter = Completer<void>();
      List<FoodItem>? copiedItems;
      DateTime? copiedDate;
      var todayLoads = 0;
      await _pumpHome(
        tester,
        loadItems: (date) async {
          if (date.day == _today.day) {
            todayLoads += 1;
            return [_food(9, 'Today food')];
          }
          return [_food(1, 'Apple'), _food(2, 'Banana')];
        },
        copyItems: ({required items, required date}) {
          copiedItems = items.toList(growable: false);
          copiedDate = date;
          return copyCompleter.future;
        },
        settle: true,
      );
      await _swipeToPreviousDay(tester);
      await tester.longPress(find.text('Apple'));
      await tester.longPress(find.text('Banana'));
      await tester.pump();

      await tester.tap(find.text('Copy to today'));
      await tester.pump();

      expect(copiedItems?.map((item) => item.id), [1, 2]);
      expect(copiedDate, _today);
      expect(_button('Copy to today').onPressed, isNull);
      expect(
        find.descendant(
          of: _buttonFinder('Copy to today'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      copyCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('July 20, 2026'), findsOneWidget);
      expect(find.text('2 selected'), findsNothing);
      expect(todayLoads, greaterThanOrEqualTo(2));
      expect(find.textContaining('Copied'), findsNothing);
    });

    testWidgets('copy failure stays on the source day and retains selection',
        (tester) async {
      await _pumpHome(
        tester,
        loadItems: (date) async =>
            date.day == _today.day ? [] : [_food(1, 'Apple')],
        copyItems: ({required items, required date}) async {
          throw StateError('copy failed');
        },
        settle: true,
      );
      await _swipeToPreviousDay(tester);
      await tester.longPress(find.text('Apple'));
      await tester.tap(find.text('Copy to today'));
      await tester.pumpAndSettle();

      expect(find.text('July 19, 2026'), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      expect(
        find.textContaining('Failed to copy selected items.'),
        findsOneWidget,
      );
      expect(_button('Copy to today').onPressed, isNotNull);
    });

    testWidgets('confirms deletion, shows busy state, reloads, and succeeds',
        (tester) async {
      final deleteCompleter = Completer<void>();
      var previousItems = [_food(1, 'Apple'), _food(2, 'Banana')];
      List<int>? deletedIds;
      var previousLoads = 0;
      await _pumpHome(
        tester,
        loadItems: (date) async {
          if (date.day == _today.day) {
            return [];
          }
          previousLoads += 1;
          return List<FoodItem>.from(previousItems);
        },
        deleteItems: ({required itemIds}) async {
          deletedIds = itemIds.toList(growable: false);
          await deleteCompleter.future;
          previousItems = [];
        },
        settle: true,
      );
      await _swipeToPreviousDay(tester);
      await tester.longPress(find.text('Apple'));
      await tester.longPress(find.text('Banana'));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete selected items'), findsOneWidget);
      expect(find.text('Delete 2 selected food items?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletedIds, isNull);
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pump();

      expect(deletedIds, [1, 2]);
      expect(_button('Delete').onPressed, isNull);
      deleteCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsNothing);
      expect(find.text('Deleted 2 items.'), findsOneWidget);
      expect(
        find.text('No entries for this day yet. Tap Add to log food.'),
        findsOneWidget,
      );
      expect(previousLoads, greaterThanOrEqualTo(2));
    });

    testWidgets('delete failure clears busy state and retains selection',
        (tester) async {
      await _pumpHome(
        tester,
        loadItems: (_) async => [_food(1, 'Apple')],
        deleteItems: ({required itemIds}) async {
          throw StateError('delete failed');
        },
        settle: true,
      );
      await tester.longPress(find.text('Apple'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(
        find.textContaining('Failed to delete selected items.'),
        findsOneWidget,
      );
      expect(_button('Delete').onPressed, isNotNull);
    });
  });

  testWidgets('routes every primary navigation action through its callback',
      (tester) async {
    FoodItem? openedFood;
    DateTime? addDate;
    DateTime? metricDate;
    MetricType? metricType;
    DateTime? weeklyDate;
    DateTime? summaryDate;
    await _pumpHome(
      tester,
      loadItems: (_) async => [_food(1, 'Apple')],
      openFoodDetails: (item, date) async {
        openedFood = item;
        return null;
      },
      openAdd: (date) async => addDate = date,
      openMetricDetails: (date, metric) async {
        metricDate = date;
        metricType = metric;
      },
      openWeeklySummary: (date) async {
        weeklyDate = date;
        return null;
      },
      openDaySummary: (date) async => summaryDate = date,
      settle: true,
    );

    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(openedFood?.id, 1);

    await tester.tap(find.text('Calories').first);
    await tester.pump();
    expect(metricDate, isNotNull);
    expect(metricType, MetricType.calories);

    await tester.tap(find.text('July 20, 2026'));
    await tester.pumpAndSettle();
    expect(weeklyDate, isNotNull);

    await tester.tap(find.text('Summarize'));
    await tester.pump();
    expect(summaryDate, isNotNull);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(addDate, isNotNull);
    for (final date in [metricDate!, weeklyDate!, summaryDate!, addDate!]) {
      expect(DateUtils.dateOnly(date), DateUtils.dateOnly(_today));
    }
  });
}

const _profile = MetabolicProfile(
  age: 30,
  sex: 'male',
  heightCm: 180,
  weightKg: 80,
  activityLevel: 'moderate',
  fatRatioPercent: 30,
  proteinRatioPercent: 20,
  carbsRatioPercent: 50,
);

final _today = DateTime(2026, 7, 20, 12);

Future<void> _pumpHome(
  WidgetTester tester, {
  required HomeItemsLoadOperation loadItems,
  HomeProfileLoadOperation? loadProfile,
  HomeCopyItemsOperation? copyItems,
  HomeDeleteItemsOperation? deleteItems,
  HomeFoodDetailsOperation? openFoodDetails,
  HomeDateNavigationOperation? openAdd,
  HomeMetricNavigationOperation? openMetricDetails,
  HomeWeeklyNavigationOperation? openWeeklySummary,
  HomeDateNavigationOperation? openDaySummary,
  bool settle = false,
  bool setDefaultViewport = true,
}) async {
  if (setDefaultViewport) {
    await _setViewport(tester, const Size(900, 1400));
  }
  await tester.pumpWidget(
    localizedTestApp(
      home: HomeScreen(
        now: () => _today,
        languageCode: 'en',
        loadItems: loadItems,
        loadProfile: loadProfile ?? (_) async => _profile,
        copyItems: copyItems,
        deleteItems: deleteItems,
        openFoodDetails: openFoodDetails,
        openAdd: openAdd,
        openMetricDetails: openMetricDetails,
        openWeeklySummary: openWeeklySummary,
        openDaySummary: openDaySummary,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _swipeToPreviousDay(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(700, 0));
  await tester.pumpAndSettle();
  expect(find.text('July 19, 2026'), findsOneWidget);
}

Finder _buttonFinder(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      )
      .first;
}

ButtonStyleButton _button(String label) {
  return _buttonFinder(label).evaluate().single.widget as ButtonStyleButton;
}

FoodItem _food(int id, String name) {
  return FoodItem(
    id: id,
    entryId: 1,
    foodId: id,
    name: name,
    amount: '100 g',
    calories: 100,
    fat: 1,
    protein: 2,
    carbs: 3,
    standardUnit: 'g',
    standardUnitAmount: 100,
    multiplier: 100,
    standardCalories: 100,
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
  );
}
