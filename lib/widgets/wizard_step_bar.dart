import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';

class WizardStepBar extends StatelessWidget {
  const WizardStepBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  }) : assert(totalSteps > 0),
       assert(currentStep >= 0),
       assert(currentStep < totalSteps);

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == totalSteps - 1 ? 0 : UiConstants.smallSpacing,
            ),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.selectionBorder : AppColors.subtleBorder,
                borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
              ),
            ),
          ),
        );
      }),
    );
  }
}
