import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class LabeledInputBox extends StatelessWidget {
  const LabeledInputBox({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.contentHeight = UiConstants.progressBarHeight,
    this.borderColor,
    this.textColor,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final double contentHeight;
  final Color? borderColor;
  final Color? textColor;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    assert(
      controller != null || initialValue != null,
      'Either controller or initialValue must be provided.',
    );
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
        child: controller != null
            ? TextField(
                controller: controller,
                enabled: enabled,
                readOnly: readOnly,
                obscureText: obscureText,
                keyboardType: keyboardType,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: textStyle,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: UiConstants.xSmallSpacing,
                  ),
                  suffixIcon: suffixIcon,
                ),
              )
            : TextFormField(
                initialValue: initialValue,
                enabled: enabled,
                readOnly: true,
                keyboardType: keyboardType,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 1,
                style: textStyle,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: UiConstants.xSmallSpacing,
                  ),
                  suffixIcon: suffixIcon,
                ),
              ),
      ),
    );
  }
}
