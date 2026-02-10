import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';

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
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(UiConstants.smallSpacing),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
          ),
          child: SingleChildScrollView(
            child: SelectableText(trimmed),
          ),
        ),
      ],
    );
  }
}
