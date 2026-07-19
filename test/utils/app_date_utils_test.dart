import 'package:calorie_tracker/utils/app_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendar day helpers', () {
    test('dayOnly removes the time component', () {
      expect(
        AppDateUtils.dayOnly(DateTime(2026, 7, 19, 23, 59, 58)),
        DateTime(2026, 7, 19),
      );
    });

    test('addCalendarDays crosses leap-day and month boundaries', () {
      expect(
        AppDateUtils.addCalendarDays(DateTime(2024, 2, 28, 18), 1),
        DateTime(2024, 2, 29),
      );
      expect(
        AppDateUtils.addCalendarDays(DateTime(2024, 2, 29), 1),
        DateTime(2024, 3, 1),
      );
      expect(
        AppDateUtils.addCalendarDays(DateTime(2025, 3, 1), -1),
        DateTime(2025, 2, 28),
      );
    });

    test('addCalendarDays crosses year boundaries in both directions', () {
      expect(
        AppDateUtils.addCalendarDays(DateTime(2025, 12, 31), 1),
        DateTime(2026),
      );
      expect(
        AppDateUtils.addCalendarDays(DateTime(2026), -1),
        DateTime(2025, 12, 31),
      );
    });
  });

  group('Monday-based weeks', () {
    test('returns the same day for Monday and previous Monday for Sunday', () {
      expect(
        AppDateUtils.startOfWeekMonday(DateTime(2026, 7, 13, 12)),
        DateTime(2026, 7, 13),
      );
      expect(
        AppDateUtils.startOfWeekMonday(DateTime(2026, 7, 19, 23)),
        DateTime(2026, 7, 13),
      );
    });

    test('week starts cross month and year boundaries', () {
      expect(
        AppDateUtils.startOfWeekMonday(DateTime(2026, 1, 1)),
        DateTime(2025, 12, 29),
      );
      expect(
        AppDateUtils.startOfWeekMonday(DateTime(2024, 3, 1)),
        DateTime(2024, 2, 26),
      );
    });

    test('counts whole calendar weeks from normalized Monday dates', () {
      expect(
        AppDateUtils.calendarWeeksBetween(
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 12),
        ),
        2,
      );
      expect(
        AppDateUtils.calendarWeeksBetween(
          DateTime(2026, 1, 12),
          DateTime(2025, 12, 31),
        ),
        -2,
      );
      expect(
        AppDateUtils.calendarWeeksBetween(
          DateTime(2026, 7, 13),
          DateTime(2026, 7, 19),
        ),
        0,
      );
    });
  });

  group('calendarDaysBetween', () {
    test('counts across leap day, month, and year boundaries', () {
      expect(
        AppDateUtils.calendarDaysBetween(
          DateTime(2024, 2, 28, 23),
          DateTime(2024, 3, 1, 1),
        ),
        2,
      );
      expect(
        AppDateUtils.calendarDaysBetween(
          DateTime(2025, 12, 31),
          DateTime(2026),
        ),
        1,
      );
    });

    test('counts forward across the Budapest spring DST transition', () {
      final beforeTransition = DateTime(2026, 3, 29);
      final afterTransition = DateTime(2026, 3, 30);

      expect(
        AppDateUtils.calendarDaysBetween(beforeTransition, afterTransition),
        1,
      );
    });

    test('counts backward across the Budapest spring DST transition', () {
      final beforeTransition = DateTime(2026, 3, 29);
      final afterTransition = DateTime(2026, 3, 30);

      expect(
        AppDateUtils.calendarDaysBetween(afterTransition, beforeTransition),
        -1,
      );
    });

    test('counts forward across the Budapest autumn DST transition', () {
      final beforeTransition = DateTime(2026, 10, 25);
      final afterTransition = DateTime(2026, 10, 26);

      expect(
        AppDateUtils.calendarDaysBetween(beforeTransition, afterTransition),
        1,
      );
    });

    test('counts backward across the Budapest autumn DST transition', () {
      final beforeTransition = DateTime(2026, 10, 25);
      final afterTransition = DateTime(2026, 10, 26);

      expect(
        AppDateUtils.calendarDaysBetween(afterTransition, beforeTransition),
        -1,
      );
    });
  });

  group('DST-adjacent calendar addition', () {
    test('moves by calendar date across the spring transition', () {
      expect(
        AppDateUtils.addCalendarDays(DateTime(2026, 3, 29, 23), 1),
        DateTime(2026, 3, 30),
      );
    });

    test('moves by calendar date across the autumn transition', () {
      expect(
        AppDateUtils.addCalendarDays(DateTime(2026, 10, 25, 23), 1),
        DateTime(2026, 10, 26),
      );
    });
  });
}
