import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class LabeledProgressBar extends StatelessWidget {
  const LabeledProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    this.unit = 'g',
    this.height = UiConstants.progressBarHeight,
    this.animationDuration = UiConstants.progressBarAnimationDuration,
    this.onTap,
  });

  final String label;
  final double value;
  final double goal;
  final Color color;
  final String unit;
  final double height;
  final Duration animationDuration;
  final VoidCallback? onTap;

  String _format(double v) {
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final isOverGoal = value > goal;
    final stripedFillColor = color.withValues(alpha: AppColors.progressFillAlpha);
    final fillColor = isOverGoal ? Colors.transparent : stripedFillColor;
    final borderColor = color;

    final content = LabeledGroupBox(
      label: label,
      value: '',
      borderColor: borderColor,
      labelColor: borderColor,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: borderColor),
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedFractionallySizedBox(
                duration: animationDuration,
                curve: Curves.easeOutCubic,
                widthFactor: progress,
                child: SizedBox(
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(color: fillColor),
                      ),
                      if (isOverGoal)
                        CustomPaint(
                          painter: _DiagonalStripePainter(
                            stripeColor: stripedFillColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: height,
              child: Center(
                child: Text(
                  '${_format(value)}/${_format(goal)} $unit',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: borderColor),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
        child: content,
      ),
    );
  }
}

class _DiagonalStripePainter extends CustomPainter {
  const _DiagonalStripePainter({
    required this.stripeColor,
  });

  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 12;
    const double strokeWidth = 1.2;
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    for (double x = -size.height; x < size.width; x += spacing) {
      final start = Offset(x, size.height);
      final end = Offset(x + size.height, 0);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripePainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor;
  }
}
