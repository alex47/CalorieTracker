import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class LabeledInputBox extends StatelessWidget {
  const LabeledInputBox({
    super.key,
    required this.label,
    required this.controller,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.contentHeight = UiConstants.progressBarHeight,
    this.borderColor,
    this.textColor,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final double contentHeight;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: resolvedTextColor);
    final resolvedBorderColor = borderColor ?? AppColors.subtleBorder;
    return LabeledGroupBox(
      label: label,
      value: '',
      borderColor: resolvedBorderColor,
      textStyle: textStyle,
      backgroundColor: Colors.transparent,
      contentHeight: contentHeight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UiConstants.tableRowHorizontalPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          minLines: 1,
          maxLines: 1,
          textAlignVertical: TextAlignVertical.center,
          style: textStyle,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              vertical: UiConstants.xSmallSpacing,
            ),
          ),
        ),
      ),
    );
  }
}

class LabeledDropdownBox<T> extends StatelessWidget {
  const LabeledDropdownBox({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.trailing,
    this.contentHeight = UiConstants.progressBarHeight,
    this.borderColor,
    this.textColor,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final Widget? trailing;
  final double contentHeight;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = textColor;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: resolvedTextColor);
    final resolvedBorderColor = borderColor ?? AppColors.subtleBorder;
    return LabeledGroupBox(
      label: label,
      value: '',
      borderColor: resolvedBorderColor,
      textStyle: textStyle,
      backgroundColor: Colors.transparent,
      contentHeight: contentHeight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UiConstants.tableRowHorizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                isExpanded: true,
                style: textStyle,
                dropdownColor: Theme.of(context).colorScheme.surface,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: UiConstants.smallSpacing),
            trailing!,
          ],
        ],
      ),
    );
  }
}
