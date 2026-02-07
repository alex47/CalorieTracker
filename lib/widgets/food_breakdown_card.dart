import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
    return Card(
      margin: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name.trim().isEmpty ? '-' : name,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amount.trim().isEmpty ? '-' : amount,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            MetricGroupBox(
              label: 'Calories',
              value: '$calories kcal',
              color: AppColors.calories,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 10),
            LabeledGroupBox(
              label: 'Notes',
              value: trimmedNotes.isEmpty ? '-' : trimmedNotes,
              borderColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
              textStyle: textTheme.bodySmall,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            ),
          ],
        ),
      ),
    );
  }
}
