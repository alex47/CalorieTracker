import 'package:flutter/material.dart';

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
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
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
                    labelText: 'Food and amounts',
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
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: trimmed.isEmpty
                            ? null
                            : () => Navigator.pop(context, trimmed),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Re-estimate', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
