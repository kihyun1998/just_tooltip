import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:just_tooltip/src/tooltip_shape_painter.dart';

/// The arrow and the body are placed from the same alignment, including where
/// RTL mirrors `start` and `end` for top and bottom tooltips.
void main() {
  /// A 100-wide target in the middle of an 800-wide screen (x 350–450) with a
  /// 200-wide tooltip, so `start` and `end` put the body past either edge.
  Future<void> showTooltip(
    WidgetTester tester, {
    required TextDirection textDirection,
    required TooltipDirection direction,
    required TooltipAlignment alignment,
    Alignment targetAt = Alignment.center,
  }) async {
    final controller = JustTooltipController();
    await tester.pumpWidget(
      MaterialApp(
        // Above the Overlay, where the tooltip reads its direction.
        builder: (context, child) =>
            Directionality(textDirection: textDirection, child: child!),
        home: Scaffold(
          body: Align(
            alignment: targetAt,
            child: JustTooltip(
              controller: controller,
              enableHover: false,
              direction: direction,
              alignment: alignment,
              theme: const JustTooltipTheme(showArrow: true),
              tooltipBuilder: (context) =>
                  const SizedBox(width: 200, height: 30),
              child: const SizedBox(key: Key('target'), width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
  }

  /// The global x of the arrow tip: the middle of the painted path one and a
  /// half pixels in from the edge that faces the target.
  double arrowTipX(WidgetTester tester, TooltipDirection direction) {
    final paint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is TooltipShapePainter,
    );
    final painter =
        tester.widget<CustomPaint>(paint).painter! as TooltipShapePainter;
    final box = tester.getRect(paint);
    final canvas = _PathCanvas();
    painter.paint(canvas, box.size);
    final y = direction == TooltipDirection.top ? box.height - 1.5 : 1.5;
    final xs = [
      for (var x = 0.0; x < box.width; x += 0.5)
        if (canvas.paths.last.contains(Offset(x, y))) x,
    ];
    return box.left + (xs.first + xs.last) / 2;
  }

  for (final textDirection in TextDirection.values) {
    for (final direction in [TooltipDirection.top, TooltipDirection.bottom]) {
      for (final alignment in TooltipAlignment.values) {
        testWidgets(
          '$textDirection $direction $alignment: the body and the arrow '
          'line up with the target',
          (tester) async {
            await showTooltip(
              tester,
              textDirection: textDirection,
              direction: direction,
              alignment: alignment,
            );

            final target = tester.getRect(find.byKey(const Key('target')));
            final tip = arrowTipX(tester, direction);
            expect(tip, inInclusiveRange(target.left, target.right));

            // `start` is the target's left edge in LTR and its right edge in
            // RTL; the *TargetCenter variants align like their edge.
            final body = tester.getRect(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is TooltipShapePainter,
              ),
            );
            final leading =
                alignment == TooltipAlignment.start ||
                alignment == TooltipAlignment.startTargetCenter;
            final trailing =
                alignment == TooltipAlignment.end ||
                alignment == TooltipAlignment.endTargetCenter;
            final rtl = textDirection == TextDirection.rtl;
            if (leading && !rtl || trailing && rtl) {
              expect(
                body.left,
                target.left,
                reason: 'aligned to the left edge',
              );
            } else if (leading || trailing) {
              expect(
                body.right,
                target.right,
                reason: 'aligned to the right edge',
              );
            } else {
              expect(body.center.dx, target.center.dx);
            }
          },
        );
      }
    }
  }

  testWidgets('a top tooltip flipped to the bottom keeps the RTL alignment', (
    tester,
  ) async {
    // At the top of the screen there is no room above, so `top` flips.
    await showTooltip(
      tester,
      textDirection: TextDirection.rtl,
      direction: TooltipDirection.top,
      alignment: TooltipAlignment.start,
      targetAt: Alignment.topCenter,
    );

    final target = tester.getRect(find.byKey(const Key('target')));
    final body = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TooltipShapePainter,
      ),
    );
    expect(body.top, greaterThan(target.bottom), reason: 'it flipped');
    expect(body.right, target.right, reason: 'RTL start is the right edge');
    expect(
      arrowTipX(tester, TooltipDirection.bottom),
      inInclusiveRange(target.left, target.right),
    );
  });
}

/// Records the paths drawn on it and ignores everything else.
class _PathCanvas implements Canvas {
  final paths = <Path>[];

  @override
  void drawPath(Path path, Paint paint) => paths.add(path);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
