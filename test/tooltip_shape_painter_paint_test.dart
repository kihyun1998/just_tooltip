import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:just_tooltip/src/tooltip_shape_painter.dart';

/// A [Canvas] that records the draw calls we care about; every other Canvas
/// method is forwarded to a no-op via [noSuchMethod].
class _RecordingCanvas implements Canvas {
  final List<Path> paths = [];
  final List<Paint> paints = [];
  int shadowCount = 0;

  @override
  void drawPath(Path path, Paint paint) {
    paths.add(path);
    paints.add(paint);
  }

  @override
  void drawShadow(
    Path path,
    Color color,
    double elevation,
    bool transparentOccluder,
  ) {
    shadowCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  Iterable<Paint> get fills =>
      paints.where((p) => p.style == PaintingStyle.fill);
  Iterable<Paint> get strokes =>
      paints.where((p) => p.style == PaintingStyle.stroke);
}

void main() {
  group('TooltipShapePainter.paint', () {
    test('fills with the theme background color', () {
      const theme = JustTooltipTheme(backgroundColor: Color(0xFF123456));
      const painter =
          TooltipShapePainter(direction: TooltipDirection.top, theme: theme);
      final canvas = _RecordingCanvas();

      painter.paint(canvas, const Size(120, 60));

      expect(canvas.fills, isNotEmpty);
      expect(canvas.fills.first.color.toARGB32(), 0xFF123456);
    });

    test('draws a border stroke only when borderColor and width are set', () {
      const withBorder = JustTooltipTheme(
        borderColor: Color(0xFFAABBCC),
        borderWidth: 2,
      );
      final c1 = _RecordingCanvas();
      const TooltipShapePainter(
              direction: TooltipDirection.top, theme: withBorder)
          .paint(c1, const Size(120, 60));
      expect(c1.strokes, isNotEmpty);
      expect(c1.strokes.first.color.toARGB32(), 0xFFAABBCC);
      expect(c1.strokes.first.strokeWidth, 2);

      const noBorder = JustTooltipTheme(); // borderColor null by default
      final c2 = _RecordingCanvas();
      const TooltipShapePainter(
              direction: TooltipDirection.top, theme: noBorder)
          .paint(c2, const Size(120, 60));
      expect(c2.strokes, isEmpty);
    });

    test('elevation uses drawShadow; boxShadow uses a blurred drawPath', () {
      const elevated = JustTooltipTheme(elevation: 4); // boxShadow null
      final c1 = _RecordingCanvas();
      const TooltipShapePainter(
              direction: TooltipDirection.top, theme: elevated)
          .paint(c1, const Size(120, 60));
      expect(c1.shadowCount, greaterThan(0),
          reason: 'elevation renders via canvas.drawShadow');

      const boxShadowed = JustTooltipTheme(
        boxShadow: [BoxShadow(color: Colors.black, blurRadius: 4)],
      );
      final c2 = _RecordingCanvas();
      const TooltipShapePainter(
              direction: TooltipDirection.top, theme: boxShadowed)
          .paint(c2, const Size(120, 60));
      expect(c2.shadowCount, 0, reason: 'boxShadow bypasses drawShadow');
      expect(c2.paints.any((p) => p.maskFilter != null), isTrue,
          reason: 'boxShadow is drawn as a blurred path');
    });

    test('the arrow tip reaches the target-facing edge in every direction', () {
      const size = Size(120, 60);
      // elevation 0 + no boxShadow + no border → a single fill drawPath.
      const theme =
          JustTooltipTheme(showArrow: true, arrowLength: 8, elevation: 0);

      Rect shapeBounds(TooltipDirection dir) {
        final canvas = _RecordingCanvas();
        TooltipShapePainter(direction: dir, theme: theme).paint(canvas, size);
        final bounds = canvas.paths.first.getBounds();
        // Stays within the canvas.
        expect(bounds.left, greaterThanOrEqualTo(-0.01));
        expect(bounds.top, greaterThanOrEqualTo(-0.01));
        expect(bounds.right, lessThanOrEqualTo(size.width + 0.01));
        expect(bounds.bottom, lessThanOrEqualTo(size.height + 0.01));
        return bounds;
      }

      // The arrow tip is the only geometry reaching the target-facing edge
      // (the rounded box stops arrowLength short of it).
      expect(
          shapeBounds(TooltipDirection.top).bottom, closeTo(size.height, 0.01));
      expect(shapeBounds(TooltipDirection.bottom).top, closeTo(0, 0.01));
      expect(
          shapeBounds(TooltipDirection.left).right, closeTo(size.width, 0.01));
      expect(shapeBounds(TooltipDirection.right).left, closeTo(0, 0.01));
    });

    // Centroid x of the arrow band (just inside the target-facing edge) for a
    // top-direction tooltip.
    double arrowTipX(TooltipAlignment alignment, {double? override}) {
      const size = Size(200, 60);
      const theme =
          JustTooltipTheme(showArrow: true, arrowLength: 8, elevation: 0);
      final canvas = _RecordingCanvas();
      TooltipShapePainter(
        direction: TooltipDirection.top,
        alignment: alignment,
        theme: theme,
        arrowCenterOverride: override,
      ).paint(canvas, size);
      final path = canvas.paths.first;
      final xs = <double>[];
      for (double x = 0; x <= size.width; x += 0.5) {
        if (path.contains(Offset(x, size.height - 2))) xs.add(x);
      }
      expect(xs, isNotEmpty, reason: 'arrow band present for $alignment');
      return xs.reduce((a, b) => a + b) / xs.length;
    }

    test('arrow shifts along the edge: start < center < end', () {
      final start = arrowTipX(TooltipAlignment.start);
      final center = arrowTipX(TooltipAlignment.center);
      final end = arrowTipX(TooltipAlignment.end);

      expect(start, lessThan(center));
      expect(center, lessThan(end));
    });

    test('targetCenter alignment places the arrow at the override position',
        () {
      // With an override far from center, the arrow tracks it (not the center).
      final tip = arrowTipX(TooltipAlignment.endTargetCenter, override: 40);
      expect(tip, closeTo(40, 6),
          reason: 'arrow follows arrowCenterOverride for targetCenter');
    });
  });
}
