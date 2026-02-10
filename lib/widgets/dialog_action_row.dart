import 'package:flutter/material.dart';

import '../theme/ui_constants.dart';

class DialogActionItem {
  const DialogActionItem({
    required this.child,
    this.width,
  });

  final Widget child;
  final double? width;
}

class DialogActionRow extends StatelessWidget {
  const DialogActionRow({
    super.key,
    required this.items,
    this.spacing = UiConstants.buttonSpacing,
    this.alignment = MainAxisAlignment.end,
  });

  final List<DialogActionItem> items;
  final double spacing;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final button = item.width == null
          ? item.child
          : SizedBox(width: item.width, child: item.child);
      children.add(button);
      if (i != items.length - 1) {
        children.add(SizedBox(width: spacing));
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: alignment,
        children: children,
      ),
    );
  }
}
