import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip fading out is still shown: a show reaches it by turning the fade
/// back, whichever path asks — the controller as well as a hover.
void main() {
  const fade = Duration(milliseconds: 200);

  Widget tooltip({
    required String key,
    required JustTooltipController controller,
    required List<String> log,
    String message = 'tip',
    Duration? showDuration,
    TooltipRegistry? registry,
    TooltipTap tap = TooltipTap.none,
  }) {
    return JustTooltip(
      controller: controller,
      message: message,
      showDuration: showDuration,
      registry: registry,
      tap: tap,
      enableHover: false,
      animationDuration: fade,
      onShow: () => log.add('show $key'),
      onHide: () => log.add('hide $key'),
      child: SizedBox(key: Key(key), width: 60, height: 30),
    );
  }

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// Starts a fade-out on a tooltip shown by [controller], and leaves it half
  /// way.
  Future<void> halfFaded(
    WidgetTester tester,
    JustTooltipController controller,
  ) async {
    controller.show();
    await tester.pumpAndSettle();
    controller.hide();
    await tester.pump();
    await tester.pump(fade ~/ 2);
    expect(find.text('tip'), findsOneWidget, reason: 'still fading out');
  }

  group('controller.show() on a tooltip fading out', () {
    testWidgets('turns the fade back, with no second onShow and no onHide', (
      tester,
    ) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(app(tooltip(key: 'a', controller: c, log: log)));
      await halfFaded(tester, c);

      c.show();
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsOneWidget);
      expect(c.isShowing, isTrue);
      expect(log, ['show a']);
    });

    testWidgets('after a tap closed it, a show deferred to a microtask opens '
        'it again', (tester) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(
        app(tooltip(key: 'a', controller: c, log: log, tap: TooltipTap.claim)),
      );
      await tester.tap(find.byKey(const Key('a')));
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsOneWidget);

      await tester.tap(find.byKey(const Key('a')));
      Future.microtask(c.show);
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsOneWidget);
      expect(log, ['show a']);
    });

    testWidgets('takes the registry back: the tooltip that evicted it hides', (
      tester,
    ) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final b = JustTooltipController();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tooltip(
                key: 'a',
                controller: a,
                log: log,
                message: 'A',
                registry: registry,
              ),
              const SizedBox(height: 100),
              tooltip(
                key: 'b',
                controller: b,
                log: log,
                message: 'B',
                registry: registry,
              ),
            ],
          ),
        ),
      );
      a.show();
      await tester.pumpAndSettle();
      b.show();
      await tester.pump();
      await tester.pump(fade ~/ 2);
      expect(find.text('A'), findsOneWidget, reason: 'A still fading out');

      a.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(log, ['show a', 'show b', 'hide b']);
    });

    testWidgets('makes it the tooltip Escape closes next', (tester) async {
      final log = <String>[];
      final a = JustTooltipController();
      final b = JustTooltipController();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tooltip(
                key: 'a',
                controller: a,
                log: log,
                message: 'A',
                registry: TooltipRegistry(),
              ),
              const SizedBox(height: 100),
              tooltip(
                key: 'b',
                controller: b,
                log: log,
                message: 'B',
                registry: TooltipRegistry(),
              ),
            ],
          ),
        ),
      );
      a.show();
      await tester.pumpAndSettle();
      b.show();
      await tester.pumpAndSettle();
      a.hide();
      await tester.pump();
      await tester.pump(fade ~/ 2);

      a.show();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(log, ['show a', 'show b', 'hide a']);
    });

    testWidgets('re-arms the auto-hide', (tester) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(
        app(
          tooltip(
            key: 'a',
            controller: c,
            log: log,
            showDuration: const Duration(seconds: 1),
          ),
        ),
      );
      await halfFaded(tester, c);

      c.show();
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsNothing);
      expect(log, ['show a', 'hide a']);
    });

    testWidgets('on a child scrolled out of sight keeps it, as a show after '
        'the fade does', (tester) async {
      final log = <String>[];
      final c = JustTooltipController();
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
                      tooltip(key: 'a', controller: c, log: log),
                      const SizedBox(width: 900, height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      c.show();
      await tester.pumpAndSettle();
      scroll.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(fade ~/ 2);
      expect(c.isShowing, isTrue, reason: 'still fading out');

      c.show();
      await tester.pumpAndSettle();
      expect(c.isShowing, isTrue);

      // The child moves on while still out of sight.
      scroll.jumpTo(320);
      await tester.pumpAndSettle();
      expect(c.isShowing, isTrue);
      expect(log, ['show a']);
    });

    testWidgets('does not turn back a fade caused by losing the content', (
      tester,
    ) async {
      final log = <String>[];
      final c = JustTooltipController();
      final message = ValueNotifier('tip');
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<String>(
            valueListenable: message,
            builder: (_, m, _) =>
                tooltip(key: 'a', controller: c, log: log, message: m),
          ),
        ),
      );
      c.show();
      await tester.pumpAndSettle();
      message.value = '';
      await tester.pump();
      await tester.pump(fade ~/ 2);
      expect(c.isShowing, isTrue, reason: 'still fading out');

      c.show();
      await tester.pumpAndSettle();
      expect(c.isShowing, isFalse);
      expect(log, ['show a', 'hide a']);
    });

    testWidgets('does not turn back a fade caused by a covering route', (
      tester,
    ) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(app(tooltip(key: 'a', controller: c, log: log)));
      c.show();
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        DialogRoute<void>(
          context: tester.element(find.byType(Scaffold)),
          builder: (_) => const AlertDialog(content: Text('dialog')),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(fade ~/ 2);
      expect(c.isShowing, isTrue, reason: 'still fading out');

      c.show();
      await tester.pumpAndSettle();
      expect(c.isShowing, isFalse);
      expect(log, ['show a', 'hide a']);
    });
  });

  testWidgets('a hover turning back an evicted fade takes the registry back', (
    tester,
  ) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final b = JustTooltipController();
    await tester.pumpWidget(
      app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JustTooltip(
              message: 'A',
              registry: registry,
              interactive: false,
              animationDuration: fade,
              onShow: () => log.add('show a'),
              onHide: () => log.add('hide a'),
              child: const SizedBox(key: Key('a'), width: 60, height: 30),
            ),
            const SizedBox(height: 100),
            tooltip(
              key: 'b',
              controller: b,
              log: log,
              message: 'B',
              registry: registry,
            ),
          ],
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byKey(const Key('a'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);

    b.show();
    await tester.pump();
    await tester.pump(fade ~/ 4);
    // Out and back in while A is still fading out.
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('a'))));
    await tester.pump();
    expect(find.text('A'), findsOneWidget, reason: 'A still fading out');

    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(log, ['show a', 'show b', 'hide b']);
  });

  testWidgets('a turned-back pointer-anchored tooltip keeps its anchor', (
    tester,
  ) async {
    final c = JustTooltipController();
    final message = ValueNotifier('A');
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<String>(
          valueListenable: message,
          builder: (_, m, _) => JustTooltip(
            controller: c,
            message: m,
            anchor: TooltipAnchor.pointer,
            interactive: false,
            animationDuration: fade,
            child: const SizedBox(key: Key('a'), width: 300, height: 40),
          ),
        ),
      ),
    );
    final child = tester.getRect(find.byKey(const Key('a')));
    final pointer = child.centerLeft + const Offset(20, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: pointer);
    await tester.pumpAndSettle();

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(fade ~/ 2);
    c.show();
    await tester.pumpAndSettle();

    // A new message lays the tooltip out again from its anchor.
    message.value = 'AB';
    await tester.pumpAndSettle();
    final dx = tester.getRect(find.text('AB')).center.dx;
    expect(
      (dx - pointer.dx).abs(),
      lessThan(20),
      reason: 'aimed at the pointer it was shown at, not the child centre',
    );
  });

  group('controller.toggle()', () {
    testWidgets('on a tooltip fading out opens it again', (tester) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(app(tooltip(key: 'a', controller: c, log: log)));
      await halfFaded(tester, c);

      c.toggle();
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsOneWidget);
      expect(log, ['show a']);
    });

    testWidgets('on a shown tooltip hides it', (tester) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(app(tooltip(key: 'a', controller: c, log: log)));
      c.show();
      await tester.pumpAndSettle();

      c.toggle();
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsNothing);
      expect(log, ['show a', 'hide a']);
    });

    testWidgets('on a tooltip fading in hides it', (tester) async {
      final log = <String>[];
      final c = JustTooltipController();
      await tester.pumpWidget(app(tooltip(key: 'a', controller: c, log: log)));
      c.show();
      await tester.pump();
      await tester.pump(fade ~/ 2);

      c.toggle();
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsNothing);
      expect(log, ['show a', 'hide a']);
    });
  });
}
