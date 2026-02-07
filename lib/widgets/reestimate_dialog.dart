import 'package:flutter/material.dart';

import 'dialog_action_row.dart';

Future<String?> showReestimateDialog(
  BuildContext context,
) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final trimmed = controller.text.trim();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: 460,
                height: 180,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Ask for follow-up changes',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(),
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
                    width: 110,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel', textAlign: TextAlign.center),
                    ),
                  ),
                  DialogActionItem(
                    child: Expanded(
                      child: FilledButton.icon(
                        onPressed: trimmed.isEmpty
                            ? null
                            : () => Navigator.pop(context, trimmed),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Re-estimate', textAlign: TextAlign.center),
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
