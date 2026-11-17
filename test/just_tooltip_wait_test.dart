import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// `waitDuration` delays only the show of a hidden tooltip; a trigger that
/// returns while the tooltip is shown or fading out turns it back at once, a
/// controller show cancels a hover show still waiting, and a controller hide
/// cancels it and dismisses the tooltip.
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

  group('a controller hide while a show waits out waitDuration', () {
    testWidgets('cancels a hover show and dismisses the tooltip: a '
        're-derivation keeps it closed, and the pointer leaving and '
        'returning shows it', (tester) async {
      final a = JustTooltipController();
      final registry = TooltipRegistry();
      final enableFocus = ValueNotifier(false);
      addTearDown(enableFocus.dispose);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<bool>(
            valueListenable: enableFocus,
            builder: (_, focus, _) => JustTooltip(
              message: 'A',
              controller: a,
              registry: registry,
              enableFocus: focus,
              interactive: false,
              waitDuration: wait,
              animationDuration: fade,
              child: const SizedBox(key: Key('a'), width: 80, height: 30),
            ),
          ),
        ),
      );
      final g = await mouse(tester);
      final centre = tester.getCenter(find.byKey(const Key('a')));
      await g.moveTo(centre);
      await trace(tester, 100);
      a.hide();
      expect(await trace(tester, 400, 'A'), isNot(contains('1')));

      enableFocus.value = true;
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'still dismissed');

      await g.moveTo(outside);
      await tester.pumpAndSettle();
      await g.moveTo(centre);
      await trace(tester, 600);
      expect(find.text('A'), findsOneWidget, reason: 'left and returned');
    });

    testWidgets('cancels a focus show until focus leaves and returns by key', (
      tester,
    ) async {
      final a = JustTooltipController();
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JustTooltip(
                message: 'A',
                controller: a,
                registry: TooltipRegistry(),
                enableFocus: true,
                waitDuration: wait,
                animationDuration: fade,
                child: TextButton(
                  focusNode: node,
                  onPressed: () {},
                  child: const Text('a'),
                ),
              ),
              TextButton(
                focusNode: other,
                onPressed: () {},
                child: const Text('other'),
              ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(node.hasFocus, isTrue);
      await trace(tester, 100);
      a.hide();
      expect(await trace(tester, 400, 'A'), isNot(contains('1')));
      expect(node.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(other.hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await trace(tester, 600);
      expect(node.hasFocus, isTrue);
      expect(find.text('A'), findsOneWidget, reason: 'focus left and returned');
    });

    testWidgets('on an evicted tooltip a new trigger act is showing, cancels '
        'that show: the holder stays, and the pointer leaving and returning '
        'shows it', (tester) async {
      final a = JustTooltipController();
      final b = JustTooltipController();
      final registry = TooltipRegistry();
      final enableFocus = ValueNotifier(false);
      addTearDown(enableFocus.dispose);
      await tester.pumpWidget(
        app(
          pair(
            ValueListenableBuilder<bool>(
              valueListenable: enableFocus,
              builder: (_, focus, _) => JustTooltip(
                message: 'A',
                controller: a,
                registry: registry,
                enableFocus: focus,
                interactive: false,
                waitDuration: wait,
                animationDuration: fade,
                child: const SizedBox(key: Key('a'), width: 80, height: 30),
              ),
            ),
            programmatic(registry, b),
          ),
        ),
      );
      final g = await mouse(tester);
      final centre = tester.getCenter(find.byKey(const Key('a')));
      await g.moveTo(centre);
      await trace(tester, 600);
      expect(find.text('A'), findsOneWidget);
      b.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'B evicted A');

      await g.moveTo(outside);
      await tester.pumpAndSettle();
      await g.moveTo(centre); // a new trigger act: the wait begins
      await trace(tester, 100);
      a.hide();
      expect(await trace(tester, 400, 'A'), isNot(contains('1')));
      expect(find.text('B'), findsOneWidget, reason: 'B keeps the place');

      enableFocus.value = true;
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'still dismissed');

      b.hide();
      expect(await trace(tester, 600, 'A'), isNot(contains('1')));
      expect(find.text('B'), findsNothing);

      await g.moveTo(outside);
      await tester.pumpAndSettle();
      await g.moveTo(centre);
      await trace(tester, 600);
      expect(find.text('A'), findsOneWidget, reason: 'a new act shows it');
      expect(find.text('B'), findsNothing);
    });

    testWidgets('cancels the wait a revival begins: the tooltip stays closed', (
      tester,
    ) async {
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
      final centre = tester.getCenter(find.byKey(const Key('a')));
      await g.moveTo(centre);
      await trace(tester, 600);
      b.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'B evicted A');

      b.hide(); // the revival: A is hidden, so it waits out waitDuration
      await trace(tester, 100);
      expect(find.text('A'), findsNothing, reason: 'still waiting');
      a.hide();
      expect(await trace(tester, 600, 'A'), isNot(contains('1')));

      await g.moveTo(outside);
      await tester.pumpAndSettle();
      await g.moveTo(centre);
      await trace(tester, 600);
      expect(find.text('A'), findsOneWidget, reason: 'left and returned');
    });

    testWidgets('a show after it opens the tooltip without the pointer, so '
        'leaving keeps it, as after Escape and a show', (tester) async {
      final a = JustTooltipController();
      await tester.pumpWidget(app(hovered(controller: a)));
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 100);
      a.hide();
      await trace(tester, 20);
      a.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);

      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('on a shown tooltip, fades it as before: a show turning the '
        'fade back leaves it to the pointer, and leaving hides it', (
      tester,
    ) async {
      final a = JustTooltipController();
      await tester.pumpWidget(app(hovered(controller: a)));
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 600);
      expect(find.text('A'), findsOneWidget);

      a.hide();
      await trace(tester, 60);
      a.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);

      await g.moveTo(outside);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('with no trigger inside and nothing waiting, changes nothing', (
      tester,
    ) async {
      final a = JustTooltipController();
      await tester.pumpWidget(app(hovered(controller: a)));
      final g = await mouse(tester);
      a.hide();
      await tester.pumpAndSettle();

      await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await trace(tester, 600);
      expect(find.text('A'), findsOneWidget);
    });
  });

  testWidgets('a revival with no waitDuration shows the tooltip at once, '
      'with a fresh showDuration countdown', (tester) async {
    final b = JustTooltipController();
    final registry = TooltipRegistry();
    await tester.pumpWidget(
      app(
        pair(
          JustTooltip(
            message: 'A',
            registry: registry,
            interactive: false,
            showDuration: const Duration(milliseconds: 1000),
            animationDuration: const Duration(milliseconds: 100),
            child: const SizedBox(key: Key('a'), width: 80, height: 30),
          ),
          programmatic(registry, b),
        ),
      ),
    );
    final g = await mouse(tester);
    await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
    await trace(tester, 400); // shown at once; its auto-hide is due at 1000
    b.show();
    await trace(tester, 300);
    expect(find.text('A'), findsNothing, reason: 'B evicted A');

    b.hide(); // at 700: the revival shows A at once
    await trace(tester, 100);
    expect(find.text('A'), findsOneWidget, reason: 'shown at once');
    // Past the left-over auto-hide at 1000, inside the fresh one.
    expect(await trace(tester, 700, 'A'), isNot(contains('0')));
    await trace(tester, 400); // the fresh auto-hide is due at about 1720
    expect(find.text('A'), findsNothing, reason: 'the fresh countdown ran out');
  });

  testWidgets('a new trigger act during the wait a revival begins makes the '
      'wait its own: the auto-hide left over from an earlier show, firing '
      'then, marks no dismissal', (tester) async {
    final b = JustTooltipController();
    final registry = TooltipRegistry();
    final node = FocusNode();
    final log = <String>[];
    addTearDown(node.dispose);
    await tester.pumpWidget(
      app(
        pair(
          JustTooltip(
            message: 'A',
            registry: registry,
            enableFocus: true,
            interactive: false,
            waitDuration: wait,
            showDuration: const Duration(milliseconds: 1000),
            animationDuration: const Duration(milliseconds: 100),
            onShow: () => log.add('show'),
            onHide: () => log.add('hide'),
            child: SizedBox(
              key: const Key('a'),
              width: 80,
              height: 30,
              child: TextButton(
                focusNode: node,
                onPressed: () {},
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          programmatic(registry, b),
        ),
      ),
    );
    final g = await mouse(tester);
    await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
    await trace(tester, 400); // shown at 300 ms; its auto-hide is due at 1300
    b.show();
    await trace(tester, 700);
    expect(find.text('A'), findsNothing, reason: 'B evicted A');

    b.hide(); // at 1100: the revival, A waits out the wait
    await trace(tester, 60);
    expect(find.text('A'), findsNothing, reason: 'still waiting');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // a new act
    expect(node.hasFocus, isTrue);
    await trace(tester, 100);
    expect(find.text('A'), findsNothing, reason: 'still waiting');
    await trace(tester, 300); // the left-over auto-hide fired at 1300
    expect(find.text('A'), findsOneWidget, reason: 'the wait ran out');
    expect(log, ['show', 'hide', 'show']);
  });

  testWidgets('an auto-hide left over from an earlier show, firing while a '
      'revival waits out waitDuration, cancels the revival: the tooltip stays '
      'closed until the pointer leaves and returns', (tester) async {
    final b = JustTooltipController();
    final registry = TooltipRegistry();
    final log = <String>[];
    await tester.pumpWidget(
      app(
        pair(
          JustTooltip(
            message: 'A',
            registry: registry,
            interactive: false,
            waitDuration: wait,
            showDuration: const Duration(milliseconds: 1000),
            animationDuration: const Duration(milliseconds: 100),
            onShow: () => log.add('show'),
            onHide: () => log.add('hide'),
            child: const SizedBox(key: Key('a'), width: 80, height: 30),
          ),
          programmatic(registry, b),
        ),
      ),
    );
    final g = await mouse(tester);
    final centre = tester.getCenter(find.byKey(const Key('a')));
    await g.moveTo(centre);
    await trace(tester, 400); // shown at 300 ms; its auto-hide is due at 1300
    expect(find.text('A'), findsOneWidget);
    b.show();
    await trace(tester, 700);
    expect(find.text('A'), findsNothing, reason: 'B evicted A');
    expect(log, ['show', 'hide']);

    b.hide(); // at 1100: the revival, A is hidden, so it waits out the wait
    await trace(tester, 100);
    expect(find.text('B'), findsNothing);
    expect(find.text('A'), findsNothing, reason: 'still waiting');
    // The left-over auto-hide fires at 1300, inside the wait.
    expect(await trace(tester, 600, 'A'), isNot(contains('1')));
    expect(log, ['show', 'hide'], reason: 'no show after the revival');

    await g.moveTo(outside);
    await tester.pumpAndSettle();
    await g.moveTo(centre);
    await trace(tester, 400);
    expect(find.text('A'), findsOneWidget, reason: 'left and returned');
    expect(log, ['show', 'hide', 'show']);
  });

  testWidgets('an auto-hide left over from an earlier show, firing while a '
      'new trigger act waits on an evicted tooltip, marks no dismissal: a '
      're-derivation keeps it shown once showDuration is gone', (tester) async {
    const longWait = Duration(milliseconds: 800);
    final b = JustTooltipController();
    final registry = TooltipRegistry();
    final enableFocus = ValueNotifier(false);
    final autoHide = ValueNotifier(true);
    addTearDown(enableFocus.dispose);
    addTearDown(autoHide.dispose);
    await tester.pumpWidget(
      app(
        pair(
          ListenableBuilder(
            listenable: Listenable.merge([enableFocus, autoHide]),
            builder: (_, _) => JustTooltip(
              message: 'A',
              registry: registry,
              enableFocus: enableFocus.value,
              interactive: false,
              waitDuration: longWait,
              showDuration: autoHide.value
                  ? const Duration(milliseconds: 1000)
                  : null,
              animationDuration: fade,
              child: const SizedBox(key: Key('a'), width: 80, height: 30),
            ),
          ),
          programmatic(registry, b),
        ),
      ),
    );
    final g = await mouse(tester);
    final centre = tester.getCenter(find.byKey(const Key('a')));
    await g.moveTo(centre);
    await trace(tester, 900); // shown at 800 ms; its auto-hide is due at 1800
    expect(find.text('A'), findsOneWidget);
    b.show();
    await trace(tester, 300);
    expect(find.text('A'), findsNothing, reason: 'B evicted A');
    autoHide.value = false; // the armed auto-hide stays

    await g.moveTo(outside);
    await trace(tester, 20);
    await g.moveTo(centre); // a new trigger act at 1220: shown at 2020
    await trace(tester, 900); // the left-over auto-hide fired at 1800
    expect(find.text('A'), findsOneWidget, reason: 'the wait ran out');
    expect(find.text('B'), findsNothing, reason: 'A took the place back');

    enableFocus.value = true;
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('an auto-hide left over from an earlier show, firing while a '
      'new trigger act waits after a revival the registry turned back, marks '
      'no dismissal: the tooltip shows when the wait ends', (tester) async {
    final b = JustTooltipController();
    final d = JustTooltipController();
    final registry = TooltipRegistry();
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JustTooltip(
              message: 'A',
              registry: registry,
              enableFocus: true,
              interactive: false,
              waitDuration: wait,
              showDuration: const Duration(milliseconds: 1000),
              animationDuration: const Duration(milliseconds: 100),
              child: SizedBox(
                key: const Key('a'),
                width: 80,
                height: 30,
                child: TextButton(
                  focusNode: node,
                  onPressed: () {},
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 100),
            // D's show ending revives A, and B takes the place before that
            // revival runs, so A waits again.
            JustTooltip(
              message: 'D',
              registry: registry,
              controller: d,
              enableHover: false,
              animationDuration: const Duration(milliseconds: 20),
              onHide: b.show,
              child: const SizedBox(width: 80, height: 30),
            ),
            programmatic(registry, b),
          ],
        ),
      ),
    );
    final g = await mouse(tester);
    await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
    await trace(tester, 400); // shown at 300 ms; its auto-hide is due at 1300
    expect(find.text('A'), findsOneWidget);
    d.show();
    await trace(tester, 200);
    expect(find.text('A'), findsNothing, reason: 'D evicted A');
    d.hide();
    await trace(tester, 500);
    expect(find.text('D'), findsNothing);
    expect(find.text('B'), findsOneWidget, reason: 'B took the place');
    expect(find.text('A'), findsNothing, reason: 'A waits again');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // a new act at 1100
    expect(node.hasFocus, isTrue);
    await trace(tester, 100);
    expect(find.text('A'), findsNothing, reason: 'still waiting');
    await trace(tester, 300); // the left-over auto-hide fired at 1300
    expect(find.text('A'), findsOneWidget, reason: 'the wait ran out');
    expect(find.text('B'), findsNothing, reason: 'A took the place back');
  });

  testWidgets('a controller hide after the show a revival waited for, once '
      'lost content has hidden the tooltip, is not a dismissal: the content '
      'coming back shows it', (tester) async {
    final a = JustTooltipController();
    final b = JustTooltipController();
    final registry = TooltipRegistry();
    final message = ValueNotifier('A');
    addTearDown(message.dispose);
    await tester.pumpWidget(
      app(
        pair(
          ValueListenableBuilder<String>(
            valueListenable: message,
            builder: (_, text, _) => JustTooltip(
              message: text,
              controller: a,
              registry: registry,
              interactive: false,
              waitDuration: wait,
              animationDuration: fade,
              child: const SizedBox(key: Key('a'), width: 80, height: 30),
            ),
          ),
          programmatic(registry, b),
        ),
      ),
    );
    final g = await mouse(tester);
    await g.moveTo(tester.getCenter(find.byKey(const Key('a'))));
    await trace(tester, 400);
    b.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'B evicted A');

    b.hide(); // the revival: A waits out waitDuration
    await trace(tester, 400);
    expect(find.text('A'), findsOneWidget, reason: 'the wait ran out');
    message.value = '';
    await tester.pumpAndSettle();
    expect(a.isShowing, isFalse, reason: 'the content went');
    a.hide();
    await tester.pumpAndSettle();

    message.value = 'A';
    await trace(tester, 400);
    expect(find.text('A'), findsOneWidget, reason: 'the content came back');
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
