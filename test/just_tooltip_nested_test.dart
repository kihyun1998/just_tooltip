import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// Nesting suppression: when JustTooltips nest, the innermost tooltip under
/// the pointer is the only one that shows.
void main() {
  /// An outer 400x200 target wrapping an inner 60x30 target at its centre.
  /// A point inside the outer but outside the inner is reachable via
  /// [outerOnly], so "moved from inner to outer" is expressible.
  Widget nested({Duration? outerWait}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            message: 'OUTER',
            waitDuration: outerWait,
            child: Container(
              key: const Key('outer'),
              width: 400,
              height: 200,
              alignment: Alignment.center,
              child: JustTooltip(
                message: 'INNER',
                child: const SizedBox(
                  key: Key('inner'),
                  width: 60,
                  height: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    return gesture;
  }

  Offset centreOf(WidgetTester tester, String key) =>
      tester.getCenter(find.byKey(Key(key)));

  /// A point inside the outer target but outside the inner one.
  Offset outerOnly(WidgetTester tester) {
    final rect = tester.getRect(find.byKey(const Key('outer')));
    return rect.topLeft + const Offset(20, 20);
  }

  testWidgets(
      'an ancestor waitDuration does not hijack the tooltip while the pointer '
      'rests on a nested child', (tester) async {
    await tester.pumpWidget(
      nested(outerWait: const Duration(milliseconds: 500)),
    );
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing);

    // The outer's hover-intent timer would fire here. The pointer has not
    // moved: the innermost tooltip must still own the screen.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget,
        reason: 'the innermost tooltip stays');
    expect(find.text('OUTER'), findsNothing,
        reason: 'a suppressed ancestor must never schedule a show');
  });

  testWidgets(
      'moving from the nested child back into the ancestor shows the ancestor, '
      'with no exit and re-enter', (tester) async {
    await tester.pumpWidget(nested());
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);

    // The pointer never leaves the outer region, so its MouseRegion sends no
    // onEnter. Releasing the suppression is what must bring the outer back.
    await gesture.moveTo(outerOnly(tester));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsNothing);
    expect(find.text('OUTER'), findsOneWidget,
        reason: 'released ancestor still holds the pointer');
  });

  testWidgets('leaving the nested child and the ancestor at once shows neither',
      (tester) async {
    await tester.pumpWidget(nested());
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);

    // Flutter delivers the inner onExit before the outer's. The ancestor is
    // released while it still believes it holds the pointer, and must not
    // flash into view on its way out.
    await gesture.moveTo(const Offset(5, 5));
    await tester.pump();
    expect(find.text('OUTER'), findsNothing,
        reason:
            'a release must not resurrect an ancestor that is also exiting');

    await tester.pumpAndSettle();
    expect(find.text('OUTER'), findsNothing);
    expect(find.text('INNER'), findsNothing);
  });

  testWidgets('suppression holds across independent registries',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: 'OUTER',
              child: Container(
                key: const Key('outer'),
                width: 400,
                height: 200,
                alignment: Alignment.center,
                // Its own registry: the "one tooltip at a time" policy cannot
                // dismiss the ancestor here. Only suppression can.
                child: JustTooltip(
                  message: 'INNER',
                  registry: TooltipRegistry(),
                  child: const SizedBox(
                    key: Key('inner'),
                    width: 60,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing);
  });

  testWidgets(
      'the innermost wins through an intermediate tooltip that has no hover '
      'region', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: 'OUTER',
              // Deferring the outer's show past the registry's dismissal makes
              // a missed suppression visible: a merely-dismissed ancestor
              // comes back when its timer fires.
              waitDuration: const Duration(milliseconds: 500),
              child: Container(
                width: 400,
                height: 200,
                alignment: Alignment.center,
                // No MouseRegion of its own, so it cannot forward a
                // suppression on the innermost's behalf.
                child: JustTooltip(
                  message: 'MIDDLE',
                  enableHover: false,
                  child: Container(
                    width: 200,
                    height: 100,
                    alignment: Alignment.center,
                    child: JustTooltip(
                      message: 'INNER',
                      child: const SizedBox(
                        key: Key('inner'),
                        width: 40,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing,
        reason:
            'the innermost suppresses every ancestor, not just the nearest');
  });
}
