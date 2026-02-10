import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'dialog_action_row.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.actionsPadding,
    this.buttonPadding,
    this.insetPadding,
    this.actionItems,
    this.actionAxis = Axis.vertical,
    this.actionAlignment = MainAxisAlignment.end,
    this.actionSpacing = UiConstants.smallSpacing,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsetsGeometry? buttonPadding;
  final EdgeInsets? insetPadding;
  final List<DialogActionItem>? actionItems;
  final Axis actionAxis;
  final MainAxisAlignment actionAlignment;
  final double actionSpacing;

  @override
  Widget build(BuildContext context) {
    final resolvedActions = actionItems == null || actionItems!.isEmpty
        ? actions
        : <Widget>[
            if (actionAxis == Axis.horizontal)
              DialogActionRow(
                items: actionItems!,
                alignment: actionAlignment,
                spacing: actionSpacing,
              )
            else
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actionItems!.length; i++) ...[
                      actionItems![i].width == null
                          ? actionItems![i].child
                          : SizedBox(
                              width: actionItems![i].width,
                              child: actionItems![i].child,
                            ),
                      if (i != actionItems!.length - 1)
                        SizedBox(height: actionSpacing),
                    ],
                  ],
                ),
              ),
          ];

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
        side: const BorderSide(color: AppColors.dialogBorder),
      ),
      title: title,
      content: content,
      actions: resolvedActions,
      contentPadding: contentPadding,
      actionsPadding: actionsPadding,
      buttonPadding: buttonPadding,
      insetPadding: insetPadding,
    );
  }
}
