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

  double _measureTextWidth(
    BuildContext context, {
    required String text,
    required TextStyle? style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
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
                final nameStyle = textTheme.titleMedium;
                final amountStyle = textTheme.bodyMedium;
                final maxWidth = constraints.maxWidth;
                final spacing = UiConstants.smallSpacing;
                final nameWidth = _measureTextWidth(
                  context,
                  text: displayName,
                  style: nameStyle,
                );
                final amountWidth = _measureTextWidth(
                  context,
                  text: displayAmount,
                  style: amountStyle,
                );
                final combinedWidth = nameWidth + spacing + amountWidth;
                final shouldStack = combinedWidth > (maxWidth - 1);

                if (shouldStack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: nameStyle,
                      ),
                      const SizedBox(height: UiConstants.xSmallSpacing),
                      Text(
                        displayAmount,
                        style: amountStyle,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: nameStyle,
                        softWrap: false,
                      ),
                    ),
                    const SizedBox(width: UiConstants.smallSpacing),
                    SizedBox(
                      width: amountWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          displayAmount,
                          style: amountStyle,
                          textAlign: TextAlign.end,
                          softWrap: false,
                        ),
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
              borderColor: AppColors.subtleBorder,
              textStyle: textTheme.bodyMedium,
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
