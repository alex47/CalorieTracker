import 'app_settings.dart';

class DailyGoals {
  const DailyGoals({
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
  });

  final int calories;
  final int fat;
  final int protein;
  final int carbs;

  factory DailyGoals.fromSettings(AppSettings settings) {
    return DailyGoals(
      calories: settings.dailyGoal,
      fat: settings.dailyFatGoal,
      protein: settings.dailyProteinGoal,
      carbs: settings.dailyCarbsGoal,
    );
  }
}
