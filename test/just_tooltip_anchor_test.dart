import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A child's rect is both the hover region and, by default, the anchor. For a
/// child much wider than the pointer's neighbourhood the two roles diverge, and
/// `TooltipAnchor.pointer` separates them.
void main() {
  /// A 700x60 target: wide enough that its centre is nowhere near the pointer.
  Widget wideTargetApp({
    TooltipAnchor? anchor,
    Duration? waitDuration,
    bool enableTap = false,
    bool enableHover = true,
    TooltipAlignment alignment = TooltipAlignment.center,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            anchor: anchor ?? TooltipAnchor.child,
            alignment: alignment,
            waitDuration: waitDuration,
            enableTap: enableTap,
            enableHover: enableHover,
            theme: const JustTooltipTheme(padding: EdgeInsets.zero),
            tooltipBuilder: (context) =>
                const SizedBox(key: Key('tip'), width: 100, height: 40),
            child: const SizedBox(key: Key('target'), width: 700, height: 60),
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

  /// A point well inside the target but far from its centre.
  Offset nearLeftEdge(WidgetTester tester) {
    final rect = tester.getRect(find.byKey(const Key('target')));
    return Offset(rect.left + 80, rect.center.dy);
  }

  testWidgets('TooltipAnchor.pointer anchors the tooltip at the pointer', (
    tester,
  ) async {
    await tester.pumpWidget(wideTargetApp(anchor: TooltipAnchor.pointer));
    final gesture = await mouse(tester);

    final pointer = nearLeftEdge(tester);
    await gesture.moveTo(pointer);
    await tester.pumpAndSettle();

    final tip = tester.getRect(find.byKey(const Key('tip')));
    final target = tester.getRect(find.byKey(const Key('target')));

    expect(
      tip.center.dx,
      moreOrLessEquals(pointer.dx, epsilon: 0.5),
      reason: 'the tooltip is centred on the pointer',
    );
    expect(
      tip.center.dx,
      isNot(moreOrLessEquals(target.center.dx, epsilon: 1)),
      reason: 'and emphatically not on the wide child',
    );
  });

  testWidgets('the anchor is where the pointer is when the tooltip shows, not '
      'where it entered', (tester) async {
    await tester.pumpWidget(
      wideTargetApp(
        anchor: TooltipAnchor.pointer,
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
    final gesture = await mouse(tester);

    final entry = nearLeftEdge(tester);
    await gesture.moveTo(entry);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('tip')), findsNothing, reason: 'still waiting');

    // The cursor wanders across the wide child before the delay elapses.
    final settled = entry + const Offset(220, 0);
    await gesture.moveTo(settled);
    await tester.pump(const Duration(milliseconds: 250)); // past 300 total
    await tester.pumpAndSettle();

    final tip = tester.getRect(find.byKey(const Key('tip')));
    expect(
      tip.center.dx,
      moreOrLessEquals(settled.dx, epsilon: 0.5),
      reason: 'the tooltip appears where the cursor came to rest',
    );
  });

  testWidgets('the anchor is frozen once shown, even across a rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(wideTargetApp(anchor: TooltipAnchor.pointer));
    final gesture = await mouse(tester);

    final shownAt = nearLeftEdge(tester);
    await gesture.moveTo(shownAt);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('tip'))).center.dx,
      moreOrLessEquals(shownAt.dx, epsilon: 0.5),
    );

    // Keep hovering the same (wide) child, further along. A tooltip that
    // chased the pointer could never be entered, which `interactive` needs.
    await gesture.moveTo(shownAt + const Offset(220, 0));
    await tester.pumpAndSettle();

    // Anything can rebuild the app while a tooltip is up.
    await tester.pumpWidget(wideTargetApp(anchor: TooltipAnchor.pointer));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('tip'))).center.dx,
      moreOrLessEquals(shownAt.dx, epsilon: 0.5),
      reason: 'the anchor was captured at show time and does not follow',
    );
  });

  testWidgets('a tap-triggered tooltip anchors at the tap', (tester) async {
    await tester.pumpWidget(
      wideTargetApp(
        anchor: TooltipAnchor.pointer,
        enableTap: true,
        enableHover: false,
      ),
    );

    // A touch produces no MouseRegion events at all, so the tap itself is the
    // only source of a position.
    final tap = nearLeftEdge(tester);
    await tester.tapAt(tap);
    await tester.pumpAndSettle();

    final tip = tester.getRect(find.byKey(const Key('tip')));
    expect(
      tip.center.dx,
      moreOrLessEquals(tap.dx, epsilon: 0.5),
      reason: 'the tooltip appears at the tap point',
    );
  });

  testWidgets('a programmatic show after the pointer left falls back to the '
      'child rect', (tester) async {
    final controller = JustTooltipController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              anchor: TooltipAnchor.pointer,
              controller: controller,
              theme: const JustTooltipTheme(padding: EdgeInsets.zero),
              tooltipBuilder: (context) =>
                  const SizedBox(key: Key('tip'), width: 100, height: 40),
              child: const SizedBox(key: Key('target'), width: 700, height: 60),
            ),
          ),
        ),
      ),
    );
    final gesture = await mouse(tester);

    // Hover, then leave. The pointer's last position must not outlive it.
    await gesture.moveTo(nearLeftEdge(tester));
    await tester.pumpAndSettle();
    await gesture.moveTo(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tip')), findsNothing);

    controller.show();
    await tester.pumpAndSettle();

    final tip = tester.getRect(find.byKey(const Key('tip')));
    final target = tester.getRect(find.byKey(const Key('target')));
    expect(
      tip.center.dx,
      moreOrLessEquals(target.center.dx, epsilon: 0.5),
      reason: 'no pointer, so the child rect is the anchor',
    );
  });

  testWidgets('a pointer-anchored tooltip can still be entered', (
    tester,
  ) async {
    await tester.pumpWidget(wideTargetApp(anchor: TooltipAnchor.pointer));
    final gesture = await mouse(tester);

    await gesture.moveTo(nearLeftEdge(tester));
    await tester.pumpAndSettle();
    final tip = tester.getRect(find.byKey(const Key('tip')));

    // The whole point of freezing the anchor: the tooltip stays put long
    // enough for the cursor to reach it.
    await gesture.moveTo(tip.center);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('tip')),
      findsOneWidget,
      reason: 'the cursor is on the tooltip, past the 100ms hover bridge',
    );
    expect(
      tester.getRect(find.byKey(const Key('tip'))),
      tip,
      reason: 'and it has not moved under the cursor',
    );
  });

  group('the last pointer position goes with the region that tracked it', () {
    /// A pointer-anchored tooltip whose `enableHover`, `tap` and left inset
    /// change through [config], opened only by [controller] or a tap.
    Future<void> pumpLive(
      WidgetTester tester, {
      required ValueNotifier<({bool hover, TooltipTap tap, double inset})>
      config,
      JustTooltipController? controller,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ValueListenableBuilder(
                valueListenable: config,
                builder: (_, c, _) => Padding(
                  padding: EdgeInsets.only(left: c.inset, top: 100),
                  child: JustTooltip(
                    anchor: TooltipAnchor.pointer,
                    controller: controller,
                    enableHover: c.hover,
                    tap: c.tap,
                    // Long enough that hovering never opens it on its own.
                    waitDuration: const Duration(seconds: 10),
                    theme: const JustTooltipTheme(padding: EdgeInsets.zero),
                    tooltipBuilder: (context) =>
                        const SizedBox(key: Key('tip'), width: 100, height: 40),
                    child: const SizedBox(
                      key: Key('target'),
                      width: 700,
                      height: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    ValueNotifier<({bool hover, TooltipTap tap, double inset})> configOf({
      bool hover = true,
      TooltipTap tap = TooltipTap.none,
    }) {
      final config = ValueNotifier((hover: hover, tap: tap, inset: 0.0));
      addTearDown(config.dispose);
      return config;
    }

    double tipCenterX(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('tip'))).center.dx;

    double targetCenterX(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('target'))).center.dx;

    testWidgets('a programmatic show after the pointer left while enableHover '
        'was off falls back to the child rect', (tester) async {
      final controller = JustTooltipController();
      final config = configOf();
      await pumpLive(tester, config: config, controller: controller);
      final gesture = await mouse(tester);
      final pointer = nearLeftEdge(tester);
      await gesture.moveTo(pointer);
      await tester.pump();

      config.value = (hover: false, tap: TooltipTap.none, inset: 0);
      await tester.pump();
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(find.byKey(const Key('tip')), findsNothing);

      controller.show();
      await tester.pumpAndSettle();
      expect(
        tipCenterX(tester),
        moreOrLessEquals(targetCenterX(tester), epsilon: 0.5),
        reason: 'the pointer is gone, so the child rect is the anchor',
      );
      expect(
        tipCenterX(tester),
        isNot(moreOrLessEquals(pointer.dx, epsilon: 1)),
        reason: 'not where the cursor was when hover was turned off',
      );
    });

    testWidgets('a programmatic show after the tap setting changed as the '
        'child moved from under the pointer falls back to the child rect', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final config = configOf();
      await pumpLive(tester, config: config, controller: controller);
      final gesture = await mouse(tester);
      final pointer = nearLeftEdge(tester);
      await gesture.moveTo(pointer);
      await tester.pump();

      // The tap widget re-creates the MouseRegion, and the new one is laid out
      // away from the pointer, so neither region reports an edge.
      config.value = (hover: true, tap: TooltipTap.claim, inset: 300);
      await tester.pump();
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('target'))).contains(pointer),
        isFalse,
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(
        tipCenterX(tester),
        moreOrLessEquals(targetCenterX(tester), epsilon: 0.5),
        reason: 'the pointer is off the child, so the child rect is the anchor',
      );
      expect(
        tipCenterX(tester),
        isNot(moreOrLessEquals(pointer.dx, epsilon: 1)),
      );
    });

    testWidgets('a pointer resting on the child when enableHover comes back on '
        'anchors a programmatic show at the pointer', (tester) async {
      final controller = JustTooltipController();
      final config = configOf();
      await pumpLive(tester, config: config, controller: controller);
      final gesture = await mouse(tester);
      final pointer = nearLeftEdge(tester);
      await gesture.moveTo(pointer);
      await tester.pump();

      config.value = (hover: false, tap: TooltipTap.none, inset: 0);
      await tester.pump();
      config.value = (hover: true, tap: TooltipTap.none, inset: 0);
      await tester.pump();
      await tester.pump();

      controller.show();
      await tester.pumpAndSettle();
      expect(
        tipCenterX(tester),
        moreOrLessEquals(pointer.dx, epsilon: 0.5),
        reason: 'the new region reports the resting pointer',
      );
    });

    testWidgets('a rebuild while enableHover is off leaves a programmatic '
        'show where the last tap was', (tester) async {
      final controller = JustTooltipController();
      final config = configOf(hover: false, tap: TooltipTap.claim);
      await pumpLive(tester, config: config, controller: controller);
      final down = nearLeftEdge(tester);
      await tester.tapAt(down);
      await tester.pumpAndSettle();
      expect(tipCenterX(tester), moreOrLessEquals(down.dx, epsilon: 0.5));
      await tester.tapAt(down);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tip')), findsNothing);

      // The same configuration again: nothing about the pointer changed.
      config.value = (hover: false, tap: TooltipTap.claim, inset: 1);
      await tester.pump();
      config.value = (hover: false, tap: TooltipTap.claim, inset: 0);
      await tester.pump();

      controller.show();
      await tester.pumpAndSettle();
      expect(
        tipCenterX(tester),
        moreOrLessEquals(down.dx, epsilon: 0.5),
        reason: 'a rebuild is not the pointer going anywhere',
      );
    });

    testWidgets('a claim tap that never lands leaves no position behind', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final config = configOf(hover: false, tap: TooltipTap.claim);
      await pumpLive(tester, config: config, controller: controller);
      final press = await tester.startGesture(nearLeftEdge(tester));
      await tester.pump();
      await press.moveBy(const Offset(0, 200)); // past the tap slop
      await press.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tip')), findsNothing);

      controller.show();
      await tester.pumpAndSettle();
      expect(
        tipCenterX(tester),
        moreOrLessEquals(targetCenterX(tester), epsilon: 0.5),
        reason: 'a cancelled tap opened nothing, so it says nothing',
      );
    });

    for (final tap in [TooltipTap.claim, TooltipTap.observe]) {
      testWidgets('a ${tap.name} tap pressed as enableHover turns off anchors '
          'at the tap', (tester) async {
        final config = configOf(tap: tap);
        await pumpLive(tester, config: config);
        final down = nearLeftEdge(tester);
        final press = await tester.startGesture(
          down,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 20));

        config.value = (hover: false, tap: tap, inset: 0);
        await tester.pump();
        await press.up();
        await tester.pumpAndSettle();
        expect(
          tipCenterX(tester),
          moreOrLessEquals(down.dx, epsilon: 0.5),
          reason: 'the tap that opened it says where it was',
        );
      });
    }
  });

  group('alignment against a zero-size anchor', () {
    // The tooltip cannot be "aligned to the edges" of a point, so alignment
    // says which of the tooltip's own edges the pointer lands on.
    /// Hovers [alignment]'s tooltip and returns `(tip rect, pointer)`.
    Future<(Rect, Offset)> tipFor(
      WidgetTester tester,
      TooltipAlignment alignment,
    ) async {
      await tester.pumpWidget(
        wideTargetApp(anchor: TooltipAnchor.pointer, alignment: alignment),
      );
      final gesture = await mouse(tester);
      final pointer = nearLeftEdge(tester);
      await gesture.moveTo(pointer);
      await tester.pumpAndSettle();
      return (tester.getRect(find.byKey(const Key('tip'))), pointer);
    }

    testWidgets("start puts the pointer at the tooltip's leading edge", (
      tester,
    ) async {
      final (tip, pointer) = await tipFor(tester, TooltipAlignment.start);
      expect(tip.left, moreOrLessEquals(pointer.dx, epsilon: 0.5));
    });

    testWidgets("end puts the pointer at the tooltip's trailing edge", (
      tester,
    ) async {
      final (tip, pointer) = await tipFor(tester, TooltipAlignment.end);
      expect(tip.right, moreOrLessEquals(pointer.dx, epsilon: 0.5));
    });
  });
}
