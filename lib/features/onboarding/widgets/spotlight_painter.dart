import 'package:flutter/material.dart';

/// Custom painter that draws a semi-transparent overlay with a
/// rounded-rectangle cutout (the "spotlight").
class SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final Color overlayColor;
  final double borderRadius;

  SpotlightPainter({
    required this.spotlightRect,
    required this.overlayColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final paint = Paint()..color = overlayColor;

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(
        RRect.fromRectAndRadius(
          spotlightRect,
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect ||
        oldDelegate.overlayColor != overlayColor;
  }
}
