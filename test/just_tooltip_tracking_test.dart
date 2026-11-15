import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// A [ClipRect] that counts how often its clip is asked for.
class CountingClip extends SingleChildRenderObjectWidget {
  const CountingClip({super.key, required this.counter, super.child});

  final ValueNotifier<int> counter;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCountingClip(counter);
}

class _RenderCountingClip extends RenderClipRect {
  _RenderCountingClip(this.counter);

  final ValueNotifier<int> counter;

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    counter.value++;
    return super.describeApproximatePaintClip(child);
  }
}

Rect tipRect(WidgetTester tester) =>
    tester.getRect(find.byType(JustTooltipOverlay));

void main() {
  testWidgets('the tooltip follows its child when the child scrolls', (
    tester,
  ) async {
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
                        key: Key('c'),
                        width: 100,
                        height: 100,
                      ),
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

  testWidgets('the tooltip follows a scrolling child in the same frame (#83)', (
    tester,
  ) async {
    final scroll = ScrollController();
    final controller = JustTooltipController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 200),
              Center(
                child: JustTooltip(
                  message: 'T',
                  controller: controller,
                  enableHover: false,
                  direction: TooltipDirection.bottom,
                  animation: TooltipAnimation.none,
                  child: const SizedBox(key: Key('c'), width: 80, height: 30),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();

    double gap() =>
        tipRect(tester).top - tester.getRect(find.byKey(const Key('c'))).bottom;
    final settled = gap();

    for (var frame = 0; frame < 3; frame++) {
      scroll.jumpTo(scroll.offset + 40);
      await tester.pump();
      expect(gap(), settled, reason: 'frame ${frame + 1} of the scroll');
    }
  });

  testWidgets('the tooltip follows its child when a resize moves it', (
    tester,
  ) async {
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

  testWidgets('the tooltip hides once its child is clipped away entirely', (
    tester,
  ) async {
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

    expect(
      find.byType(JustTooltipOverlay),
      findsNothing,
      reason: 'no visible target, no tooltip',
    );
    expect(hidden, isTrue, reason: 'it hides through the normal path');
  });

  testWidgets(
    'show() on an already-clipped child keeps tracking, and re-aims when it returns',
    (tester) async {
      final scroll = ScrollController();
      final controller = JustTooltipController();
      addTearDown(scroll.dispose);
      var hides = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
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
                          onHide: () => hides++,
                          child: const SizedBox(
                            key: Key('c'),
                            width: 100,
                            height: 100,
                          ),
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

      // The clip is 100..500. Push the child out to -200..-100 first, so it has
      // never had a visible target.
      scroll.jumpTo(300);
      await tester.pumpAndSettle();

      controller.show();
      await tester.pumpAndSettle();
      expect(
        tipRect(tester).center.dx,
        100.0,
        reason: 'the clip edge the child lies beyond',
      );
      expect(hides, 0, reason: 'showing was honoured, not swallowed');

      // Bring the child back: 100..200, centre 150.
      scroll.jumpTo(0);
      await tester.pumpAndSettle();

      expect(find.byType(JustTooltipOverlay), findsOneWidget);
      expect(
        tipRect(tester).center.dx,
        150.0,
        reason: 'tracking survived the clipped show and found the child',
      );

      // And now that it has pointed at something, losing it hides.
      scroll.jumpTo(300);
      await tester.pumpAndSettle();

      expect(find.byType(JustTooltipOverlay), findsNothing);
      expect(hides, 1);
    },
  );

  testWidgets('a partly clipped child keeps its tooltip, aimed at what shows', (
    tester,
  ) async {
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

    expect(
      find.byType(JustTooltipOverlay),
      findsOneWidget,
      reason: 'part of it still shows',
    );
    expect(
      tipRect(tester).center.dx,
      120.0,
      reason: 'the centre of the visible 100..140, not of the child',
    );
  });

  group('a tooltip its clipped-away child hid is not dismissed', () {
    const fade = Duration(milliseconds: 200);

    /// A 200 px tall scroll view whose first child, 48 px tall, carries the
    /// tooltip; scrolling by 300 clips it away entirely.
    Widget scroller({
      required ScrollController scroll,
      required Widget tooltip,
      Widget? below,
      ValueNotifier<int>? clipQueries,
      GlobalKey<NavigatorState>? navigator,
    }) => MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: SizedBox(
              width: 300,
              height: 200,
              child: CountingClip(
                counter: clipQueries ?? ValueNotifier(0),
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [tooltip, const SizedBox(height: 1000), ?below],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget focusTooltip(
      FocusNode node, {
      String message = 'T',
      JustTooltipController? controller,
      TooltipRegistry? registry,
      bool enableHover = true,
      List<String>? log,
    }) => JustTooltip(
      message: message,
      controller: controller,
      registry: registry ?? TooltipRegistry(),
      enableFocus: true,
      enableHover: enableHover,
      animationDuration: fade,
      onShow: log == null ? null : () => log.add('show'),
      onHide: log == null ? null : () => log.add('hide'),
      child: SizedBox(
        width: 120,
        height: 48,
        child: TextButton(
          focusNode: node,
          onPressed: () {},
          child: const Text('btn'),
        ),
      ),
    );

    Future<void> tab(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    testWidgets('a focus-shown tooltip scrolled out and back with focus inside '
        'shows again', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node, log: log),
        ),
      );
      await tab(tester);
      expect(find.text('T'), findsOneWidget);

      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'clipped away');
      expect(node.hasFocus, isTrue);

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget, reason: 'back, focus inside');
      expect(log, ['show', 'hide', 'show']);
    });

    testWidgets('a child scrolled out during the whole fade is watched once '
        'per frame, and not once focus has left', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final queries = ValueNotifier(0);
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      addTearDown(queries.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node),
          clipQueries: queries,
        ),
      );
      await tab(tester);
      scroll.animateTo(
        800,
        duration: const Duration(milliseconds: 600),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 8));
      expect(find.text('T'), findsNothing);

      queries.value = 0;
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
      expect(queries.value, 1, reason: 'one watch, one clip walk');

      node.unfocus();
      await tester.pumpAndSettle();
      queries.value = 0;
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
      expect(queries.value, 0, reason: 'no trigger inside, no watch');
    });

    testWidgets('scrolled back while still fading out, it turns the fade '
        'back', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node, log: log),
        ),
      );
      await tab(tester);

      scroll.jumpTo(300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      expect(log, ['show'], reason: 'one show, never ended');
    });

    testWidgets('a hover-shown tooltip whose child scrolls out from under the '
        'resting pointer and back shows again', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: JustTooltip(
            message: 'T',
            registry: TooltipRegistry(),
            animationDuration: fade,
            onShow: () => log.add('show'),
            onHide: () => log.add('hide'),
            child: const SizedBox(key: Key('c'), width: 120, height: 48),
          ),
        ),
      );
      await hoverAt(tester, tester.getCenter(find.byKey(const Key('c'))));
      expect(find.text('T'), findsOneWidget);

      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      expect(log, ['show', 'hide', 'show']);
    });

    testWidgets('a re-derivation while the child is clipped away does not '
        'show it at the clip edge', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final hover = ValueNotifier(true);
      final log = <String>[];
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      addTearDown(hover.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: ValueListenableBuilder<bool>(
            valueListenable: hover,
            builder: (_, on, _) =>
                focusTooltip(node, enableHover: on, log: log),
          ),
        ),
      );
      await tab(tester);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      hover.value = false;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'still clipped away');
      expect(log, ['show', 'hide'], reason: 'never drawn at the clip edge');

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    /// A tooltip in a 100 px [ClipRect] below a button `other`; [shift]
    /// moves the tooltip's child down, out of the clip.
    Widget clipped(
      FocusNode node,
      FocusNode other,
      ValueNotifier<double> shift, {
      JustTooltipController? controller,
      List<String>? log,
    }) => MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              focusNode: other,
              onPressed: () {},
              child: const Text('other'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: ClipRect(
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: ValueListenableBuilder<double>(
                    valueListenable: shift,
                    builder: (_, dy, child) => Transform.translate(
                      offset: Offset(0, dy),
                      child: child,
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: focusTooltip(
                        node,
                        controller: controller,
                        log: log,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    testWidgets('focus arriving by key on a child still clipped away waits '
        'for the child, under a clip no scroll can undo', (tester) async {
      final node = FocusNode();
      final other = FocusNode();
      final shift = ValueNotifier(0.0);
      final log = <String>[];
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      addTearDown(shift.dispose);
      await tester.pumpWidget(clipped(node, other, shift, log: log));
      other.requestFocus();
      await tester.pumpAndSettle();
      await tab(tester);
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsOneWidget);

      shift.value = 300; // the child moves out of the clip
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(other.hasFocus, isTrue);
      await tab(tester);
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsNothing, reason: 'still clipped away');
      expect(log, ['show', 'hide'], reason: 'never drawn at the clip edge');

      shift.value = 0;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('a tooltip its controller opened, clipped away with no '
        'trigger inside, waits for the child when focus arrives by key', (
      tester,
    ) async {
      final node = FocusNode();
      final other = FocusNode();
      final shift = ValueNotifier(0.0);
      final c = JustTooltipController();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      addTearDown(shift.dispose);
      await tester.pumpWidget(clipped(node, other, shift, controller: c));
      other.requestFocus();
      await tester.pumpAndSettle();
      c.show();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);

      shift.value = 300;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      await tab(tester);
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsNothing, reason: 'still clipped away');

      shift.value = 0;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('a controller show on the clipped-away child still shows it '
        'at the clip edge', (tester) async {
      final node = FocusNode();
      final other = FocusNode();
      final shift = ValueNotifier(300.0);
      final c = JustTooltipController();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      addTearDown(shift.dispose);
      await tester.pumpWidget(clipped(node, other, shift, controller: c));
      c.show();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('visible for one frame and clipped again, it does not stay '
        'at the clip edge', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(scroll: scroll, tooltip: focusTooltip(node)),
      );
      await tab(tester);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();

      scroll.jumpTo(0);
      await tester.pump();
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('clipped again while waitDuration runs, it waits for the '
        'child again', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: JustTooltip(
            message: 'T',
            registry: TooltipRegistry(),
            enableFocus: true,
            waitDuration: const Duration(milliseconds: 300),
            animationDuration: fade,
            child: SizedBox(
              width: 120,
              height: 48,
              child: TextButton(
                focusNode: node,
                onPressed: () {},
                child: const Text('btn'),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      scroll.jumpTo(300);
      await tester.pumpAndSettle();

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      scroll.jumpTo(300);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    group('clipped while a show waits out waitDuration', () {
      Widget waiting(
        FocusNode node,
        List<String> log, {
        JustTooltipController? controller,
      }) => JustTooltip(
        message: 'T',
        registry: TooltipRegistry(),
        controller: controller,
        enableFocus: true,
        waitDuration: const Duration(milliseconds: 300),
        animationDuration: fade,
        onShow: () => log.add('show'),
        onHide: () => log.add('hide'),
        child: SizedBox(
          width: 120,
          height: 48,
          child: TextButton(
            focusNode: node,
            onPressed: () {},
            child: const Text('btn'),
          ),
        ),
      );

      testWidgets('the show is called off: it is never drawn, and shows once '
          'the child is back', (tester) async {
        final scroll = ScrollController();
        final node = FocusNode();
        final log = <String>[];
        addTearDown(scroll.dispose);
        addTearDown(node.dispose);
        await tester.pumpWidget(
          scroller(scroll: scroll, tooltip: waiting(node, log)),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 100));
        scroll.jumpTo(300);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(log, isEmpty, reason: 'never drawn');

        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('T'), findsOneWidget);
        expect(log, ['show']);
      });

      testWidgets('a controller show then shows it at the clip edge', (
        tester,
      ) async {
        final scroll = ScrollController();
        final node = FocusNode();
        final c = JustTooltipController();
        final log = <String>[];
        addTearDown(scroll.dispose);
        addTearDown(node.dispose);
        await tester.pumpWidget(
          scroller(
            scroll: scroll,
            tooltip: waiting(node, log, controller: c),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 100));
        scroll.jumpTo(300);
        await tester.pump();
        c.show();
        await tester.pumpAndSettle();
        expect(find.text('T'), findsOneWidget);
        expect(log, ['show']);
      });

      testWidgets('Escape then is not a dismissal: it shows once the child is '
          'back', (tester) async {
        final scroll = ScrollController();
        final node = FocusNode();
        final log = <String>[];
        addTearDown(scroll.dispose);
        addTearDown(node.dispose);
        await tester.pumpWidget(
          scroller(scroll: scroll, tooltip: waiting(node, log)),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 100));
        scroll.jumpTo(300);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('T'), findsOneWidget);
      });
    });

    testWidgets('a focused child a lazy list keeps alive off screen does not '
        'bring the tooltip back', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final log = <String>[];
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: ListView(
                    controller: scroll,
                    children: [
                      JustTooltip(
                        message: 'T',
                        registry: TooltipRegistry(),
                        enableFocus: true,
                        animationDuration: fade,
                        onShow: () => log.add('show'),
                        onHide: () => log.add('hide'),
                        child: SizedBox(
                          width: 120,
                          height: 48,
                          child: TextField(focusNode: node),
                        ),
                      ),
                      for (var i = 0; i < 100; i++)
                        SizedBox(height: 48, child: Text('row $i')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(log, ['show']);
      scroll.jumpTo(100); // clipped away, inside the list's cache extent
      await tester.pumpAndSettle();
      scroll.jumpTo(2000); // kept alive, out of the list's paint
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(log, ['show', 'hide']);
      expect(find.text('T'), findsNothing);
    });

    testWidgets('an evicted tooltip whose child is clipped after the eviction '
        'fade waits for the child when the holder hides', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final d = JustTooltipController();
      final registry = TooltipRegistry();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node, registry: registry),
          below: JustTooltip(
            message: 'D',
            controller: d,
            registry: registry,
            enableHover: false,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      );
      await tab(tester);
      d.show();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'D evicted T');
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'still clipped away');

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('a tooltip clipped away while covered waits for the child '
        'after the route is popped', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node),
          navigator: navigator,
        ),
      );
      await tab(tester);
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          opaque: false,
          requestFocus: false,
          pageBuilder: (_, _, _) => const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'covered');
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsNothing, reason: 'still clipped away');

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('controller.hide() on an evicted tooltip waiting for its '
        'clipped-away child is not a dismissal: it shows once the child is '
        'back', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final a = JustTooltipController();
      final d = JustTooltipController();
      final registry = TooltipRegistry();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node, controller: a, registry: registry),
          below: JustTooltip(
            message: 'D',
            controller: d,
            registry: registry,
            enableHover: false,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      );
      await tab(tester);
      d.show();
      await tester.pumpAndSettle();
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      a.hide();
      await tester.pumpAndSettle();
      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'still clipped away');

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    for (final close in ['Escape', 'controller.hide()']) {
      testWidgets('$close while it waits for the clipped-away child is not a '
          'dismissal: it shows once the child is back', (tester) async {
        final scroll = ScrollController();
        final node = FocusNode();
        final c = JustTooltipController();
        addTearDown(scroll.dispose);
        addTearDown(node.dispose);
        await tester.pumpWidget(
          scroller(
            scroll: scroll,
            tooltip: focusTooltip(node, controller: c),
          ),
        );
        await tab(tester);
        scroll.jumpTo(300);
        await tester.pumpAndSettle();
        if (close == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          c.hide();
        }
        await tester.pumpAndSettle();

        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('T'), findsOneWidget);
      });
    }

    testWidgets('a zero-size child inside the scroll view still shows its '
        'tooltip on focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    JustTooltip(
                      message: 'T',
                      registry: TooltipRegistry(),
                      enableFocus: true,
                      animationDuration: fade,
                      child: Focus(
                        focusNode: node,
                        child: const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tab(tester);
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('a tooltip a tap closed before it was clipped stays closed '
        'when the child returns', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: JustTooltip(
            message: 'T',
            registry: TooltipRegistry(),
            enableFocus: true,
            tap: TooltipTap.observe,
            animationDuration: fade,
            child: SizedBox(
              width: 120,
              height: 48,
              child: TextButton(
                focusNode: node,
                onPressed: () {},
                child: const Text('btn'),
              ),
            ),
          ),
        ),
      );
      await tab(tester);
      expect(find.text('T'), findsOneWidget);
      await tester.tap(find.text('btn'));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'closed by the tap');

      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsNothing, reason: 'still dismissed');
    });

    testWidgets('a tooltip dismissed with Escape before it was clipped stays '
        'closed when the child returns', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(scroll: scroll, tooltip: focusTooltip(node)),
      );
      await tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'still dismissed');
    });

    testWidgets('a tooltip its controller closed is still dismissed when the '
        'child is clipped during that fade and returns', (tester) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final c = JustTooltipController();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node, controller: c),
        ),
      );
      await tab(tester);
      c.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'still dismissed');
    });

    testWidgets('a tooltip opened by its controller, clipped away and back, '
        'stays closed as a covered one does', (tester) async {
      final scroll = ScrollController();
      final c = JustTooltipController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: JustTooltip(
            message: 'T',
            controller: c,
            registry: TooltipRegistry(),
            animationDuration: fade,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      );
      c.show();
      await tester.pumpAndSettle();
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);
    });

    testWidgets('an evicted tooltip clipped during its eviction fade is not '
        'dismissed: it waits while clipped, and shows once the child is back', (
      tester,
    ) async {
      final scroll = ScrollController();
      final node = FocusNode();
      final d = JustTooltipController();
      final registry = TooltipRegistry();
      addTearDown(scroll.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        scroller(
          scroll: scroll,
          tooltip: focusTooltip(node, registry: registry),
          below: JustTooltip(
            message: 'D',
            controller: d,
            registry: registry,
            enableHover: false,
            animationDuration: const Duration(milliseconds: 20),
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      );
      await tab(tester);
      expect(find.text('T'), findsOneWidget);

      d.show(); // evicts T
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      scroll.jumpTo(300); // T's child clipped during the eviction's fade
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      d.hide(); // the revival, with T's child still clipped away
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'still clipped away');

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget, reason: 'back, focus inside');
    });
  });
}
