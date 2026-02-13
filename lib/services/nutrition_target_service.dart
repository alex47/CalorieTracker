import '../models/daily_targets.dart';
import '../models/metabolic_profile.dart';
import 'calorie_deficit_service.dart';

class NutritionTargetService {
  NutritionTargetService._();

  static DailyTargets targetsFromProfile(MetabolicProfile profile) {
    final maintenanceCalories = CalorieDeficitService.maintenanceCalories(profile);
    final proteinRatio = profile.proteinRatioPercent / 100.0;
    final fatRatio = profile.fatRatioPercent / 100.0;
    final carbsRatio = profile.carbsRatioPercent / 100.0;
    return targetsFromCalories(
      maintenanceCalories,
      proteinRatio: proteinRatio,
      fatRatio: fatRatio,
      carbsRatio: carbsRatio,
    );
  }

  static DailyTargets targetsFromCalories(
    int calories, {
    required double proteinRatio,
    required double fatRatio,
    required double carbsRatio,
  }) {
    final proteinGrams = ((calories * proteinRatio) / 4).round();
    final fatGrams = ((calories * fatRatio) / 9).round();
    final carbsGrams = ((calories * carbsRatio) / 4).round();
    return DailyTargets(
      calories: calories,
      fat: fatGrams,
      protein: proteinGrams,
      carbs: carbsGrams,
    );
  }
}
