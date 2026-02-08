import 'package:flutter/material.dart';

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
    this.overGoalColor = const Color(0xFF7F1D1D),
  });

  final String label;
  final double value;
  final double goal;
  final Color color;
  final String unit;
  final double height;
  final Duration animationDuration;
  final Color overGoalColor;

  String _format(double v) {
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final isOverGoal = value > goal;
    final baseColor = isOverGoal ? overGoalColor : color;
    final fillColor = baseColor.withOpacity(0.28);
    final borderColor = baseColor;
    final trackColor = Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6);

    return LabeledGroupBox(
      label: label,
      value: '',
      borderColor: borderColor,
      labelColor: borderColor,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: borderColor),
      backgroundColor: trackColor,
      contentPadding: EdgeInsets.zero,
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fillColor),
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
    );
  }
}
