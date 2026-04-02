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
    this.minLines = 1,
    this.maxLines = 1,
    this.borderColor,
    this.textColor,
    this.suffixIcon,
    this.autofocus = false,
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
  final int minLines;
  final int maxLines;
  final Color? borderColor;
  final Color? textColor;
  final Widget? suffixIcon;
  final bool autofocus;

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
      contentHeight: maxLines > 1 ? null : contentHeight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UiConstants.tableRowHorizontalPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: controller != null
            ? TextField(
                controller: controller,
                autofocus: autofocus,
                enabled: enabled,
                readOnly: readOnly,
                obscureText: obscureText,
                keyboardType: keyboardType,
                onChanged: onChanged,
                minLines: minLines,
                maxLines: maxLines,
                textAlignVertical: maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
                style: textStyle,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: maxLines > 1
                      ? const EdgeInsets.only(
                          top: UiConstants.mediumSpacing,
                          bottom: UiConstants.mediumSpacing,
                        )
                      : const EdgeInsets.symmetric(
                          vertical: UiConstants.xSmallSpacing,
                        ),
                  suffixIcon: suffixIcon,
                ),
              )
            : TextFormField(
                initialValue: initialValue,
                autofocus: autofocus,
                enabled: enabled,
                readOnly: true,
                keyboardType: keyboardType,
                onChanged: onChanged,
                minLines: minLines,
                maxLines: maxLines,
                style: textStyle,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: maxLines > 1
                      ? const EdgeInsets.only(
                          top: UiConstants.mediumSpacing,
                          bottom: UiConstants.mediumSpacing,
                        )
                      : const EdgeInsets.symmetric(
                          vertical: UiConstants.xSmallSpacing,
                        ),
                  suffixIcon: suffixIcon,
                ),
              ),
      ),
    );
  }
}
