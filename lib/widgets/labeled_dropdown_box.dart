import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'labeled_group_box.dart';

class LabeledDropdownBox<T> extends StatefulWidget {
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
  State<LabeledDropdownBox<T>> createState() => _LabeledDropdownBoxState<T>();
}

class _LabeledDropdownBoxState<T> extends State<LabeledDropdownBox<T>> {
  final GlobalKey _fieldKey = GlobalKey();
  bool _menuOpen = false;

  Future<void> _openMenu() async {
    if (!widget.enabled || widget.onChanged == null) {
      return;
    }

    final fieldContext = _fieldKey.currentContext;
    if (fieldContext == null) {
      return;
    }
    final fieldBox = fieldContext.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (fieldBox == null || overlayBox == null) {
      return;
    }

    final topLeft = fieldBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = fieldBox.localToGlobal(
      Offset(fieldBox.size.width, fieldBox.size.height),
      ancestor: overlayBox,
    );

    final popupItems = widget.items.where((item) => item.value != null).toList();
    if (popupItems.isEmpty || !mounted) {
      return;
    }
    final popupBorderColor = widget.borderColor ?? AppColors.subtleBorder;
    const itemVerticalPadding = UiConstants.smallSpacing;
    const itemHeight = UiConstants.settingsFieldHeight;
    const maxMenuHeight = 280.0;
    final desiredHeight = (popupItems.length * itemHeight).clamp(0.0, maxMenuHeight);
    final spaceBelow = overlayBox.size.height - bottomRight.dy;
    final showBelow = spaceBelow >= desiredHeight || spaceBelow >= topLeft.dy;
    final top = showBelow
        ? bottomRight.dy
        : (topLeft.dy - desiredHeight).clamp(0.0, overlayBox.size.height - desiredHeight);
    final left = topLeft.dx.clamp(0.0, overlayBox.size.width - fieldBox.size.width);

    setState(() => _menuOpen = true);
    try {
      final selected = await showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        pageBuilder: (dialogContext, _, __) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: fieldBox.size.width,
                child: Material(
                  color: AppColors.pageBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                    side: BorderSide(color: popupBorderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: maxMenuHeight),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: popupItems.length,
                      itemBuilder: (context, index) {
                        final item = popupItems[index];
                        final value = item.value as T;
                        final isSelected = value == widget.value;
                        final enabled = item.enabled;
                        return InkWell(
                          onTap: enabled ? () => Navigator.of(dialogContext).pop(value) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UiConstants.tableRowHorizontalPadding,
                              vertical: itemVerticalPadding,
                            ),
                            color: isSelected ? AppColors.progressFillOverlay : Colors.transparent,
                            child: DefaultTextStyle.merge(
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: enabled
                                        ? (widget.textColor ?? AppColors.text)
                                        : AppColors.text.withValues(alpha: 0.45),
                                  ),
                              child: item.child,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        transitionBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 100),
      );

      if (selected != null && mounted) {
        widget.onChanged!(selected);
      }
    } finally {
      if (mounted) {
        setState(() => _menuOpen = false);
      }
    }
  }

  Widget _selectedChild() {
    for (final item in widget.items) {
      if (item.value == widget.value) {
        return item.child;
      }
    }
    if (widget.value != null) {
      return Text(widget.value.toString());
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor = widget.textColor;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: resolvedTextColor);
    final resolvedBorderColor = widget.borderColor ?? AppColors.subtleBorder;
    return LabeledGroupBox(
      label: widget.label,
      value: '',
      borderColor: resolvedBorderColor,
      textStyle: textStyle,
      backgroundColor: _menuOpen ? AppColors.progressFillOverlay : Colors.transparent,
      contentHeight: widget.contentHeight,
      contentPadding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Material(
              key: _fieldKey,
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.enabled ? _openMenu : null,
                borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UiConstants.tableRowHorizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: textStyle ?? const TextStyle(),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _selectedChild(),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: (textStyle?.color ?? Theme.of(context).textTheme.bodyMedium?.color)
                            ?.withValues(alpha: widget.enabled ? 1 : 0.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: UiConstants.smallSpacing),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
