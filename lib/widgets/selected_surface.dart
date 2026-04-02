import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';

class SelectedSurface extends StatelessWidget {
  const SelectedSurface({
    super.key,
    required this.selected,
    required this.child,
    this.inset = false,
    this.backgroundColor,
    this.borderColor,
    this.showBaseBorder = false,
  });

  final bool selected;
  final Widget child;
  final bool inset;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showBaseBorder;

  @override
  Widget build(BuildContext context) {
    final insetPadding = inset
        ? const EdgeInsets.symmetric(
            horizontal: UiConstants.xxSmallSpacing,
            vertical: UiConstants.xSmallSpacing / 2,
          )
        : EdgeInsets.zero;
    final resolvedBorderColor = selected
        ? (borderColor ?? AppColors.selectionBorder)
        : (showBaseBorder ? AppColors.subtleBorder : null);
    final resolvedBackgroundColor =
        selected ? (backgroundColor ?? AppColors.selectionHighlight) : null;

    if (resolvedBorderColor == null && resolvedBackgroundColor == null) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: insetPadding,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: resolvedBackgroundColor,
                  border: resolvedBorderColor == null
                      ? null
                      : Border.all(
                          color: resolvedBorderColor,
                          width: UiConstants.borderWidth,
                        ),
                  borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
