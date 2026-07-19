import '../models/daily_targets.dart';
import '../models/food_item.dart';
import '../models/metabolic_profile.dart';
import 'day_summary_service.dart';
import 'macro_ratio_preset_catalog.dart';

class DaySummarySnapshotBuilder {
  DaySummarySnapshotBuilder._();

  static const double maintenanceTolerancePercent = 10;
  static const double macroRatioTolerancePercentagePoints = 5;

  static Map<String, dynamic> build({
    required DateTime date,
    required List<FoodItem> items,
    required MetabolicProfile? profile,
    required DailyTargets? maintenanceBaseline,
    required String languageCode,
  }) {
    final sortedItems = [...items]..sort((a, b) => a.id.compareTo(b.id));
    final calories =
        sortedItems.fold<int>(0, (sum, item) => sum + item.calories);
    final fat = sortedItems.fold<double>(0, (sum, item) => sum + item.fat);
    final protein =
        sortedItems.fold<double>(0, (sum, item) => sum + item.protein);
    final carbs = sortedItems.fold<double>(0, (sum, item) => sum + item.carbs);
    final preset = profile == null
        ? null
        : MacroRatioPresetCatalog.presetForKey(
            MacroRatioPresetCatalog.keyForRatios(
              fatPercent: profile.fatRatioPercent,
              proteinPercent: profile.proteinRatioPercent,
              carbsPercent: profile.carbsRatioPercent,
            ),
          );
    final macroStrategyName = preset == null
        ? null
        : _localizedPresetName(
            presetKey: preset.key,
            languageCode: languageCode,
          );
    final objectiveAdherence = preset == null || maintenanceBaseline == null
        ? null
        : _buildObjectiveAdherence(
            calories: calories,
            fat: fat,
            protein: protein,
            carbs: carbs,
            preset: preset,
            maintenanceBaseline: maintenanceBaseline,
          );

    return {
      'date': DaySummaryService.instance.dayKey(date),
      'language_code': languageCode,
      'entries': sortedItems
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'amount': item.calculatedAmountText,
              'calories': item.calories,
              'fat': item.fat,
              'protein': item.protein,
              'carbs': item.carbs,
              'notes': item.notes,
            },
          )
          .toList(growable: false),
      'totals': {
        'calories': calories,
        'fat': fat,
        'protein': protein,
        'carbs': carbs,
      },
      'metabolic_profile': profile == null
          ? null
          : {
              'age': profile.age,
              'sex': profile.sex,
              'height_cm': profile.heightCm,
              'weight_kg': profile.weightKg,
              'activity_level': profile.activityLevel,
              'fat_ratio_percent': profile.fatRatioPercent,
              'protein_ratio_percent': profile.proteinRatioPercent,
              'carbs_ratio_percent': profile.carbsRatioPercent,
            },
      'nutrition_objective': preset == null
          ? null
          : {
              'macro_strategy_key': preset.key,
              'macro_strategy_name': macroStrategyName,
              'calorie_objective': preset.calorieObjective.key,
            },
      'maintenance_baseline': maintenanceBaseline == null
          ? null
          : {
              'calories': maintenanceBaseline.calories,
              'fat': maintenanceBaseline.fat,
              'protein': maintenanceBaseline.protein,
              'carbs': maintenanceBaseline.carbs,
            },
      'objective_adherence': objectiveAdherence,
    };
  }

  static String _localizedPresetName({
    required String presetKey,
    required String languageCode,
  }) {
    final englishName = MacroRatioPresetCatalog.localizedLabelForLanguageCode(
      languageCode: 'en',
      key: presetKey,
    );
    final localizedName = MacroRatioPresetCatalog.localizedLabelForLanguageCode(
      languageCode: languageCode,
      key: presetKey,
    );
    if (languageCode == 'en' || localizedName == englishName) {
      return englishName;
    }
    return '$localizedName ($englishName)';
  }

  static Map<String, dynamic> _buildObjectiveAdherence({
    required int calories,
    required double fat,
    required double protein,
    required double carbs,
    required MacroRatioPreset preset,
    required DailyTargets maintenanceBaseline,
  }) {
    final calorieAdherence = _buildCalorieAdherence(
      actual: calories,
      maintenance: maintenanceBaseline.calories,
      objective: preset.calorieObjective,
    );
    final macroDistribution = _buildMacroDistribution(
      fat: fat,
      protein: protein,
      carbs: carbs,
      preset: preset,
    );
    final hasCalorieGap = !(calorieAdherence['supports_objective'] as bool);
    final hasMacroGap = macroDistribution['has_gap'] as bool;

    return {
      'has_objective_gap': hasCalorieGap || hasMacroGap,
      'calories': calorieAdherence,
      'macro_distribution': macroDistribution,
    };
  }

  static Map<String, dynamic> _buildCalorieAdherence({
    required int actual,
    required int maintenance,
    required CalorieObjective objective,
  }) {
    if (maintenance <= 0) {
      return {
        'actual': actual,
        'maintenance_baseline': maintenance,
        'delta_from_maintenance': actual - maintenance,
        'percent_of_maintenance': 0,
        'objective': objective.key,
        'supports_objective': false,
        'status': 'no_baseline',
      };
    }

    final delta = actual - maintenance;
    final percentOfMaintenance = (actual / maintenance) * 100;
    final supportsObjective = switch (objective) {
      CalorieObjective.belowMaintenance => actual < maintenance,
      CalorieObjective.maintenance =>
        ((delta.abs() / maintenance) * 100) <= maintenanceTolerancePercent,
    };
    final status = switch (objective) {
      CalorieObjective.belowMaintenance when actual < maintenance =>
        'supports_objective',
      CalorieObjective.belowMaintenance when actual == maintenance =>
        'at_maintenance',
      CalorieObjective.belowMaintenance => 'above_maintenance',
      CalorieObjective.maintenance when supportsObjective =>
        'supports_objective',
      CalorieObjective.maintenance when actual < maintenance =>
        'below_maintenance_range',
      CalorieObjective.maintenance => 'above_maintenance_range',
    };

    return {
      'actual': actual,
      'maintenance_baseline': maintenance,
      'delta_from_maintenance': delta,
      'percent_of_maintenance': _round(percentOfMaintenance),
      'objective': objective.key,
      'supports_objective': supportsObjective,
      'status': status,
      if (objective == CalorieObjective.maintenance)
        'tolerance_percent': maintenanceTolerancePercent,
    };
  }

  static Map<String, dynamic> _buildMacroDistribution({
    required double fat,
    required double protein,
    required double carbs,
    required MacroRatioPreset preset,
  }) {
    final fatCalories = fat * 9;
    final proteinCalories = protein * 4;
    final carbsCalories = carbs * 4;
    final totalMacroCalories = fatCalories + proteinCalories + carbsCalories;
    final hasMacroData = totalMacroCalories > 0;

    Map<String, dynamic> macro({
      required double macroCalories,
      required int targetPercent,
    }) {
      if (!hasMacroData) {
        return {
          'actual_percent': 0,
          'target_percent': targetPercent,
          'difference_percentage_points': -targetPercent,
          'status': 'no_data',
        };
      }
      final actualPercent = (macroCalories / totalMacroCalories) * 100;
      final difference = actualPercent - targetPercent;
      final status = difference.abs() <= macroRatioTolerancePercentagePoints
          ? 'on_target'
          : difference > 0
              ? 'over'
              : 'under';
      return {
        'actual_percent': _round(actualPercent),
        'target_percent': targetPercent,
        'difference_percentage_points': _round(difference),
        'status': status,
      };
    }

    final fatDistribution = macro(
      macroCalories: fatCalories,
      targetPercent: preset.fatPercent,
    );
    final proteinDistribution = macro(
      macroCalories: proteinCalories,
      targetPercent: preset.proteinPercent,
    );
    final carbsDistribution = macro(
      macroCalories: carbsCalories,
      targetPercent: preset.carbsPercent,
    );
    final hasGap = !hasMacroData ||
        fatDistribution['status'] != 'on_target' ||
        proteinDistribution['status'] != 'on_target' ||
        carbsDistribution['status'] != 'on_target';

    return {
      'has_gap': hasGap,
      'tolerance_percentage_points': macroRatioTolerancePercentagePoints,
      'fat': fatDistribution,
      'protein': proteinDistribution,
      'carbs': carbsDistribution,
    };
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
