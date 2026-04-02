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
  });

  final bool selected;
  final Widget child;
  final bool inset;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return child;
    }

    final insetPadding = inset
        ? const EdgeInsets.symmetric(
            horizontal: UiConstants.xxSmallSpacing,
            vertical: UiConstants.xSmallSpacing / 2,
          )
        : EdgeInsets.zero;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: insetPadding,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor ?? AppColors.selectionHighlight,
                  border: Border.all(
                    color: borderColor ?? AppColors.selectionBorder,
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
