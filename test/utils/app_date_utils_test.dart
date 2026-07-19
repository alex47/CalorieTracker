import 'package:calorie_tracker/utils/app_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendarDaysBetween', () {
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
}
