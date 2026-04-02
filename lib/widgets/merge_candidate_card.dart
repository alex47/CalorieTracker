import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/food_definition.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'food_breakdown_card.dart';
import 'labeled_group_box.dart';
import 'selected_surface.dart';

class MergeCandidateCard extends StatelessWidget {
  const MergeCandidateCard({
    super.key,
    required this.food,
    required this.selected,
    this.onTap,
  });

  static const EdgeInsets _cardPadding = EdgeInsets.all(UiConstants.mediumSpacing);

  final FoodDefinition food;
  final bool selected;
  final VoidCallback? onTap;

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  String _formatAmount(double value, String unit) {
    final displayValue = _formatNumber(value);
    return unit.isEmpty ? displayValue : '$displayValue $unit';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: UiConstants.homePageSnapDuration,
        curve: Curves.easeOutCubic,
        child: SelectedSurface(
          selected: selected,
          showBaseBorder: true,
          child: Padding(
            padding: _cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: LabeledGroupBox(
                    label: l10n.foodLabel,
                    value: food.name.trim().isEmpty ? '-' : food.name,
                    borderColor: AppColors.subtleBorder,
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: UiConstants.smallSpacing),
                Row(
                  children: [
                    Expanded(
                      child: LabeledGroupBox(
                        label: l10n.standardUnitLabel,
                        value: _formatAmount(
                          food.standardUnitAmount,
                          food.standardUnit,
                        ),
                        borderColor: AppColors.subtleBorder,
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(
                      width: UiConstants.smallSpacing + UiConstants.groupBoxHeaderTopInset,
                    ),
                    Expanded(
                      child: LabeledGroupBox(
                        label: l10n.foodUsesLabel,
                        value: food.usageCount.toString(),
                        borderColor: AppColors.subtleBorder,
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiConstants.mediumSpacing),
                FoodBreakdownCard(
                  name: food.name,
                  calories: food.standardCalories.round(),
                  fat: food.standardFat,
                  protein: food.standardProtein,
                  carbs: food.standardCarbs,
                  notes: food.notes,
                  showName: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
