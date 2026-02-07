import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
            _MetricGroupBox(
              label: 'Calories',
              value: '$calories kcal',
              color: AppColors.calories,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricGroupBox(
                  label: 'Fat',
                  value: '${_formatGrams(fat)} g',
                  color: AppColors.fat,
                ),
                _MetricGroupBox(
                  label: 'Protein',
                  value: '${_formatGrams(protein)} g',
                  color: AppColors.protein,
                ),
                _MetricGroupBox(
                  label: 'Carbs',
                  value: '${_formatGrams(carbs)} g',
                  color: AppColors.carbs,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _LabeledGroupBox(
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

class _MetricGroupBox extends StatelessWidget {
  const _MetricGroupBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _LabeledGroupBox(
      label: label,
      value: value,
      borderColor: color,
      textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
      minWidth: 100,
      backgroundColor: color.withOpacity(0.14),
      labelColor: color,
    );
  }
}

class _LabeledGroupBox extends StatelessWidget {
  const _LabeledGroupBox({
    required this.label,
    required this.value,
    required this.borderColor,
    required this.textStyle,
    this.minWidth,
    this.backgroundColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final Color borderColor;
  final TextStyle? textStyle;
  final double? minWidth;
  final Color? backgroundColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final surface = Theme.of(context).colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: minWidth == null ? null : BoxConstraints(minWidth: minWidth!),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: textStyle),
        ),
        Positioned(
          left: 10,
          top: 0,
          child: Container(
            color: surface,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: labelColor ?? borderColor),
            ),
          ),
        ),
      ],
    );
  }
}
