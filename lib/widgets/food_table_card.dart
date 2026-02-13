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
  });

  final List<FoodTableCell> cells;
  final TextStyle? textStyle;
  final VoidCallback? onTap;
}

class FoodTableCard extends StatelessWidget {
  const FoodTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.borderColor,
  });

  final List<FoodTableColumn> columns;
  final List<FoodTableRowData> rows;
  final Color? borderColor;

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
              const Divider(height: 1),
              ...rows.map((row) {
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
                          style: row.textStyle ?? textTheme.bodyMedium,
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
