import 'package:calorie_tracker/models/daily_targets.dart';
import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/services/day_summary_snapshot_builder.dart';
import 'package:calorie_tracker/services/macro_ratio_preset_catalog.dart';
import 'package:calorie_tracker/services/openai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const maintenanceBaseline = DailyTargets(
    calories: 2000,
    fat: 67,
    protein: 100,
    carbs: 250,
  );

  group('Daily summary objective adherence', () {
    test('only weight loss uses the below-maintenance objective', () {
      for (final preset in MacroRatioPresetCatalog.presets) {
        final expected =
            preset.key == MacroRatioPresetCatalog.fatLossHigherProteinKey
                ? CalorieObjective.belowMaintenance
                : CalorieObjective.maintenance;

        expect(preset.calorieObjective, expected, reason: preset.key);
      }
    });

    test('weight-loss intake below maintenance supports the objective', () {
      final snapshot = _buildSnapshot(
        profile: _weightLossProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 1600,
          fatPercent: 30,
          proteinPercent: 30,
          carbsPercent: 40,
        ),
      );
      final adherence = _map(snapshot['objective_adherence']);
      final calorieAdherence = _map(adherence['calories']);
      final macroDistribution = _map(adherence['macro_distribution']);

      expect(calorieAdherence['supports_objective'], isTrue);
      expect(calorieAdherence['status'], 'supports_objective');
      expect(macroDistribution['has_gap'], isFalse);
      expect(adherence['has_objective_gap'], isFalse);
    });

    test('weight-loss intake at maintenance has an objective gap', () {
      final snapshot = _buildSnapshot(
        profile: _weightLossProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 2000,
          fatPercent: 30,
          proteinPercent: 30,
          carbsPercent: 40,
        ),
      );
      final adherence = _map(snapshot['objective_adherence']);
      final calorieAdherence = _map(adherence['calories']);

      expect(calorieAdherence['supports_objective'], isFalse);
      expect(calorieAdherence['status'], 'at_maintenance');
      expect(adherence['has_objective_gap'], isTrue);
    });

    test('weight-loss intake above maintenance has an objective gap', () {
      final snapshot = _buildSnapshot(
        profile: _weightLossProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 2100,
          fatPercent: 30,
          proteinPercent: 30,
          carbsPercent: 40,
        ),
      );
      final adherence = _map(snapshot['objective_adherence']);
      final calorieAdherence = _map(adherence['calories']);

      expect(calorieAdherence['supports_objective'], isFalse);
      expect(calorieAdherence['status'], 'above_maintenance');
      expect(adherence['has_objective_gap'], isTrue);
    });

    test('maintenance intake outside its tolerance has an objective gap', () {
      final snapshot = _buildSnapshot(
        profile: _maintenanceProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 1700,
          fatPercent: 30,
          proteinPercent: 20,
          carbsPercent: 50,
        ),
      );
      final adherence = _map(snapshot['objective_adherence']);
      final calorieAdherence = _map(adherence['calories']);

      expect(calorieAdherence['supports_objective'], isFalse);
      expect(calorieAdherence['status'], 'below_maintenance_range');
      expect(adherence['has_objective_gap'], isTrue);
    });

    test('macro adherence uses distribution instead of maintenance grams', () {
      final snapshot = _buildSnapshot(
        profile: _weightLossProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 1400,
          fatPercent: 30,
          proteinPercent: 30,
          carbsPercent: 40,
        ),
      );
      final adherence = _map(snapshot['objective_adherence']);
      final macroDistribution = _map(adherence['macro_distribution']);

      expect(_map(macroDistribution['fat'])['status'], 'on_target');
      expect(_map(macroDistribution['protein'])['status'], 'on_target');
      expect(_map(macroDistribution['carbs'])['status'], 'on_target');
      expect(macroDistribution['has_gap'], isFalse);
      expect(adherence['has_objective_gap'], isFalse);
    });

    test('incorrect macro distribution creates an objective gap', () {
      final snapshot = _buildSnapshot(
        profile: _weightLossProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 1600,
          fatPercent: 20,
          proteinPercent: 20,
          carbsPercent: 60,
        ),
      );
      final adherence = _map(snapshot['objective_adherence']);
      final macroDistribution = _map(adherence['macro_distribution']);

      expect(macroDistribution['has_gap'], isTrue);
      expect(adherence['has_objective_gap'], isTrue);
    });
  });

  group('Daily summary objective prompt', () {
    test('describes weight loss as below maintenance', () {
      final snapshot = _buildSnapshot(
        profile: _weightLossProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 1600,
          fatPercent: 30,
          proteinPercent: 30,
          carbsPercent: 40,
        ),
      );

      final prompt = OpenAIService('test-key').buildDaySummaryPrompt(
        languageCode: 'en',
        daySnapshot: snapshot,
      );

      expect(prompt, contains('Selected macro strategy: Weight loss.'));
      expect(
        prompt,
        contains(
          'Every total strictly below maintenance satisfies this objective\'s calorie-direction criterion.',
        ),
      );
      expect(
        prompt,
        contains(
          'does not by itself establish that the intake is nutritionally adequate',
        ),
      );
      expect(prompt, contains('absolute macro amounts'));
      expect(
        prompt,
        contains(
          'An on-target macro distribution does not prove that absolute intake is adequate.',
        ),
      );
      expect(
        prompt,
        contains('Do not state an unmeasured nutrient deficiency as fact.'),
      );
      expect(prompt, contains('"issues": provide 0-5 short bullets.'));
      expect(prompt, contains('"suggestions": provide 0-5'));
      expect(prompt, contains('has no objective gap'));
      expect(
        prompt,
        isNot(contains('Daily maintenance baseline for this day: Weight loss')),
      );
    });

    test('describes maintenance and includes a detected gap', () {
      final snapshot = _buildSnapshot(
        profile: _maintenanceProfile,
        maintenanceBaseline: maintenanceBaseline,
        item: _foodWithMacroPercentages(
          calories: 1700,
          fatPercent: 30,
          proteinPercent: 20,
          carbsPercent: 50,
        ),
      );

      final prompt = OpenAIService('test-key').buildDaySummaryPrompt(
        languageCode: 'en',
        daySnapshot: snapshot,
      );

      expect(prompt, contains('Selected macro strategy: Balanced default.'));
      expect(
          prompt, contains('remain near the estimated maintenance baseline'));
      expect(prompt, contains('An objective gap is present'));
    });

    test('does not describe absent adherence data as gap-free', () {
      final prompt = OpenAIService('test-key').buildDaySummaryPrompt(
        languageCode: 'en',
        daySnapshot: const {
          'nutrition_objective': null,
          'objective_adherence': null,
        },
      );

      expect(prompt, contains('No calorie or macro objective is configured.'));
      expect(prompt, isNot(contains('provided adherence data has no')));
      expect(prompt, isNot(contains('objective gap is present')));
    });
  });
}

const _weightLossProfile = MetabolicProfile(
  age: 30,
  sex: 'male',
  heightCm: 180,
  weightKg: 80,
  activityLevel: 'moderate',
  fatRatioPercent: 30,
  proteinRatioPercent: 30,
  carbsRatioPercent: 40,
);

const _maintenanceProfile = MetabolicProfile(
  age: 30,
  sex: 'male',
  heightCm: 180,
  weightKg: 80,
  activityLevel: 'moderate',
  fatRatioPercent: 30,
  proteinRatioPercent: 20,
  carbsRatioPercent: 50,
);

Map<String, dynamic> _buildSnapshot({
  required MetabolicProfile profile,
  required DailyTargets maintenanceBaseline,
  required FoodItem item,
}) {
  return DaySummarySnapshotBuilder.build(
    date: DateTime(2026, 7, 19),
    items: [item],
    profile: profile,
    maintenanceBaseline: maintenanceBaseline,
    languageCode: 'en',
  );
}

FoodItem _foodWithMacroPercentages({
  required int calories,
  required int fatPercent,
  required int proteinPercent,
  required int carbsPercent,
}) {
  final fat = (calories * (fatPercent / 100)) / 9;
  final protein = (calories * (proteinPercent / 100)) / 4;
  final carbs = (calories * (carbsPercent / 100)) / 4;
  return FoodItem(
    id: 1,
    entryId: 1,
    foodId: 1,
    name: 'Test meal',
    amount: '1 serving',
    calories: calories,
    fat: fat,
    protein: protein,
    carbs: carbs,
    standardUnit: 'serving',
    standardUnitAmount: 1,
    multiplier: 1,
    standardCalories: calories.toDouble(),
    standardFat: fat,
    standardProtein: protein,
    standardCarbs: carbs,
    notes: '',
  );
}

Map<String, dynamic> _map(Object? value) {
  return value as Map<String, dynamic>;
}
