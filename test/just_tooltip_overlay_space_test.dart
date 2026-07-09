import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// The tooltip is laid out inside its [Overlay], so the target it is positioned
/// against must be expressed in that Overlay's coordinate space — not the
/// window's. The two coincide for a full-window `MaterialApp`, which is why an
/// inset Overlay is needed to tell them apart.
void main() {
  const inset = EdgeInsets.only(left: 200, top: 100);

  /// A tooltip inside an [Overlay] that does not start at the window origin.
  Widget insetOverlayApp() {
    return MaterialApp(
      home: Padding(
        padding: inset,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Center(
                child: JustTooltip(
                  tooltipBuilder: (context) => const SizedBox(
                    key: Key('tip'),
                    width: 100,
                    height: 40,
                  ),
                  child: const SizedBox(
                    key: Key('target'),
                    width: 60,
                    height: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<TestGesture> hoverTarget(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
    return gesture;
  }

  testWidgets(
      'an Overlay inset from the window still centres the tooltip '
      'on its target', (tester) async {
    await tester.pumpWidget(insetOverlayApp());
    await hoverTarget(tester);
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(const Key('target')));
    final tip = tester.getRect(find.byKey(const Key('tip')));

    // TooltipAlignment.center: the tooltip is centred on the target's
    // cross-axis. The default TooltipDirection.top puts it above.
    expect(tip.center.dx, moreOrLessEquals(target.center.dx, epsilon: 0.5),
        reason: 'the tooltip is centred on its target, not on the Overlay '
            'offset by the same amount');
    expect(tip.bottom, lessThanOrEqualTo(target.top),
        reason: 'a top-direction tooltip sits above its target');
  });

  testWidgets(
      'direction flipping measures space inside the Overlay, not the '
      'window', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Padding(
          padding: inset,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Align(
                  alignment: Alignment.topCenter,
                  // 20px below the Overlay's top edge: no room for a
                  // top-direction tooltip here. The window, however, has the
                  // inset's 100px of slack above.
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: JustTooltip(
                      // Zero padding makes the 'tip' box the tooltip box, so
                      // the `offset` gap can be measured directly.
                      theme: const JustTooltipTheme(padding: EdgeInsets.zero),
                      tooltipBuilder: (context) => const SizedBox(
                        key: Key('tip'),
                        width: 100,
                        height: 40,
                      ),
                      child: const SizedBox(
                        key: Key('target'),
                        width: 60,
                        height: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await hoverTarget(tester);
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(const Key('target')));
    final tip = tester.getRect(find.byKey(const Key('tip')));

    // Not merely "below the target" — a target rect displaced by the inset
    // also lands below it, for the wrong reason. The tooltip must sit exactly
    // one `offset` (8, the default) under the target's bottom edge.
    expect(tip.top, moreOrLessEquals(target.bottom + 8, epsilon: 0.5),
        reason: 'too little room above inside the Overlay, so it flips down '
            'and hangs one offset below the target');
  });
}
