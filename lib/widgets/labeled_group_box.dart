import 'package:flutter/material.dart';

import '../theme/ui_constants.dart';
import 'painters/notched_border_painter.dart';

class LabeledGroupBox extends StatelessWidget {
  const LabeledGroupBox({
    super.key,
    required this.label,
    required this.value,
    required this.borderColor,
    required this.textStyle,
    this.child,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 10, 12, 6),
    this.contentHeight,
    this.minWidth,
    this.backgroundColor,
    this.labelColor,
    this.clipChild = true,
  });

  final String label;
  final String value;
  final Color borderColor;
  final TextStyle? textStyle;
  final Widget? child;
  final EdgeInsetsGeometry contentPadding;
  final double? contentHeight;
  final double? minWidth;
  final Color? backgroundColor;
  final Color? labelColor;
  final bool clipChild;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasLabel = label.trim().isNotEmpty;
    const gapStart = UiConstants.groupBoxHeaderGapStart;
    const gapHorizontalPadding = UiConstants.groupBoxHeaderGapHorizontalPadding;
    final effectiveLabelColor = labelColor ?? borderColor;
    final labelStyle = textTheme.bodySmall?.copyWith(color: effectiveLabelColor);
    final labelPainter = TextPainter(
      text: TextSpan(text: hasLabel ? label : '', style: labelStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final labelGapWidth = hasLabel ? labelPainter.width + (gapHorizontalPadding * 2) : 0.0;
    final topInset = hasLabel ? UiConstants.groupBoxHeaderTopInset : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.only(top: topInset),
          constraints: minWidth == null ? null : BoxConstraints(minWidth: minWidth!),
          height: contentHeight,
          padding: contentPadding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
          ),
          child: child == null
              ? Text(value, style: textStyle)
              : (clipChild
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                      child: child,
                    )
                  : child!),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: NotchedBorderPainter(
                color: borderColor,
                radius: UiConstants.cornerRadius,
                topInset: topInset,
                gapStart: gapStart,
                gapWidth: labelGapWidth,
              ),
            ),
          ),
        ),
        if (hasLabel)
          Positioned(
            left: gapStart,
            top: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: gapHorizontalPadding),
              child: Text(
                label,
                style: labelStyle,
              ),
            ),
          ),
      ],
    );
  }
}

class MetricGroupBox extends StatelessWidget {
  const MetricGroupBox({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.minWidth = UiConstants.metricGroupMinWidth,
    this.contentHeight = UiConstants.progressBarHeight,
    this.valueAlignment = Alignment.centerLeft,
    this.valueTextAlign = TextAlign.start,
  });

  final String label;
  final String value;
  final Color color;
  final double minWidth;
  final double contentHeight;
  final AlignmentGeometry valueAlignment;
  final TextAlign valueTextAlign;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);
    return LabeledGroupBox(
      label: label,
      value: '',
      borderColor: color,
      textStyle: valueStyle,
      contentHeight: contentHeight,
      contentPadding: const EdgeInsets.symmetric(horizontal: UiConstants.tableRowHorizontalPadding),
      minWidth: minWidth,
      backgroundColor: Colors.transparent,
      labelColor: color,
      child: SizedBox(
        width: double.infinity,
        child: Align(
          alignment: valueAlignment,
          child: Text(
            value,
            style: valueStyle,
            textAlign: valueTextAlign,
          ),
        ),
      ),
    );
  }
}
