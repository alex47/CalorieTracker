import 'package:flutter/material.dart';

class LabeledGroupBox extends StatelessWidget {
  const LabeledGroupBox({
    super.key,
    required this.label,
    required this.value,
    required this.borderColor,
    required this.textStyle,
    this.child,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 10, 12, 6),
    this.contentHeight,
    this.minWidth,
    this.backgroundColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final Color borderColor;
  final TextStyle? textStyle;
  final Widget? child;
  final EdgeInsetsGeometry contentPadding;
  final double? contentHeight;
  final double? minWidth;
  final Color? backgroundColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const gapStart = 10.0;
    const gapHorizontalPadding = 4.0;
    final labelStyle = textTheme.bodySmall?.copyWith(color: labelColor ?? borderColor);
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final labelGapWidth = labelPainter.width + (gapHorizontalPadding * 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: minWidth == null ? null : BoxConstraints(minWidth: minWidth!),
          height: contentHeight,
          padding: contentPadding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child == null
              ? Text(value, style: textStyle)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: NotchedBorderPainter(
                color: borderColor,
                radius: 8,
                topInset: 8,
                gapStart: gapStart,
                gapWidth: labelGapWidth,
              ),
            ),
          ),
        ),
        Positioned(
          left: gapStart,
          top: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: gapHorizontalPadding),
            child: Text(
              label,
              style: labelStyle,
            ),
          ),
        ),
      ],
    );
  }
}

class MetricGroupBox extends StatelessWidget {
  const MetricGroupBox({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.minWidth = 100,
    this.contentHeight = 36,
  });

  final String label;
  final String value;
  final Color color;
  final double minWidth;
  final double contentHeight;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);
    return LabeledGroupBox(
      label: label,
      value: '',
      borderColor: color,
      textStyle: valueStyle,
      contentHeight: contentHeight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: Text(value, style: valueStyle),
      ),
      minWidth: minWidth,
      backgroundColor: color.withOpacity(0.14),
      labelColor: color,
    );
  }
}

class NotchedBorderPainter extends CustomPainter {
  const NotchedBorderPainter({
    required this.color,
    required this.radius,
    required this.topInset,
    required this.gapStart,
    required this.gapWidth,
  });

  final Color color;
  final double radius;
  final double topInset;
  final double gapStart;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, topInset, size.width, size.height - topInset);
    final r = radius.clamp(0.0, rect.height / 2);
    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;

    final topStart = left + r;
    final topEnd = right - r;
    final minGapStart = topStart + 2;
    final maxGapEnd = topEnd - 2;

    var gapL = left + gapStart;
    var gapR = gapL + gapWidth;
    if (gapL < minGapStart) {
      gapL = minGapStart;
      gapR = gapL + gapWidth;
    }
    if (gapR > maxGapEnd) {
      gapR = maxGapEnd;
      gapL = gapR - gapWidth;
      if (gapL < minGapStart) {
        gapL = minGapStart;
      }
    }

    final path = Path()..moveTo(topStart, top);
    if (gapL > topStart) {
      path.lineTo(gapL, top);
    }
    path.moveTo(gapR, top);
    path.lineTo(topEnd, top);
    path.arcToPoint(
      Offset(right, top + r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(right, bottom - r);
    path.arcToPoint(
      Offset(right - r, bottom),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(left + r, bottom);
    path.arcToPoint(
      Offset(left, bottom - r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(left, top + r);
    path.arcToPoint(
      Offset(left + r, top),
      radius: Radius.circular(r),
      clockwise: true,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NotchedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.topInset != topInset ||
        oldDelegate.gapStart != gapStart ||
        oldDelegate.gapWidth != gapWidth;
  }
}
