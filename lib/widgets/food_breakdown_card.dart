import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class FoodBreakdownCard extends StatelessWidget {
  const FoodBreakdownCard({
    super.key,
    required this.name,
    required this.amount,
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
    required this.notes,
    this.margin,
  });

  final String name;
  final String amount;
  final int calories;
  final double fat;
  final double protein;
  final double carbs;
  final String notes;
  final EdgeInsetsGeometry? margin;

  String _formatGrams(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trimmedNotes = notes.trim();
    final displayName = name.trim().isEmpty ? '-' : name;
    final displayAmount = amount.trim().isEmpty ? '-' : amount;
    return Card(
      margin: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(UiConstants.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final shouldStack = constraints.maxWidth < 360 ||
                    (displayName.length > 26 && displayAmount.length > 18);
                if (shouldStack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayAmount,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        displayName,
                        style: textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: UiConstants.smallSpacing),
                    Expanded(
                      flex: 2,
                      child: Text(
                        displayAmount,
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            MetricGroupBox(
              label: 'Calories',
              value: '$calories kcal',
              color: AppColors.calories,
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            Wrap(
              spacing: UiConstants.smallSpacing,
              runSpacing: UiConstants.smallSpacing,
              children: [
                MetricGroupBox(
                  label: 'Fat',
                  value: '${_formatGrams(fat)} g',
                  color: AppColors.fat,
                ),
                MetricGroupBox(
                  label: 'Protein',
                  value: '${_formatGrams(protein)} g',
                  color: AppColors.protein,
                ),
                MetricGroupBox(
                  label: 'Carbs',
                  value: '${_formatGrams(carbs)} g',
                  color: AppColors.carbs,
                ),
              ],
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            LabeledGroupBox(
              label: 'Notes',
              value: trimmedNotes.isEmpty ? '-' : trimmedNotes,
              borderColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
              textStyle: textTheme.bodyMedium,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            ),
          ],
        ),
      ),
    );
  }
}
