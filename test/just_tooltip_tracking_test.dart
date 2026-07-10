import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:just_tooltip/src/just_tooltip_overlay.dart';

/// Adds the pointer clear of every child before moving onto [at].
///
/// `addPointer(location: Offset.zero)` would land inside a child pinned to the
/// top-left, firing `onEnter` at the origin.
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

void main() {
  testWidgets('the tooltip follows its child when the child scrolls',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 100,
              child: SingleChildScrollView(
                controller: scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 50, height: 100),
                    JustTooltip(
                      message: 'T',
                      child: const SizedBox(
                          key: Key('c'), width: 100, height: 100),
                    ),
                    const SizedBox(width: 800, height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The child spans 50..150, so the tooltip is centred on 100.
    await hoverAt(tester, const Offset(100, 50));
    expect(tipRect(tester).center.dx, 100.0);

    // Slide the child to 20..120. The pointer stays inside it, so nothing
    // dismisses the tooltip -- it must re-aim instead.
    scroll.jumpTo(30);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('c'))).center.dx, 70.0);
    expect(tipRect(tester).center.dx, 70.0);
  });

  testWidgets('the tooltip follows its child when a resize moves it',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = JustTooltipController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: 'T',
              controller: controller,
              direction: TooltipDirection.bottom,
              child: const SizedBox(key: Key('c'), width: 100, height: 50),
            ),
          ),
        ),
      ),
    );

    // Shown programmatically, with no pointer: a resize slides the child out
    // from under a stationary cursor, and the hover exit would dismiss the
    // tooltip before tracking could be observed.
    controller.show();
    await tester.pumpAndSettle();
    expect(tipRect(tester).center.dx, 400.0);

    // Narrowing the window re-centres the child. Nothing scrolls, so a
    // ScrollNotification subscription would miss this entirely.
    tester.view.physicalSize = const Size(500, 600);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('c'))).center.dx, 250.0);
    expect(tipRect(tester).center.dx, 250.0);
  });

  testWidgets('the tooltip hides once its child is clipped away entirely',
      (tester) async {
    final scroll = ScrollController();
    final controller = JustTooltipController();
    addTearDown(scroll.dispose);
    var hidden = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 100,
              child: SingleChildScrollView(
                controller: scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    JustTooltip(
                      message: 'T',
                      controller: controller,
                      onHide: () => hidden = true,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                    const SizedBox(width: 900, height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.show();
    await tester.pumpAndSettle();
    expect(find.byType(JustTooltipOverlay), findsOneWidget);

    // Scroll the child (0..100) completely past the viewport's leading edge.
    scroll.jumpTo(150);
    await tester.pumpAndSettle();

    expect(find.byType(JustTooltipOverlay), findsNothing,
        reason: 'no visible target, no tooltip');
    expect(hidden, isTrue, reason: 'it hides through the normal path');
  });

  testWidgets('a partly clipped child keeps its tooltip, aimed at what shows',
      (tester) async {
    final scroll = ScrollController();
    final controller = JustTooltipController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            // Inset from the screen edge, so screenMargin cannot clamp the
            // tooltip and blur what the target actually resolved to.
            child: Padding(
              padding: const EdgeInsets.only(left: 100),
              child: SizedBox(
                width: 400,
                height: 100,
                child: SingleChildScrollView(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      JustTooltip(
                        message: 'T',
                        controller: controller,
                        child: const SizedBox(width: 100, height: 100),
                      ),
                      const SizedBox(width: 900, height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.show();
    await tester.pumpAndSettle();

    // The clip is 100..500 and the child starts at 100..200. Scrolling by 60
    // slides it to 40..140, of which 100..140 shows.
    scroll.jumpTo(60);
    await tester.pumpAndSettle();

    expect(find.byType(JustTooltipOverlay), findsOneWidget,
        reason: 'part of it still shows');
    expect(tipRect(tester).center.dx, 120.0,
        reason: 'the centre of the visible 100..140, not of the child');
  });
}
