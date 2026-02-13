import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class FoodTableColumn {
  const FoodTableColumn({
    required this.label,
    required this.flex,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final int flex;
  final TextAlign textAlign;
}

class FoodTableCell {
  const FoodTableCell({
    required this.text,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
}

class FoodTableRowData {
  const FoodTableRowData({
    required this.cells,
    this.textStyle,
    this.onTap,
    this.fat,
    this.protein,
    this.carbs,
  });

  final List<FoodTableCell> cells;
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final double? fat;
  final double? protein;
  final double? carbs;
}

class FoodTableCard extends StatelessWidget {
  const FoodTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.borderColor,
    this.highlightRowsByDominantMacro = false,
  });

  final List<FoodTableColumn> columns;
  final List<FoodTableRowData> rows;
  final Color? borderColor;
  final bool highlightRowsByDominantMacro;

  Color? _dominantMacroColor(FoodTableRowData row) {
    final fat = row.fat;
    final protein = row.protein;
    final carbs = row.carbs;
    if (fat == null || protein == null || carbs == null) {
      return null;
    }
    final maxValue = [fat, protein, carbs].reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) {
      return null;
    }
    if (carbs == maxValue) {
      return AppColors.carbs;
    }
    if (protein == maxValue) {
      return AppColors.protein;
    }
    return AppColors.fat;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resolvedBorderColor = borderColor ?? AppColors.tableBorder;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiConstants.tableRowHorizontalPadding,
                  vertical: UiConstants.tableRowVerticalPadding,
                ),
                child: Row(
                  children: columns
                      .map(
                        (column) => Expanded(
                          flex: column.flex,
                          child: Text(
                            column.label,
                            style: textTheme.labelLarge,
                            textAlign: column.textAlign,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: UiConstants.borderWidth,
                child: CustomPaint(
                  painter: _HorizontalDividerPainter(
                    color: resolvedBorderColor,
                  ),
                ),
              ),
              ...rows.map((row) {
                final dominantColor =
                    highlightRowsByDominantMacro ? _dominantMacroColor(row) : null;
                final effectiveTextStyle =
                    row.textStyle ?? textTheme.bodyMedium?.copyWith(color: dominantColor);
                final content = Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UiConstants.tableRowHorizontalPadding,
                    vertical: UiConstants.tableRowVerticalPadding,
                  ),
                  child: Row(
                    children: List<Widget>.generate(columns.length, (index) {
                      final column = columns[index];
                      final cell = row.cells[index];
                      return Expanded(
                        flex: column.flex,
                        child: Text(
                          cell.text,
                          textAlign: cell.textAlign,
                          maxLines: cell.maxLines,
                          overflow: cell.overflow,
                          style: effectiveTextStyle,
                        ),
                      );
                    }),
                  ),
                );

                if (row.onTap == null) {
                  return content;
                }
                return InkWell(
                  onTap: row.onTap,
                  child: content,
                );
              }),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: NotchedBorderPainter(
                  color: resolvedBorderColor,
                  radius: UiConstants.cornerRadius,
                  topInset: 0,
                  gapStart: 0,
                  gapWidth: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalDividerPainter extends CustomPainter {
  const _HorizontalDividerPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = UiConstants.borderWidth
      ..color = color;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _HorizontalDividerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

List<FoodTableColumn> buildStandardFoodTableColumns({
  required String firstLabel,
  required String secondLabel,
  required String thirdLabel,
  TextAlign firstAlign = TextAlign.start,
  TextAlign secondAlign = TextAlign.start,
  TextAlign thirdAlign = TextAlign.end,
}) {
  return [
    FoodTableColumn(label: firstLabel, flex: 4, textAlign: firstAlign),
    FoodTableColumn(label: secondLabel, flex: 3, textAlign: secondAlign),
    FoodTableColumn(label: thirdLabel, flex: 2, textAlign: thirdAlign),
  ];
}
