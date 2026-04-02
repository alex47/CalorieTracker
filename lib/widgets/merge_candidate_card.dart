import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/food_definition.dart';
import '../theme/ui_constants.dart';
import 'food_breakdown_card.dart';
import 'selected_surface.dart';

class MergeCandidateCard extends StatelessWidget {
  const MergeCandidateCard({
    super.key,
    required this.food,
    required this.selected,
    this.onTap,
  });

  static const EdgeInsets _cardPadding = EdgeInsets.all(UiConstants.smallSpacing);
  static const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(
    UiConstants.smallSpacing,
    0,
    UiConstants.smallSpacing,
    UiConstants.smallSpacing,
  );

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
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: UiConstants.homePageSnapDuration,
        curve: Curves.easeOutCubic,
        child: SelectedSurface(
          selected: selected,
          child: Padding(
            padding: _cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: _headerPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name.trim().isEmpty ? '-' : food.name,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: UiConstants.xSmallSpacing),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatAmount(food.standardUnitAmount, food.standardUnit),
                              style: textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            l10n.foodUsageCount(food.usageCount),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
