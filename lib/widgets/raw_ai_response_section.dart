import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class RawAiResponseSection extends StatelessWidget {
  const RawAiResponseSection({
    super.key,
    required this.title,
    required this.responseText,
  });

  final String title;
  final String responseText;

  @override
  Widget build(BuildContext context) {
    final trimmed = responseText.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      key: ValueKey(trimmed.hashCode),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.text),
      ),
      iconColor: AppColors.text,
      collapsedIconColor: AppColors.text,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        LabeledGroupBox(
          label: '',
          value: '',
          borderColor: AppColors.subtleBorder,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, minWidth: double.infinity),
            child: Padding(
              padding: const EdgeInsets.all(UiConstants.smallSpacing),
              child: SingleChildScrollView(
                child: SelectableText(trimmed),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
