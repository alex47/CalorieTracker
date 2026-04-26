import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../theme/ui_constants.dart';
import 'app_button.dart';
import 'app_dialog.dart';
import 'dialog_action_row.dart';
import 'labeled_input_box.dart';

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
          return AppDialog(
            content: Padding(
              padding: const EdgeInsets.only(top: UiConstants.mediumSpacing),
              child: SizedBox(
                width: UiConstants.reestimateDialogWidth,
                child: LabeledInputBox(
                  label: l10n.askFollowupChangesLabel,
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  minLines: 3,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  contentHeight: UiConstants.settingsFieldHeight,
                ),
              ),
            ),
            actionItems: [
              DialogActionItem(
                child: AppButton(
                  onPressed: trimmed.isEmpty
                      ? null
                      : () => Navigator.pop(context, trimmed),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: l10n.reestimateButton,
                ),
              ),
              DialogActionItem(
                width: UiConstants.buttonMinWidth,
                child: AppButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: l10n.cancelButton,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
