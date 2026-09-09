// PROTOTYPE — throwaway. Branch prototype/preview-overlay, issue #53.
//
// Question: does a JustTooltip land correctly inside flutter_example_template's
// PreviewStage, which owns its own Overlay and reports its frame as the whole
// screen?
//
// Numbers, not eyeballs. Each probe prints what it measured.

import 'package:flutter/material.dart';
import 'package:flutter_example_template/flutter_example_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

const _spec = ViewportSpec.mobile; // 390 x 844
const _window = Size(1400, 1000); // frame is centred, 78px of room above it

void _sized(WidgetTester tester) {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A target [top] px below the frame's top edge, tooltip pointing up.
Widget _app({
  required GlobalKey frameKey,
  required JustTooltipController controller,
  required double top,
  double left = 150,
  bool framed = true,
  TooltipDirection direction = TooltipDirection.top,
}) {
  final subject = Stack(
    children: [
      Positioned(
        left: left,
        top: top,
        child: JustTooltip(
          controller: controller,
          message: 'TIP',
          direction: direction,
          enableHover: false,
          animation: TooltipAnimation.none,
          child: Container(width: 40, height: 20, color: Colors.blue),
        ),
      ),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: framed
            ? KeyedSubtree(
                key: frameKey,
                child: PreviewStage(spec: _spec, child: subject),
              )
            : SizedBox(
                key: frameKey,
                width: _spec.width,
                height: _spec.height,
                child: subject,
              ),
      ),
    ),
  );
}

void main() {
  testWidgets('P1 · tooltip lands inside the frame, not displaced by its inset',
      (tester) async {
    _sized(tester);
    final key = GlobalKey();
    final c = JustTooltipController();
    await tester.pumpWidget(
      _app(frameKey: key, controller: c, top: 400),
    );
    c.show();
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(key));
    final tip = tester.getRect(find.text('TIP'));
    debugPrint('P1 frame=$frame');
    debugPrint('P1 tip  =$tip');

    expect(frame.contains(tip.topLeft), isTrue, reason: 'tip left frame');
    expect(frame.contains(tip.bottomRight), isTrue, reason: 'tip left frame');
  });

  testWidgets('P2 · flip is measured against the FRAME (framed: expect flip)',
      (tester) async {
    _sized(tester);
    final key = GlobalKey();
    final c = JustTooltipController();
    // 20px below the frame's top edge: no room above inside the frame,
    // but 78 + 20 = 98px of room above inside the window.
    await tester.pumpWidget(_app(frameKey: key, controller: c, top: 20));
    c.show();
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(key));
    final tip = tester.getRect(find.text('TIP'));
    final target = tester.getRect(find.byType(Container).last);
    debugPrint('P2 framed frame=$frame');
    debugPrint('P2 framed target=$target');
    debugPrint('P2 framed tip=$tip  flipped=${tip.top > target.top}');

    expect(tip.top, greaterThan(target.top),
        reason: 'should have flipped below the target');
  });

  testWidgets('P2b · REDDEN: unframed, same geometry, must NOT flip',
      (tester) async {
    _sized(tester);
    final key = GlobalKey();
    final c = JustTooltipController();
    await tester.pumpWidget(
      _app(frameKey: key, controller: c, top: 20, framed: false),
    );
    c.show();
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byType(Container).last);
    final tip = tester.getRect(find.text('TIP'));
    debugPrint('P2b unframed target=$target');
    debugPrint('P2b unframed tip=$tip  flipped=${tip.top > target.top}');

    expect(tip.top, lessThan(target.top),
        reason: 'window has room above; without the frame it must not flip');
  });

  testWidgets('P3 · screenMargin clamps to the frame edge', (tester) async {
    _sized(tester);
    final key = GlobalKey();
    final c = JustTooltipController();
    await tester.pumpWidget(
      _app(frameKey: key, controller: c, top: 400, left: 2),
    );
    c.show();
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(key));
    final tip = tester.getRect(find.text('TIP'));
    debugPrint('P3 frame.left=${frame.left} tip.left=${tip.left} '
        'delta=${tip.left - frame.left}');

    expect(tip.left, greaterThanOrEqualTo(frame.left),
        reason: 'clamped to the frame, not the window');
  });
}
