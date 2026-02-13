import '../models/daily_targets.dart';
import '../models/metabolic_profile.dart';
import 'calorie_deficit_service.dart';

class MacroRatioConfig {
  const MacroRatioConfig({
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final double protein;
  final double fat;
  final double carbs;

  static const MacroRatioConfig placeholder = MacroRatioConfig(
    protein: 0.30,
    fat: 0.30,
    carbs: 0.40,
  );
}

class NutritionTargetService {
  NutritionTargetService._();

  static const MacroRatioConfig macroRatios = MacroRatioConfig.placeholder;

  static DailyTargets targetsFromProfile(MetabolicProfile profile) {
    final maintenanceCalories = CalorieDeficitService.maintenanceCalories(profile);
    return targetsFromCalories(maintenanceCalories);
  }

  static DailyTargets targetsFromCalories(int calories) {
    final proteinGrams = ((calories * macroRatios.protein) / 4).round();
    final fatGrams = ((calories * macroRatios.fat) / 9).round();
    final carbsGrams = ((calories * macroRatios.carbs) / 4).round();
    return DailyTargets(
      calories: calories,
      fat: fatGrams,
      protein: proteinGrams,
      carbs: carbsGrams,
    );
  }
}
