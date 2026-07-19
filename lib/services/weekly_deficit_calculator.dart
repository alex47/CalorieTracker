import '../utils/app_date_utils.dart';

class WeeklyDeficitDay {
  const WeeklyDeficitDay({
    required this.date,
    required this.calorieTarget,
    required this.itemCount,
    required this.calories,
  });

  final DateTime date;
  final int? calorieTarget;
  final int itemCount;
  final int calories;
}

class ResolvedDailyDeficit {
  const ResolvedDailyDeficit({
    required this.value,
    required this.estimated,
  });

  final int value;
  final bool estimated;
}

class WeeklyDeficitCalculator {
  WeeklyDeficitCalculator._();

  static List<ResolvedDailyDeficit?>? resolveDailyDeficits({
    required List<WeeklyDeficitDay> days,
    required DateTime today,
  }) {
    final todayDay = AppDateUtils.dayOnly(today);
    final observedDeficits = days
        .where((day) {
          final date = AppDateUtils.dayOnly(day.date);
          return date.isBefore(todayDay) &&
              day.itemCount > 0 &&
              day.calorieTarget != null;
        })
        .map((day) => day.calorieTarget! - day.calories)
        .toList(growable: false);
    if (observedDeficits.isEmpty) {
      return null;
    }

    final average =
        observedDeficits.reduce((a, b) => a + b) / observedDeficits.length;
    return days.map((day) {
      final date = AppDateUtils.dayOnly(day.date);
      if (date.isAfter(todayDay)) {
        return null;
      }

      final hasActualDeficit = day.itemCount > 0 && day.calorieTarget != null;
      if (hasActualDeficit) {
        return ResolvedDailyDeficit(
          value: day.calorieTarget! - day.calories,
          estimated: false,
        );
      }
      if (date.isAtSameMomentAs(todayDay)) {
        return null;
      }
      return ResolvedDailyDeficit(
        value: average.round(),
        estimated: true,
      );
    }).toList(growable: false);
  }
}
