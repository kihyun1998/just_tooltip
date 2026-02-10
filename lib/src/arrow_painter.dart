import 'package:flutter/rendering.dart';

import 'enums.dart';

/// A [CustomPainter] that draws a triangular arrow pointing in the given
/// [direction].
///
/// For [TooltipDirection.top] and [TooltipDirection.bottom], the arrow size is
/// `Size(arrowWidth, arrowHeight)`.
/// For [TooltipDirection.left] and [TooltipDirection.right], the arrow size is
/// `Size(arrowHeight, arrowWidth)`.
class ArrowPainter extends CustomPainter {
  const ArrowPainter({
    required this.direction,
    required this.color,
  });

  /// The direction the arrow points toward (i.e., the direction from tooltip
  /// to child).
  final TooltipDirection direction;

  /// The fill color of the arrow.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = _buildPath(size);
    canvas.drawPath(path, paint);
  }

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;

    switch (direction) {
      // Arrow points downward (tooltip is above the child).
      case TooltipDirection.top:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w / 2, h)
          ..lineTo(w, 0)
          ..close();

      // Arrow points upward (tooltip is below the child).
      case TooltipDirection.bottom:
        return Path()
          ..moveTo(0, h)
          ..lineTo(w / 2, 0)
          ..lineTo(w, h)
          ..close();

      // Arrow points rightward (tooltip is to the left of the child).
      case TooltipDirection.left:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w, h / 2)
          ..lineTo(0, h)
          ..close();

      // Arrow points leftward (tooltip is to the right of the child).
      case TooltipDirection.right:
        return Path()
          ..moveTo(w, 0)
          ..lineTo(0, h / 2)
          ..lineTo(w, h)
          ..close();
    }
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) =>
      direction != oldDelegate.direction || color != oldDelegate.color;
}
