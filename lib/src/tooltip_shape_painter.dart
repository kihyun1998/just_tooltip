import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'enums.dart';
import 'just_tooltip_theme.dart';

/// A [CustomPainter] that draws a tooltip shape as a single unified path:
/// a rounded rectangle with an optional triangular arrow seamlessly connected.
///
/// When [theme.showArrow] is `true`, the arrow is integrated into the path so
/// that background fill, shadow, and border stroke all follow the combined
/// outline.
class TooltipShapePainter extends CustomPainter {
  const TooltipShapePainter({
    required this.direction,
    required this.theme,
    this.alignment = TooltipAlignment.center,
  });

  /// The resolved direction of the tooltip (after auto-flip).
  final TooltipDirection direction;

  /// The cross-axis alignment, used to position the arrow.
  final TooltipAlignment alignment;

  /// The visual theme containing colors, border, arrow dimensions, etc.
  final JustTooltipTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Draw shadows.
    if (theme.boxShadow != null) {
      for (final shadow in theme.boxShadow!) {
        final shadowPath = path.shift(shadow.offset);
        canvas.drawPath(
          shadowPath,
          Paint()
            ..color = shadow.color
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _convertRadiusToSigma(shadow.blurRadius),
            ),
        );
      }
    } else if (theme.elevation > 0) {
      canvas.drawShadow(path, const Color(0xFF000000), theme.elevation, false);
    }

    // Fill.
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.backgroundColor
        ..style = PaintingStyle.fill,
    );

    // Border stroke.
    if (theme.borderColor != null && theme.borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = theme.borderWidth,
      );
    }
  }

  Path _buildPath(Size size) {
    if (!theme.showArrow) {
      return Path()..addRRect(theme.borderRadius.toRRect(Offset.zero & size));
    }

    switch (direction) {
      case TooltipDirection.top:
        return _buildTopPath(size);
      case TooltipDirection.bottom:
        return _buildBottomPath(size);
      case TooltipDirection.left:
        return _buildLeftPath(size);
      case TooltipDirection.right:
        return _buildRightPath(size);
    }
  }

  /// Computes the arrow center along the cross-axis based on [alignment].
  ///
  /// [tooltipCrossSize] is the tooltip's cross-axis dimension.
  /// [minEdge] / [maxEdge] are the border-radius insets on the start/end side.
  double _arrowCenter(double tooltipCrossSize, double minEdge, double maxEdge) {
    final halfBase = theme.arrowBaseWidth / 2;
    final lo = minEdge + halfBase;
    final hi = tooltipCrossSize - maxEdge - halfBase;

    final hiClamped = math.max(lo, hi);
    final center = switch (alignment) {
      TooltipAlignment.start =>
        lo + (hiClamped - lo) * theme.arrowPositionRatio,
      TooltipAlignment.center => tooltipCrossSize / 2,
      TooltipAlignment.end =>
        lo + (hiClamped - lo) * (1 - theme.arrowPositionRatio),
    };
    return center.clamp(lo, hiClamped);
  }

  /// Arrow on the bottom edge, pointing down toward the target.
  Path _buildTopPath(Size size) {
    final boxBottom = size.height - theme.arrowLength;
    final rrect = theme.borderRadius.toRRect(
      Rect.fromLTWH(0, 0, size.width, boxBottom),
    );
    final cx = _arrowCenter(size.width, rrect.blRadiusX, rrect.brRadiusX);
    final halfBase = theme.arrowBaseWidth / 2;

    return _tracePath(
      rrect: rrect,
      arrowEdge: _ArrowEdge.bottom,
      arrowStart: math.max(cx - halfBase, rrect.blRadiusX),
      arrowEnd: math.min(cx + halfBase, size.width - rrect.brRadiusX),
      arrowTip: Offset(cx, size.height),
    );
  }

  /// Arrow on the top edge, pointing up toward the target.
  Path _buildBottomPath(Size size) {
    final rrect = theme.borderRadius.toRRect(
      Rect.fromLTWH(
          0, theme.arrowLength, size.width, size.height - theme.arrowLength),
    );
    final cx = _arrowCenter(size.width, rrect.tlRadiusX, rrect.trRadiusX);
    final halfBase = theme.arrowBaseWidth / 2;

    return _tracePath(
      rrect: rrect,
      arrowEdge: _ArrowEdge.top,
      arrowStart: math.max(cx - halfBase, rrect.tlRadiusX),
      arrowEnd: math.min(cx + halfBase, size.width - rrect.trRadiusX),
      arrowTip: Offset(cx, 0),
    );
  }

  /// Arrow on the right edge, pointing right toward the target.
  Path _buildLeftPath(Size size) {
    final boxRight = size.width - theme.arrowLength;
    final rrect = theme.borderRadius.toRRect(
      Rect.fromLTWH(0, 0, boxRight, size.height),
    );
    final cy = _arrowCenter(size.height, rrect.trRadiusY, rrect.brRadiusY);
    final halfBase = theme.arrowBaseWidth / 2;

    return _tracePath(
      rrect: rrect,
      arrowEdge: _ArrowEdge.right,
      arrowStart: math.max(cy - halfBase, rrect.trRadiusY),
      arrowEnd: math.min(cy + halfBase, size.height - rrect.brRadiusY),
      arrowTip: Offset(size.width, cy),
    );
  }

  /// Arrow on the left edge, pointing left toward the target.
  Path _buildRightPath(Size size) {
    final rrect = theme.borderRadius.toRRect(
      Rect.fromLTWH(
          theme.arrowLength, 0, size.width - theme.arrowLength, size.height),
    );
    final cy = _arrowCenter(size.height, rrect.tlRadiusY, rrect.blRadiusY);
    final halfBase = theme.arrowBaseWidth / 2;

    return _tracePath(
      rrect: rrect,
      arrowEdge: _ArrowEdge.left,
      arrowStart: math.max(cy - halfBase, rrect.tlRadiusY),
      arrowEnd: math.min(cy + halfBase, size.height - rrect.blRadiusY),
      arrowTip: Offset(0, cy),
    );
  }

  /// Traces a closed clockwise path around the rounded rect, inserting an
  /// arrow triangle on the specified edge.
  ///
  /// For horizontal edges (top/bottom), [arrowStart]/[arrowEnd] are x coords.
  /// For vertical edges (left/right), they are y coords (start < end).
  Path _tracePath({
    required RRect rrect,
    required _ArrowEdge arrowEdge,
    required double arrowStart,
    required double arrowEnd,
    required Offset arrowTip,
  }) {
    final path = Path();

    // Start after top-left corner arc.
    path.moveTo(rrect.left + rrect.tlRadiusX, rrect.top);

    // ── Top edge (left → right) ──
    if (arrowEdge == _ArrowEdge.top) {
      path.lineTo(arrowStart, rrect.top);
      path.lineTo(arrowTip.dx, arrowTip.dy);
      path.lineTo(arrowEnd, rrect.top);
    }
    path.lineTo(rrect.right - rrect.trRadiusX, rrect.top);

    // Top-right corner.
    _arcCorner(path, rrect, _Corner.topRight);

    // ── Right edge (top → bottom) ──
    if (arrowEdge == _ArrowEdge.right) {
      path.lineTo(rrect.right, arrowStart);
      path.lineTo(arrowTip.dx, arrowTip.dy);
      path.lineTo(rrect.right, arrowEnd);
    }
    path.lineTo(rrect.right, rrect.bottom - rrect.brRadiusY);

    // Bottom-right corner.
    _arcCorner(path, rrect, _Corner.bottomRight);

    // ── Bottom edge (right → left) ──
    if (arrowEdge == _ArrowEdge.bottom) {
      path.lineTo(arrowEnd, rrect.bottom);
      path.lineTo(arrowTip.dx, arrowTip.dy);
      path.lineTo(arrowStart, rrect.bottom);
    }
    path.lineTo(rrect.left + rrect.blRadiusX, rrect.bottom);

    // Bottom-left corner.
    _arcCorner(path, rrect, _Corner.bottomLeft);

    // ── Left edge (bottom → top) ──
    if (arrowEdge == _ArrowEdge.left) {
      path.lineTo(rrect.left, arrowEnd);
      path.lineTo(arrowTip.dx, arrowTip.dy);
      path.lineTo(rrect.left, arrowStart);
    }
    path.lineTo(rrect.left, rrect.top + rrect.tlRadiusY);

    // Top-left corner.
    _arcCorner(path, rrect, _Corner.topLeft);

    path.close();
    return path;
  }

  void _arcCorner(Path path, RRect rrect, _Corner corner) {
    late Rect arcRect;
    late double startAngle;

    switch (corner) {
      case _Corner.topLeft:
        if (rrect.tlRadiusX == 0 && rrect.tlRadiusY == 0) return;
        arcRect = Rect.fromLTWH(
          rrect.left,
          rrect.top,
          rrect.tlRadiusX * 2,
          rrect.tlRadiusY * 2,
        );
        startAngle = math.pi; // 180°
      case _Corner.topRight:
        if (rrect.trRadiusX == 0 && rrect.trRadiusY == 0) return;
        arcRect = Rect.fromLTWH(
          rrect.right - rrect.trRadiusX * 2,
          rrect.top,
          rrect.trRadiusX * 2,
          rrect.trRadiusY * 2,
        );
        startAngle = -math.pi / 2; // 270°
      case _Corner.bottomRight:
        if (rrect.brRadiusX == 0 && rrect.brRadiusY == 0) return;
        arcRect = Rect.fromLTWH(
          rrect.right - rrect.brRadiusX * 2,
          rrect.bottom - rrect.brRadiusY * 2,
          rrect.brRadiusX * 2,
          rrect.brRadiusY * 2,
        );
        startAngle = 0; // 0°
      case _Corner.bottomLeft:
        if (rrect.blRadiusX == 0 && rrect.blRadiusY == 0) return;
        arcRect = Rect.fromLTWH(
          rrect.left,
          rrect.bottom - rrect.blRadiusY * 2,
          rrect.blRadiusX * 2,
          rrect.blRadiusY * 2,
        );
        startAngle = math.pi / 2; // 90°
    }

    path.arcTo(arcRect, startAngle, math.pi / 2, false);
  }

  static double _convertRadiusToSigma(double radius) {
    return radius > 0 ? radius * 0.57735 + 0.5 : 0;
  }

  @override
  bool shouldRepaint(TooltipShapePainter oldDelegate) {
    return direction != oldDelegate.direction ||
        alignment != oldDelegate.alignment ||
        theme != oldDelegate.theme;
  }
}

enum _ArrowEdge { top, bottom, left, right }

enum _Corner { topLeft, topRight, bottomRight, bottomLeft }
