import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/day_summary.dart';
import '../theme/ui_constants.dart';
import 'app_dialog.dart';
import 'dialog_action_row.dart';

Future<void> showDaySummaryDialog({
  required BuildContext context,
  required DaySummary summary,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AppDialog(
        title: Text(l10n.dailySummaryTitle),
        content: SizedBox(
          width: UiConstants.reestimateDialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(summary.summary),
                const SizedBox(height: UiConstants.mediumSpacing),
                _SummarySection(
                  title: l10n.dailySummaryHighlightsTitle,
                  items: summary.highlights,
                ),
                const SizedBox(height: UiConstants.smallSpacing),
                _SummarySection(
                  title: l10n.dailySummaryIssuesTitle,
                  items: summary.issues,
                ),
                const SizedBox(height: UiConstants.smallSpacing),
                _SummarySection(
                  title: l10n.dailySummarySuggestionsTitle,
                  items: summary.suggestions,
                ),
              ],
            ),
          ),
        ),
        actionItems: [
          DialogActionItem(
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              label: Text(l10n.acceptButton, textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    },
  );
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: UiConstants.xxSmallSpacing),
        if (items.isEmpty)
          Text(
            '-',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: UiConstants.xxSmallSpacing),
              child: Text('• $item'),
            ),
          ),
      ],
    );
  }
}
