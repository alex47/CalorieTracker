import 'dart:async';

import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/screens/weekly_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_test_app.dart';

void main() {
  group('WeeklySummaryScreen states', () {
    testWidgets('shows loading and then an empty completed week',
        (tester) async {
      final items = Completer<List<FoodItem>>();
      await _pumpWeekly(
        tester,
        loadItems: (_) => items.future,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      items.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('July 13 - July 19'), findsOneWidget);
      expect(find.text('No entries for this week.'), findsOneWidget);
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('shows load failures and remains refreshable', (tester) async {
      await _pumpWeekly(
        tester,
        loadItems: (_) async => throw StateError('week failed'),
        settle: true,
      );

      expect(find.text('Failed to load entries.'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('renders the current week on a narrow viewport',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpWeekly(
        tester,
        anchorDate: DateTime(2026, 7, 20),
        loadItems: (_) async => [],
        settle: true,
        setDefaultViewport: false,
      );

      expect(find.text('July 20 - July 26'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('WeeklySummaryScreen calculations and paging', () {
    testWidgets('shows a complete Monday-Sunday week with actual deficits',
        (tester) async {
      await _pumpWeekly(
        tester,
        loadItems: (_) async => [_food(calories: 1000)],
        settle: true,
      );

      expect(find.text('July 13 - July 19'), findsOneWidget);
      expect(find.text('5460 kcal'), findsOneWidget);
      expect(find.text('780 kcal'), findsNWidgets(7));
      expect(find.textContaining('* Estimated'), findsNothing);
    });

    testWidgets(
        'marks missing days estimated but keeps zero-calorie days actual',
        (tester) async {
      await _pumpWeekly(
        tester,
        loadItems: (date) async {
          if (date.day == 13) {
            return [_food(calories: 1000)];
          }
          if (date.day == 14) {
            return [_food(calories: 0)];
          }
          return [];
        },
        settle: true,
      );

      expect(find.text('8960 kcal*'), findsOneWidget);
      expect(find.text('780 kcal'), findsOneWidget);
      expect(find.text('1780 kcal'), findsOneWidget);
      expect(find.text('1280 kcal*'), findsNWidgets(5));
      expect(
        find.text('* Estimated from the average of logged days.'),
        findsOneWidget,
      );
    });

    testWidgets('pages to current week, blocks future days, and returns today',
        (tester) async {
      final selectedDays = <DateTime>[];
      await _pumpWeekly(
        tester,
        loadItems: (_) async => [],
        onDaySelected: selectedDays.add,
        settle: true,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('July 20 - July 26'), findsOneWidget);
      expect(find.text('5460 kcal'), findsNothing);

      await tester.tap(find.text('Monday'));
      await tester.pump();
      expect(selectedDays, [DateTime(2026, 7, 20)]);

      await tester.tap(find.text('Tuesday'));
      await tester.pump();
      expect(selectedDays, hasLength(1));

      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('July 20 - July 26'), findsOneWidget);
    });

    testWidgets('pull-to-refresh reloads all seven days', (tester) async {
      var loadCount = 0;
      await _pumpWeekly(
        tester,
        loadItems: (_) async {
          loadCount += 1;
          return [];
        },
        settle: true,
      );
      expect(loadCount, 7);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 600),
        1000,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(loadCount, 14);
    });
  });
}

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

final _today = DateTime(2026, 7, 20, 12);

Future<void> _pumpWeekly(
  WidgetTester tester, {
  DateTime? anchorDate,
  required WeeklyItemsLoadOperation loadItems,
  ValueChanged<DateTime>? onDaySelected,
  bool settle = false,
  bool setDefaultViewport = true,
}) async {
  if (setDefaultViewport) {
    await _setViewport(tester, const Size(900, 1400));
  }
  await tester.pumpWidget(
    localizedTestApp(
      home: WeeklySummaryScreen(
        anchorDate: anchorDate ?? DateTime(2026, 7, 13),
        now: () => _today,
        languageCode: 'en',
        loadItems: loadItems,
        loadProfiles: ({
          required startDate,
          required endDate,
        }) async {
          final profiles = <String, MetabolicProfile?>{};
          for (var date = DateUtils.dateOnly(startDate);
              !date.isAfter(DateUtils.dateOnly(endDate));
              date = DateUtils.addDaysToDate(date, 1)) {
            profiles[_dateKey(date)] = _profile;
          }
          return profiles;
        },
        onDaySelected: onDaySelected,
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

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

FoodItem _food({required int calories}) {
  return FoodItem(
    id: 1,
    entryId: 1,
    foodId: 1,
    name: 'Logged food',
    amount: '1 serving',
    calories: calories,
    fat: 1,
    protein: 2,
    carbs: 3,
    standardUnit: 'serving',
    standardUnitAmount: 1,
    multiplier: 1,
    standardCalories: calories.toDouble(),
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
  );
}
