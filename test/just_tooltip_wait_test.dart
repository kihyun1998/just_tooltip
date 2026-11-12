import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// `waitDuration` delays only the show of a hidden tooltip; a trigger that
/// returns while the tooltip is shown or fading out turns it back at once, and
/// a controller show cancels a hover show still waiting.
void main() {
  const wait = Duration(milliseconds: 300);
  const fade = Duration(milliseconds: 200);
  const outside = Offset(700, 500);

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  int count(String text) => find.text(text).evaluate().length;

  /// Pumps [ms] in 20 ms steps and returns how many [text] widgets were found
  /// after each step, one digit per step.
  Future<String> trace(WidgetTester tester, int ms, [String? text]) async {
    final out = StringBuffer();
    for (var i = 0; i < ms ~/ 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (text != null) out.write(count(text));
    }
    return out.toString();
  }

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: outside);
    addTearDown(gesture.removePointer);
    await tester.pump();
    return gesture;
  }

  Widget hovered({
    String message = 'A',
    String key = 'a',
    JustTooltipController? controller,
    TooltipRegistry? registry,
    TooltipTap tap = TooltipTap.none,
    List<String>? log,
  }) => JustTooltip(
    message: message,
    controller: controller,
    registry: registry ?? TooltipRegistry(),
    tap: tap,
    interactive: false,
    waitDuration: wait,
    animationDuration: fade,
    onShow: log == null ? null : () => log.add('show'),
    onHide: log == null ? null : () => log.add('hide'),
    child: SizedBox(key: Key(key), width: 80, height: 30),
  );

  /// A tooltip in the same registry that only its controller opens.
  Widget programmatic(TooltipRegistry registry, JustTooltipController c) =>
      JustTooltip(
        message: 'B',
        registry: registry,
        controller: c,
        enableHover: false,
        animationDuration: const Duration(milliseconds: 20),
        child: const SizedBox(width: 80, height: 30),
      );

  Widget pair(Widget a, Widget b) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [a, const SizedBox(height: 100), b],
  );

  group('a trigger returning while the tooltip fades out', () {
    testWidgets('a hover turns the fade back at once, and leaving hides it', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(app(hovered(log: log)));
      final g = await mouse(tester);
      final child = tester.getCenter(find.byKey(const Key('a')));
      await g.moveTo(child);
      await trace(tester, 700);

      await g.moveTo(outside);
      final leaving = await trace(tester, 60, 'A');
      await g.moveTo(child);
      final back = await trace(tester, 600, 'A');

      expect(leaving + back, isNot(contains('0')), reason: 'never off screen');
      expect(log, ['show'], reason: 'one show, never ended');
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(log, ['show', 'hide']);
    });

    testWidgets('focus turns the fade back at once, and blurring hides it', (
      tester,
    ) async {
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                focusNode: other,
                onPressed: () {},
                child: const Text('x'),
              ),
              JustTooltip(
                message: 'A',
                enableHover: false,
                enableFocus: true,
                interactive: false,
                registry: TooltipRegistry(),
                waitDuration: wait,
                animationDuration: fade,
                child: TextButton(
                  focusNode: node,
                  onPressed: () {},
                  child: const Text('btn'),
                ),
              ),
            ],
          ),
        ),
      );
      other.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await trace(tester, 700);
      expect(find.text('A'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await trace(tester, 60);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final back = await trace(tester, 600, 'A');

      expect(back, isNot(contains('0')));
      other.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('a hover after a tap closed it turns the fade back, and '
        'leaving hides it', (tester) async {
      await tester.pumpWidget(app(hovered(tap: TooltipTap.claim)));
      final g = await mouse(tester);
      final child = tester.getCenter(find.byKey(const Key('a')));
      await g.moveTo(child);
      await trace(tester, 700);
      await g.down(child);
      await g.up();
      await trace(tester, 20);

      await g.moveTo(outside);
      await trace(tester, 60);
      await g.moveTo(child);
      final back = await trace(tester, 600, 'A');

      expect(back, isNot(contains('0')));
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('a nested tooltip releasing the outer one turns its fade '
        'back, and leaving hides it', (tester) async {
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'O',
            registry: TooltipRegistry(),
            interactive: false,
            waitDuration: wait,
            animationDuration: fade,
            child: SizedBox(
              key: const Key('o'),
              width: 200,
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 120),
                  JustTooltip(
                    message: 'I',
                    registry: TooltipRegistry(),
                    interactive: false,
                    child: const SizedBox(key: Key('i'), width: 60, height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final outer =
          tester.getTopLeft(find.byKey(const Key('o'))) + const Offset(20, 20);
      final g = await mouse(tester);
      await g.moveTo(outer);
      await trace(tester, 700);
      expect(find.text('O'), findsOneWidget);

      await g.moveTo(tester.getCenter(find.byKey(const Key('i'))));
      await trace(tester, 60);
      await g.moveTo(outer);
      final back = await trace(tester, 600, 'O');

      expect(back, isNot(contains('0')));
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('O'), findsNothing);
    });

    testWidgets('a revival from the registry turns the fade back, and '
        'leaving hides it', (tester) async {
      final b = JustTooltipController();
      final registry = TooltipRegistry();
      await tester.pumpWidget(
        app(pair(hovered(registry: registry), programmatic(registry, b))),
      );
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 700);

      b.show();
      final evicted = await trace(tester, 60, 'A');
      b.hide();
      final revived = await trace(tester, 600, 'A');

      expect(evicted + revived, isNot(contains('0')));
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
    });

    testWidgets('a revival when the evicting tooltip leaves the tree turns '
        'the fade back, and leaving hides it', (tester) async {
      final b = JustTooltipController();
      final registry = TooltipRegistry();
      final withB = ValueNotifier(true);
      addTearDown(withB.dispose);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<bool>(
            valueListenable: withB,
            builder: (_, on, _) => pair(
              hovered(registry: registry),
              on ? programmatic(registry, b) : const SizedBox(),
            ),
          ),
        ),
      );
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 700);

      b.show();
      final evicted = await trace(tester, 60, 'A');
      withB.value = false;
      final revived = await trace(tester, 600, 'A');

      expect(evicted + revived, isNot(contains('0')));
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });
  });

  testWidgets('a hover entering a controller-shown tooltip restarts '
      'showDuration at once', (tester) async {
    final a = JustTooltipController();
    await tester.pumpWidget(
      app(
        JustTooltip(
          message: 'A',
          controller: a,
          registry: TooltipRegistry(),
          waitDuration: wait,
          showDuration: const Duration(milliseconds: 500),
          animationDuration: fade,
          child: const SizedBox(key: Key('a'), width: 80, height: 30),
        ),
      ),
    );
    final g = await mouse(tester);
    a.show();
    await trace(tester, 300);
    await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));

    // Hidden 500 ms after the entry plus the fade. Not restarted, the
    // controller's countdown would hide it 200 ms after the entry; restarted
    // at the end of the wait, it would still show 800 ms after the entry.
    final shown = await trace(tester, 760, 'A');
    expect(shown.substring(0, 24), isNot(contains('0')));
    expect(find.text('A'), findsNothing);
  });

  group('a controller show answers a hover show waiting for waitDuration', () {
    testWidgets('a hide whose fade outlasts the wait is not turned back', (
      tester,
    ) async {
      final a = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(app(hovered(controller: a, log: log)));
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 20);
      a.show();
      await trace(tester, 160);
      a.hide();

      // The fade runs from 180 ms to 380 ms, past the wait's end at 300 ms.
      await trace(tester, 400);
      expect(find.text('A'), findsNothing);
      expect(log, ['show', 'hide']);
    });

    testWidgets('showDuration counts from the controller show', (tester) async {
      final a = JustTooltipController();
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'A',
            controller: a,
            registry: TooltipRegistry(),
            waitDuration: wait,
            showDuration: const Duration(milliseconds: 500),
            animationDuration: fade,
            child: const SizedBox(key: Key('a'), width: 80, height: 30),
          ),
        ),
      );
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 20);
      a.show();

      // Hidden by 500 ms plus the fade; counted from the end of the wait it
      // would still show until 780 ms plus the fade.
      final shown = await trace(tester, 760, 'A');
      expect(shown.substring(0, 24), isNot(contains('0')));
      expect(find.text('A'), findsNothing);
    });

    testWidgets('a controller show and hide during the wait leave it closed', (
      tester,
    ) async {
      final a = JustTooltipController();
      await tester.pumpWidget(app(hovered(controller: a)));
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 20);
      a.show();
      await trace(tester, 20);
      expect(find.text('A'), findsOneWidget);
      a.hide();
      await trace(tester, 600);

      expect(find.text('A'), findsNothing, reason: 'closed until it returns');
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('eviction of a controller-shown tooltip during the wait '
        'leaves it evicted', (tester) async {
      final a = JustTooltipController();
      final b = JustTooltipController();
      final registry = TooltipRegistry();
      await tester.pumpWidget(
        app(
          pair(
            hovered(controller: a, registry: registry),
            programmatic(registry, b),
          ),
        ),
      );
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 20);
      a.show();
      await trace(tester, 20);
      b.show();
      await trace(tester, 600);

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('a trigger back while shown leaves no show waiting', () {
    testWidgets('eviction after a hover turned the fade back leaves it '
        'evicted', (tester) async {
      final b = JustTooltipController();
      final registry = TooltipRegistry();
      await tester.pumpWidget(
        app(pair(hovered(registry: registry), programmatic(registry, b))),
      );
      final child = tester.getCenter(find.byKey(const Key('a')));
      final g = await mouse(tester);
      await g.moveTo(child);
      await trace(tester, 700);
      await g.moveTo(outside);
      await trace(tester, 40);
      await g.moveTo(child);
      await trace(tester, 20);
      b.show();
      await trace(tester, 600);

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('eviction after a hover returned within the hover bridge '
        'leaves it evicted', (tester) async {
      final b = JustTooltipController();
      final registry = TooltipRegistry();
      await tester.pumpWidget(
        app(
          pair(
            JustTooltip(
              message: 'A',
              registry: registry,
              waitDuration: wait,
              animationDuration: fade,
              child: const SizedBox(key: Key('a'), width: 80, height: 30),
            ),
            programmatic(registry, b),
          ),
        ),
      );
      final child = tester.getCenter(find.byKey(const Key('a')));
      final g = await mouse(tester);
      await g.moveTo(child);
      await trace(tester, 700);
      await g.moveTo(outside);
      await trace(tester, 40);
      await g.moveTo(child);
      await trace(tester, 20);
      expect(find.text('A'), findsOneWidget, reason: 'the bridge never fired');
      b.show();
      await trace(tester, 600);

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('Escape after a hover turned the fade back keeps it closed', (
      tester,
    ) async {
      await tester.pumpWidget(app(hovered()));
      final child = tester.getCenter(find.byKey(const Key('a')));
      final g = await mouse(tester);
      await g.moveTo(child);
      await trace(tester, 700);
      await g.moveTo(outside);
      await trace(tester, 60);
      await g.moveTo(child);
      await trace(tester, 200);
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'turned back, not waiting',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await trace(tester, 600);

      expect(find.text('A'), findsNothing);
    });
  });
}
