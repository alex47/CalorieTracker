import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';
import 'labeled_input_box.dart';

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
    this.multiplierController,
    this.multiplierValue,
    this.multiplierLabel,
    this.multiplierEnabled = true,
    this.onMultiplierChanged,
    this.margin,
  });

  final String name;
  final String amount;
  final int calories;
  final double fat;
  final double protein;
  final double carbs;
  final String notes;
  final TextEditingController? multiplierController;
  final String? multiplierValue;
  final String? multiplierLabel;
  final bool multiplierEnabled;
  final ValueChanged<String>? onMultiplierChanged;
  final EdgeInsetsGeometry? margin;

  String _formatGrams(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final trimmedNotes = notes.trim();
    final displayName = name.trim().isEmpty ? '-' : name;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: LabeledGroupBox(
        label: '',
        value: '',
        borderColor: AppColors.subtleBorder,
        textStyle: textTheme.bodyMedium,
        backgroundColor: AppColors.boxBackground,
        clipChild: false,
        contentPadding: const EdgeInsets.all(UiConstants.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = UiConstants.smallSpacing + UiConstants.groupBoxHeaderTopInset;
                final columnWidth = (constraints.maxWidth - (2 * gap)) / 3;
                return Row(
                  children: [
                    SizedBox(
                      width: columnWidth,
                      child: MetricGroupBox(
                        label: l10n.caloriesLabel,
                        value: l10n.caloriesKcalValue(calories),
                        color: AppColors.calories,
                        minWidth: 0,
                        valueAlignment: Alignment.center,
                        valueTextAlign: TextAlign.center,
                      ),
                    ),
                    if ((multiplierController != null || multiplierValue != null) &&
                        multiplierLabel != null) ...[
                      const SizedBox(width: gap),
                      Expanded(
                        child: LabeledInputBox(
                          label: multiplierLabel!,
                          controller: multiplierController,
                          initialValue: multiplierValue,
                          enabled: multiplierEnabled,
                          readOnly: multiplierController == null,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: onMultiplierChanged,
                          borderColor: AppColors.amountField,
                          textColor: AppColors.text,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: UiConstants.macroCounterGap),
            Row(
              children: [
                Expanded(
                  child: MetricGroupBox(
                    label: l10n.fatLabel,
                    value: l10n.gramsValue(_formatGrams(fat)),
                    color: AppColors.fat,
                    minWidth: 0,
                    valueAlignment: Alignment.center,
                    valueTextAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(
                  width: UiConstants.smallSpacing + UiConstants.groupBoxHeaderTopInset,
                ),
                Expanded(
                  child: MetricGroupBox(
                    label: l10n.proteinLabel,
                    value: l10n.gramsValue(_formatGrams(protein)),
                    color: AppColors.protein,
                    minWidth: 0,
                    valueAlignment: Alignment.center,
                    valueTextAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(
                  width: UiConstants.smallSpacing + UiConstants.groupBoxHeaderTopInset,
                ),
                Expanded(
                  child: MetricGroupBox(
                    label: l10n.carbsLabel,
                    value: l10n.gramsValue(_formatGrams(carbs)),
                    color: AppColors.carbs,
                    minWidth: 0,
                    valueAlignment: Alignment.center,
                    valueTextAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: UiConstants.macroCounterGap),
            SizedBox(
              width: double.infinity,
              child: LabeledGroupBox(
                label: l10n.notesLabel,
                value: trimmedNotes.isEmpty ? '-' : trimmedNotes,
                borderColor: AppColors.subtleBorder,
                textStyle: textTheme.bodyMedium,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
