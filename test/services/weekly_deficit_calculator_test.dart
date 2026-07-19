import 'package:calorie_tracker/services/weekly_deficit_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeeklyDeficitCalculator', () {
    test('estimates missing completed-week days from logged-day average', () {
      final deficits = WeeklyDeficitCalculator.resolveDailyDeficits(
        days: [
          _day(DateTime(2026, 7, 13), calories: 1500, itemCount: 1),
          _day(DateTime(2026, 7, 14), calories: 1700, itemCount: 1),
          for (var day = 15; day <= 19; day++) _day(DateTime(2026, 7, day)),
        ],
        today: DateTime(2026, 7, 20),
      );

      expect(
        deficits?.map((deficit) => deficit?.value),
        [500, 300, 400, 400, 400, 400, 400],
      );
      expect(
        deficits?.map((deficit) => deficit?.estimated),
        [false, false, true, true, true, true, true],
      );
      expect(
        deficits
            ?.whereType<ResolvedDailyDeficit>()
            .fold<int>(0, (sum, deficit) => sum + deficit.value),
        2800,
      );
    });

    test('treats a zero-calorie food entry as logged, not estimated', () {
      final deficits = WeeklyDeficitCalculator.resolveDailyDeficits(
        days: [
          _day(DateTime(2026, 7, 13), calories: 1500, itemCount: 1),
          _day(DateTime(2026, 7, 14), calories: 0, itemCount: 1),
          _day(DateTime(2026, 7, 15)),
        ],
        today: DateTime(2026, 7, 20),
      );

      expect(deficits?[0]?.value, 500);
      expect(deficits?[0]?.estimated, isFalse);
      expect(deficits?[1]?.value, 2000);
      expect(deficits?[1]?.estimated, isFalse);
      expect(deficits?[2]?.value, 1250);
      expect(deficits?[2]?.estimated, isTrue);
    });

    test('returns no result without a logged past day', () {
      final deficits = WeeklyDeficitCalculator.resolveDailyDeficits(
        days: [
          _day(DateTime(2026, 7, 13)),
          _day(DateTime(2026, 7, 14)),
        ],
        today: DateTime(2026, 7, 20),
      );

      expect(deficits, isNull);
    });

    test('does not estimate today or future days', () {
      final deficits = WeeklyDeficitCalculator.resolveDailyDeficits(
        days: [
          _day(DateTime(2026, 7, 18), calories: 1500, itemCount: 1),
          _day(DateTime(2026, 7, 19)),
          _day(DateTime(2026, 7, 20)),
          _day(DateTime(2026, 7, 21), calories: 1500, itemCount: 1),
        ],
        today: DateTime(2026, 7, 20),
      );

      expect(deficits?[0]?.value, 500);
      expect(deficits?[1]?.value, 500);
      expect(deficits?[1]?.estimated, isTrue);
      expect(deficits?[2], isNull);
      expect(deficits?[3], isNull);
    });
  });
}

WeeklyDeficitDay _day(
  DateTime date, {
  int calorieTarget = 2000,
  int itemCount = 0,
  int calories = 0,
}) {
  return WeeklyDeficitDay(
    date: date,
    calorieTarget: calorieTarget,
    itemCount: itemCount,
    calories: calories,
  );
}
