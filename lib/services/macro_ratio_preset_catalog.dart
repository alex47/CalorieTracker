import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

class MacroRatioPreset {
  const MacroRatioPreset({
    required this.key,
    required this.fatPercent,
    required this.proteinPercent,
    required this.carbsPercent,
  });

  final String key;
  final int fatPercent;
  final int proteinPercent;
  final int carbsPercent;
}

class MacroRatioPresetCatalog {
  static const String balancedDefaultKey = 'balanced_default';
  static const String fatLossHigherProteinKey = 'fat_loss_higher_protein';
  static const String bodyRecompositionTrainingKey = 'body_recomposition_training';
  static const String enduranceHighActivityKey = 'endurance_high_activity';
  static const String lowerCarbAppetiteControlKey = 'lower_carb_appetite_control';
  static const String highCarbPerformanceKey = 'high_carb_performance';

  static const List<MacroRatioPreset> presets = [
    MacroRatioPreset(
      key: balancedDefaultKey,
      fatPercent: 30,
      proteinPercent: 20,
      carbsPercent: 50,
    ),
    MacroRatioPreset(
      key: fatLossHigherProteinKey,
      fatPercent: 30,
      proteinPercent: 30,
      carbsPercent: 40,
    ),
    MacroRatioPreset(
      key: bodyRecompositionTrainingKey,
      fatPercent: 30,
      proteinPercent: 35,
      carbsPercent: 35,
    ),
    MacroRatioPreset(
      key: enduranceHighActivityKey,
      fatPercent: 30,
      proteinPercent: 15,
      carbsPercent: 55,
    ),
    MacroRatioPreset(
      key: lowerCarbAppetiteControlKey,
      fatPercent: 40,
      proteinPercent: 35,
      carbsPercent: 25,
    ),
    MacroRatioPreset(
      key: highCarbPerformanceKey,
      fatPercent: 20,
      proteinPercent: 20,
      carbsPercent: 60,
    ),
  ];

  static String keyForRatios({
    required int fatPercent,
    required int proteinPercent,
    required int carbsPercent,
  }) {
    for (final preset in presets) {
      if (preset.fatPercent == fatPercent &&
          preset.proteinPercent == proteinPercent &&
          preset.carbsPercent == carbsPercent) {
        return preset.key;
      }
    }
    return balancedDefaultKey;
  }

  static MacroRatioPreset presetForKey(String? key) {
    if (key == null || key.isEmpty) {
      return presets.first;
    }
    for (final preset in presets) {
      if (preset.key == key) {
        return preset;
      }
    }
    return presets.first;
  }

  static String localizedLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case balancedDefaultKey:
        return l10n.macroPresetBalancedDefault;
      case fatLossHigherProteinKey:
        return l10n.macroPresetFatLossHigherProtein;
      case bodyRecompositionTrainingKey:
        return l10n.macroPresetBodyRecompositionTraining;
      case enduranceHighActivityKey:
        return l10n.macroPresetEnduranceHighActivity;
      case lowerCarbAppetiteControlKey:
        return l10n.macroPresetLowerCarbAppetiteControl;
      case highCarbPerformanceKey:
        return l10n.macroPresetHighCarbPerformance;
      default:
        return l10n.macroPresetBalancedDefault;
    }
  }

  static String localizedLabelForLanguageCode({
    required String languageCode,
    required String key,
  }) {
    final l10n = lookupAppLocalizations(Locale(languageCode));
    return localizedLabel(l10n, key);
  }
}
