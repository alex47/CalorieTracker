import 'package:calorie_tracker/services/macro_ratio_preset_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MacroRatioPresetCatalog', () {
    test('every preset can be identified by its ratios and key', () {
      for (final preset in MacroRatioPresetCatalog.presets) {
        expect(
          MacroRatioPresetCatalog.keyForRatios(
            fatPercent: preset.fatPercent,
            proteinPercent: preset.proteinPercent,
            carbsPercent: preset.carbsPercent,
          ),
          preset.key,
        );
        expect(
          MacroRatioPresetCatalog.presetForKey(preset.key),
          same(preset),
        );
      }
    });

    test('unknown ratios and keys fall back to balanced default', () {
      expect(
        MacroRatioPresetCatalog.keyForRatios(
          fatPercent: 1,
          proteinPercent: 2,
          carbsPercent: 97,
        ),
        MacroRatioPresetCatalog.balancedDefaultKey,
      );
      expect(
        MacroRatioPresetCatalog.presetForKey('unknown').key,
        MacroRatioPresetCatalog.balancedDefaultKey,
      );
      expect(
        MacroRatioPresetCatalog.presetForKey(null).key,
        MacroRatioPresetCatalog.balancedDefaultKey,
      );
      expect(
        MacroRatioPresetCatalog.presetForKey('').key,
        MacroRatioPresetCatalog.balancedDefaultKey,
      );
    });

    test('only weight loss uses below-maintenance calories', () {
      for (final preset in MacroRatioPresetCatalog.presets) {
        expect(
          preset.calorieObjective,
          preset.key == MacroRatioPresetCatalog.fatLossHigherProteinKey
              ? CalorieObjective.belowMaintenance
              : CalorieObjective.maintenance,
        );
      }
    });
  });
}
