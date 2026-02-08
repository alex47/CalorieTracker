import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'dialog_action_row.dart';

Future<String?> showReestimateDialog(
  BuildContext context,
) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final controller = TextEditingController();
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final trimmed = controller.text.trim();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
              side: const BorderSide(
                color: AppColors.dialogBorder,
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: UiConstants.mediumSpacing),
              child: SizedBox(
                width: UiConstants.reestimateDialogWidth,
                height: UiConstants.reestimateDialogHeight,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.askFollowupChangesLabel,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: const OutlineInputBorder(),
                  ),
                  expands: true,
                  minLines: null,
                  maxLines: null,
                ),
              ),
            ),
            actions: [
              DialogActionRow(
                alignment: MainAxisAlignment.start,
                items: [
                  DialogActionItem(
                    width: UiConstants.buttonMinWidth,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.cancelButton, textAlign: TextAlign.center),
                    ),
                  ),
                  DialogActionItem(
                    child: Expanded(
                      child: FilledButton.icon(
                        onPressed: trimmed.isEmpty
                            ? null
                            : () => Navigator.pop(context, trimmed),
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(l10n.reestimateButton, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}
