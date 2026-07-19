import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/services/calorie_deficit_service.dart';
import 'package:calorie_tracker/services/nutrition_target_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalorieDeficitService', () {
    for (final scenario in [
      (activity: 'bmr', expected: 1780),
      (activity: 'sedentary', expected: 2136),
      (activity: 'light', expected: 2448),
      (activity: 'moderate', expected: 2759),
      (activity: 'active', expected: 3071),
      (activity: 'very_active', expected: 3382),
    ]) {
      test('calculates ${scenario.activity} male maintenance', () {
        expect(
          CalorieDeficitService.maintenanceCalories(
            _profile(activityLevel: scenario.activity),
          ),
          scenario.expected,
        );
      });
    }

    test('uses the female Mifflin-St Jeor adjustment', () {
      expect(
        CalorieDeficitService.maintenanceCalories(
          _profile(sex: 'female', activityLevel: 'moderate'),
        ),
        2502,
      );
    });

    test('unknown activity falls back to BMR', () {
      expect(
        CalorieDeficitService.maintenanceCalories(
          _profile(activityLevel: 'unsupported'),
        ),
        1780,
      );
    });

    test('daily deficit can be positive, zero, or negative', () {
      final profile = _profile(activityLevel: 'bmr');

      expect(
        CalorieDeficitService.dailyDeficit(
          consumedCalories: 1500,
          profile: profile,
        ),
        280,
      );
      expect(
        CalorieDeficitService.dailyDeficit(
          consumedCalories: 1780,
          profile: profile,
        ),
        0,
      );
      expect(
        CalorieDeficitService.dailyDeficit(
          consumedCalories: 2000,
          profile: profile,
        ),
        -220,
      );
    });
  });

  group('NutritionTargetService', () {
    test('calculates custom calorie ratios and rounds each macro', () {
      final targets = NutritionTargetService.targetsFromCalories(
        2001,
        proteinRatio: 0.333,
        fatRatio: 0.277,
        carbsRatio: 0.39,
      );

      expect(targets.calories, 2001);
      expect(targets.protein, 167);
      expect(targets.fat, 62);
      expect(targets.carbs, 195);
    });

    test('derives calories and configured ratios from a profile', () {
      final targets = NutritionTargetService.targetsFromProfile(
        _profile(
          activityLevel: 'bmr',
          fatPercent: 30,
          proteinPercent: 30,
          carbsPercent: 40,
        ),
      );

      expect(targets.calories, 1780);
      expect(targets.fat, 59);
      expect(targets.protein, 134);
      expect(targets.carbs, 178);
    });

    test('zero calories produce zero macro targets', () {
      final targets = NutritionTargetService.targetsFromCalories(
        0,
        proteinRatio: 0.2,
        fatRatio: 0.3,
        carbsRatio: 0.5,
      );

      expect(targets.calories, 0);
      expect(targets.fat, 0);
      expect(targets.protein, 0);
      expect(targets.carbs, 0);
    });
  });
}

MetabolicProfile _profile({
  String sex = 'male',
  String activityLevel = 'bmr',
  int fatPercent = 30,
  int proteinPercent = 20,
  int carbsPercent = 50,
}) {
  return MetabolicProfile(
    age: 30,
    sex: sex,
    heightCm: 180,
    weightKg: 80,
    activityLevel: activityLevel,
    fatRatioPercent: fatPercent,
    proteinRatioPercent: proteinPercent,
    carbsRatioPercent: carbsPercent,
  );
}
