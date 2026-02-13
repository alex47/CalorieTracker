import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'daily_goals.dart';
import 'food_item.dart';

enum MetricType { calories, fat, protein, carbs }

extension MetricTypeX on MetricType {
  String label(AppLocalizations l10n) {
    switch (this) {
      case MetricType.calories:
        return l10n.caloriesLabel;
      case MetricType.fat:
        return l10n.fatLabel;
      case MetricType.protein:
        return l10n.proteinLabel;
      case MetricType.carbs:
        return l10n.carbsLabel;
    }
  }

  String get unit {
    switch (this) {
      case MetricType.calories:
        return 'kcal';
      case MetricType.fat:
      case MetricType.protein:
      case MetricType.carbs:
        return 'g';
    }
  }

  Color get color {
    switch (this) {
      case MetricType.calories:
        return AppColors.calories;
      case MetricType.fat:
        return AppColors.fat;
      case MetricType.protein:
        return AppColors.protein;
      case MetricType.carbs:
        return AppColors.carbs;
    }
  }

  double goalFromDailyGoals(DailyGoals goals) {
    switch (this) {
      case MetricType.calories:
        return goals.calories.toDouble();
      case MetricType.fat:
        return goals.fat.toDouble();
      case MetricType.protein:
        return goals.protein.toDouble();
      case MetricType.carbs:
        return goals.carbs.toDouble();
    }
  }

  double valueFromFoodItem(FoodItem item) {
    switch (this) {
      case MetricType.calories:
        return item.calories.toDouble();
      case MetricType.fat:
        return item.fat;
      case MetricType.protein:
        return item.protein;
      case MetricType.carbs:
        return item.carbs;
    }
  }

  double valueFromTotals({
    required int calories,
    required double fat,
    required double protein,
    required double carbs,
  }) {
    switch (this) {
      case MetricType.calories:
        return calories.toDouble();
      case MetricType.fat:
        return fat;
      case MetricType.protein:
        return protein;
      case MetricType.carbs:
        return carbs;
    }
  }

  String formatValue(double value) {
    if (this == MetricType.calories) {
      return value.toInt().toString();
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
