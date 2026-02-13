import 'package:flutter/material.dart';

import '../../theme/ui_constants.dart';

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
      ..strokeWidth = UiConstants.borderWidth
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
