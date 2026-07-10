import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:just_tooltip/src/just_tooltip_overlay.dart';

/// Adds the pointer clear of every child before moving onto [at].
///
/// `addPointer(location: Offset.zero)` would land inside a child pinned to the
/// top-left, firing `onEnter` at the origin and freezing a pointer anchor there.
Future<void> hoverAt(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(700, 500));
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(at);
  await tester.pumpAndSettle();
}

Rect tipRect(WidgetTester tester) =>
    tester.getRect(find.byType(JustTooltipOverlay));

/// A 900px child inside a 400px horizontally scrolling viewport.
Widget wideRowInViewport() {
  return const MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: JustTooltip(
              message: 'T',
              child: SizedBox(width: 900, height: 100),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a child wider than its viewport anchors inside the visible band',
      (tester) async {
    await tester.pumpWidget(wideRowInViewport());
    await hoverAt(tester, const Offset(200, 50));

    // Visible band is 0..400; the child's own centre is 450.
    expect(tipRect(tester).center.dx, 200.0,
        reason:
            'the centre of child (0..900) intersected with the clip (0..400)');
    expect(tipRect(tester).left, lessThan(400),
        reason: 'the tooltip is inside the scroll view that owns it');
  });

  testWidgets('a plain ClipRect clips the target too, not just viewports',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 100,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: 900,
                  child: const JustTooltip(
                    message: 'T',
                    child: SizedBox(width: 900, height: 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await hoverAt(tester, const Offset(200, 50));

    expect(tipRect(tester).center.dx, 200.0);
  });

  testWidgets('an unclipped child is untouched', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: const JustTooltip(
              message: 'T',
              direction: TooltipDirection.bottom,
              child: SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      ),
    );
    await hoverAt(tester, const Offset(50, 25));

    expect(tipRect(tester).center.dx, 50.0,
        reason: 'the child rect, unchanged');
  });

  testWidgets('a scaled child targets its painted rect, not its layout size',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Transform.scale(
              scale: 2.0,
              alignment: Alignment.topLeft,
              child: const JustTooltip(
                message: 'T',
                direction: TooltipDirection.bottom,
                child: SizedBox(key: Key('c'), width: 100, height: 50),
              ),
            ),
          ),
        ),
      ),
    );
    await hoverAt(tester, const Offset(100, 50));

    final painted = tester.getRect(find.byKey(const Key('c')));
    expect(painted, const Rect.fromLTRB(0, 0, 200, 100));
    expect(tipRect(tester).center.dx, painted.center.dx,
        reason: 'the target is the painted rect, so 100 not 50');
    expect(tipRect(tester).top, greaterThanOrEqualTo(painted.bottom),
        reason: 'a bottom tooltip clears the child instead of overlapping it');
  });

  testWidgets(
      'a child clipped away entirely pins the tooltip to the edge it lies beyond',
      (tester) async {
    final scroll = ScrollController();
    final tooltip = JustTooltipController();
    addTearDown(scroll.dispose);
    var hides = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            // Inset from the screen edge, so screenMargin cannot clamp the
            // tooltip and blur what the anchor actually resolved to.
            child: Padding(
              padding: const EdgeInsets.only(left: 100),
              child: SizedBox(
                width: 400,
                height: 100,
                child: SingleChildScrollView(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    JustTooltip(
                      message: 'T',
                      controller: tooltip,
                      onHide: () => hides++,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                    const SizedBox(width: 900, height: 100),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Scroll the child fully out to the left, then show programmatically --
    // a hovering pointer could never reach this state.
    scroll.jumpTo(300);
    await tester.pumpAndSettle();
    tooltip.show();
    await tester.pumpAndSettle();

    // The clip is 100..500; the child now sits at -200..-100, wholly outside
    // it. Its centre clamps to the clip's left edge, 100.
    expect(find.byType(JustTooltipOverlay), findsOneWidget,
        reason: 'showing is not refused');
    expect(tipRect(tester).center.dx, 100.0);
    expect(hides, 0,
        reason: 'shown outright, not shown then hidden by target tracking');
  });
}
