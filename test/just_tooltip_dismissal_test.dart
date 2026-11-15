import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip closed by something other than its trigger leaving — a tap, the
/// auto-hide, a controller — stays closed until its trigger leaves and returns
/// (ADR-0010), whatever drops its show intent during the closing fade.
void main() {
  const fade = Duration(milliseconds: 200);
  const step = Duration(milliseconds: 20);

  Future<void> stepFor(WidgetTester tester, Duration duration) async {
    for (var t = Duration.zero; t < duration; t += step) {
      await tester.pump(step);
    }
  }

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// Tooltip A around a 400x200 target, with tooltip N in its own registry
  /// at the target's centre when [nested].
  Widget outer({
    required List<String> log,
    String message = 'A',
    bool nested = false,
    TooltipTap? tap,
    JustTooltipController? controller,
  }) => JustTooltip(
    message: message,
    registry: TooltipRegistry(),
    tap: tap,
    controller: controller,
    animationDuration: fade,
    onShow: () => log.add('A show'),
    onHide: () => log.add('A hide'),
    child: Container(
      key: const Key('outer'),
      width: 400,
      height: 200,
      alignment: Alignment.center,
      child: nested
          ? JustTooltip(
              message: 'N',
              registry: TooltipRegistry(),
              child: const SizedBox(key: Key('inner'), width: 60, height: 30),
            )
          : null,
    ),
  );

  /// A point inside A's target but outside N's.
  Offset outerOnly(WidgetTester tester) =>
      tester.getRect(find.byKey(const Key('outer'))).topLeft +
      const Offset(20, 20);

  Offset inner(WidgetTester tester) =>
      tester.getCenter(find.byKey(const Key('inner')));

  /// Rests a mouse on A's target and returns once A is shown.
  Future<TestGesture> hoverA(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(outerOnly(tester));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    return mouse;
  }

  /// Taps A's target with [mouse], closing A, and lets 60 ms of the fade run.
  Future<void> tapCloseA(WidgetTester tester, TestGesture mouse) async {
    await mouse.down(outerOnly(tester));
    await mouse.up();
    await tester.pump();
    await stepFor(tester, const Duration(milliseconds: 60));
    expect(find.text('A'), findsOneWidget, reason: 'A is fading out');
  }

  group('a tooltip a tap closed stays closed', () {
    testWidgets('when the pointer moves onto a nested tooltip during the fade '
        'and back after it', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        app(outer(log: log, nested: true, tap: TooltipTap.claim)),
      );
      final mouse = await hoverA(tester);
      await tapCloseA(tester, mouse);

      await mouse.moveTo(inner(tester));
      await tester.pumpAndSettle();
      expect(find.text('N'), findsOneWidget);
      expect(find.text('A'), findsNothing);

      await mouse.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('N'), findsNothing);
      expect(find.text('A'), findsNothing);
      expect(log, ['A show', 'A hide']);
    });

    testWidgets('when the pointer moves onto a nested tooltip and back, both '
        'during the fade', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        app(outer(log: log, nested: true, tap: TooltipTap.claim)),
      );
      final mouse = await hoverA(tester);
      await tapCloseA(tester, mouse);

      await mouse.moveTo(inner(tester));
      await stepFor(tester, const Duration(milliseconds: 40));
      expect(find.text('A'), findsOneWidget, reason: 'A is still fading out');
      await mouse.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(log, ['A show', 'A hide']);
    });

    testWidgets('when its content goes during the fade and returns after it', (
      tester,
    ) async {
      final log = <String>[];
      final message = ValueNotifier('A');
      addTearDown(message.dispose);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<String>(
            valueListenable: message,
            builder: (_, value, _) =>
                outer(log: log, message: value, tap: TooltipTap.claim),
          ),
        ),
      );
      final mouse = await hoverA(tester);
      await tapCloseA(tester, mouse);

      message.value = '';
      await tester.pumpAndSettle();
      expect(log, ['A show', 'A hide']);
      message.value = 'A';
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(log, ['A show', 'A hide']);
    });

    testWidgets('and shows again once the pointer leaves and returns', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(
        app(outer(log: log, nested: true, tap: TooltipTap.claim)),
      );
      final mouse = await hoverA(tester);
      await tapCloseA(tester, mouse);
      await mouse.moveTo(inner(tester));
      await tester.pumpAndSettle();
      await mouse.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);

      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await mouse.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'A hide', 'A show']);
    });
  });

  testWidgets('a tooltip its controller hid stays closed when a route covers '
      'it during the fade and is popped with focus still inside', (
    tester,
  ) async {
    final log = <String>[];
    final a = JustTooltipController();
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      app(
        JustTooltip(
          message: 'A',
          enableFocus: true,
          controller: a,
          registry: TooltipRegistry(),
          animationDuration: fade,
          onShow: () => log.add('A show'),
          onHide: () => log.add('A hide'),
          child: TextButton(
            focusNode: node,
            onPressed: () {},
            child: const Text('btn'),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);

    a.hide();
    await tester.pump();
    await stepFor(tester, const Duration(milliseconds: 60));
    expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        requestFocus: false,
        builder: (_) => const Scaffold(body: Text('page')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'A hide']);
  });

  testWidgets('a hide during a fade begun by a nested tooltip suppressing it '
      'is not a dismissal: the pointer moving back onto it shows it', (
    tester,
  ) async {
    final log = <String>[];
    final a = JustTooltipController();
    await tester.pumpWidget(app(outer(log: log, nested: true, controller: a)));
    final mouse = await hoverA(tester);
    await mouse.moveTo(inner(tester));
    await stepFor(tester, const Duration(milliseconds: 60));
    expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

    a.hide();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    await mouse.moveTo(outerOnly(tester));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(log, ['A show', 'A hide', 'A show']);
  });

  group('a dismissal is released only by its trigger moving away', () {
    const away = Offset(760, 560);

    /// Tooltip T on a 200x100 child at the centre, closed by a tap
    /// (`TooltipTap.claim`); [navigator] pushes routes over it.
    Widget page({
      required GlobalKey<NavigatorState> navigator,
      bool enableHover = true,
      bool enableFocus = false,
      bool hideWhenCovered = true,
      TooltipTap tap = TooltipTap.claim,
      FocusNode? node,
      ScrollController? scroll,
      List<String>? log,
    }) {
      Widget tooltip = JustTooltip(
        message: 'T',
        registry: TooltipRegistry(),
        tap: tap,
        enableHover: enableHover,
        enableFocus: enableFocus,
        hideWhenCovered: hideWhenCovered,
        animationDuration: fade,
        onShow: log == null ? null : () => log.add('show'),
        onHide: log == null ? null : () => log.add('hide'),
        child: SizedBox(
          key: const Key('child'),
          width: 200,
          height: 100,
          child: node == null
              ? null
              : TextButton(
                  focusNode: node,
                  onPressed: () {},
                  child: const Text('btn'),
                ),
        ),
      );
      if (scroll != null) {
        tooltip = SizedBox(
          width: 300,
          height: 300,
          child: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 100),
                tooltip,
                const SizedBox(height: 1000),
              ],
            ),
          ),
        );
      }
      return MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Center(
            child: node == null
                ? tooltip
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tooltip,
                      TextButton(onPressed: () {}, child: const Text('other')),
                    ],
                  ),
          ),
        ),
      );
    }

    Offset centre(WidgetTester tester) =>
        tester.getCenter(find.byKey(const Key('child')));

    /// Rests a mouse on the child until T shows, then taps T closed and lets
    /// the fade end.
    Future<TestGesture> showThenTapClose(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: away);
      await tester.pump();
      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      await mouse.down(centre(tester));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'closed by the tap');
      return mouse;
    }

    Future<void> pushDialog(GlobalKey<NavigatorState> navigator) async {
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      );
    }

    testWidgets('a dialog pushed and popped over the child with the pointer '
        'still leaves it closed', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(page(navigator: navigator));
      await showThenTapClose(tester);

      await pushDialog(navigator);
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
    });

    testWidgets('enableHover turned off and on with the pointer still leaves '
        'it closed', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final hover = ValueNotifier(true);
      addTearDown(hover.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: hover,
          builder: (_, on, _) => page(navigator: navigator, enableHover: on),
        ),
      );
      await showThenTapClose(tester);

      hover.value = false;
      await tester.pumpAndSettle();
      hover.value = true;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
    });

    testWidgets('a tap mode change with the pointer still leaves it closed', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final tap = ValueNotifier(TooltipTap.claim);
      addTearDown(tap.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<TooltipTap>(
          valueListenable: tap,
          builder: (_, mode, _) => page(navigator: navigator, tap: mode),
        ),
      );
      await showThenTapClose(tester);

      tap.value = TooltipTap.observe;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
    });

    testWidgets('the child scrolled out from under the still pointer and back '
        'leaves it closed', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(page(navigator: navigator, scroll: scroll));
      await showThenTapClose(tester);

      scroll.jumpTo(250);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
    });

    /// Rests a mouse on the child until T shows, then taps T closed and lets
    /// 60 ms of the fade run.
    Future<TestGesture> showThenTapCloseMidFade(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: away);
      await tester.pump();
      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      await mouse.down(centre(tester));
      await mouse.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('T'), findsOneWidget, reason: 'fading out');
      return mouse;
    }

    group('with the close still fading out', () {
      testWidgets('a dialog that does not hide it, pushed and popped, leaves '
          'it closed', (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          page(navigator: navigator, hideWhenCovered: false),
        );
        await showThenTapCloseMidFade(tester);
        await pushDialog(navigator);
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
      });

      testWidgets('enableHover turned off and on leaves it closed', (
        tester,
      ) async {
        final navigator = GlobalKey<NavigatorState>();
        final hover = ValueNotifier(true);
        addTearDown(hover.dispose);
        await tester.pumpWidget(
          ValueListenableBuilder<bool>(
            valueListenable: hover,
            builder: (_, on, _) => page(navigator: navigator, enableHover: on),
          ),
        );
        await showThenTapCloseMidFade(tester);
        hover.value = false;
        await tester.pumpAndSettle();
        hover.value = true;
        await tester.pumpAndSettle();
        expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
      });

      testWidgets('the child scrolled partly from under the pointer and back '
          'leaves it closed', (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(page(navigator: navigator, scroll: scroll));
        await showThenTapCloseMidFade(tester);
        scroll.jumpTo(70);
        await tester.pumpAndSettle();
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
      });
    });

    testWidgets('the pointer moving out releases it: the child scrolled under '
        'the resting pointer then shows it', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(page(navigator: navigator, scroll: scroll));
      final mouse = await showThenTapClose(tester);
      // Out of the child by its own movement, onto the space above it.
      await mouse.moveTo(centre(tester) - const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      scroll.jumpTo(120); // the child moves up under the resting pointer
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('enableFocus turned off and on during the close\'s fade, focus '
        'staying inside, leaves it closed', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final node = FocusNode();
      final second = FocusNode();
      final focusOn = ValueNotifier(true);
      final c = JustTooltipController();
      addTearDown(node.dispose);
      addTearDown(second.dispose);
      addTearDown(focusOn.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: focusOn,
          builder: (_, on, _) => MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: Center(
                child: JustTooltip(
                  message: 'T',
                  registry: TooltipRegistry(),
                  controller: c,
                  enableFocus: on,
                  enableHover: false,
                  animationDuration: fade,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        focusNode: node,
                        onPressed: () {},
                        child: const Text('a'),
                      ),
                      TextButton(
                        focusNode: second,
                        onPressed: () {},
                        child: const Text('b'),
                      ),
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
      expect(find.text('T'), findsOneWidget);
      c.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      focusOn.value = false;
      await tester.pump();
      focusOn.value = true;
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // a -> b, inside
      await tester.pumpAndSettle();
      expect(second.hasFocus, isTrue);
      expect(find.text('T'), findsNothing, reason: 'focus never left');
    });

    testWidgets('a later dismissal keeps the hold an earlier one left', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final hover = ValueNotifier(true);
      final c = JustTooltipController();
      addTearDown(hover.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: hover,
          builder: (_, on, _) => MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: Center(
                child: JustTooltip(
                  message: 'T',
                  registry: TooltipRegistry(),
                  controller: c,
                  tap: TooltipTap.claim,
                  enableHover: on,
                  animationDuration: fade,
                  child: const SizedBox(
                    key: Key('child'),
                    width: 200,
                    height: 100,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await showThenTapClose(tester);
      hover.value = false;
      await tester.pumpAndSettle();
      c.show();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      hover.value = true;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'the pointer never moved');
    });

    testWidgets('focus that left while enableFocus was off releases its hold '
        'once enableFocus is back on', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final node = FocusNode();
      final focusOn = ValueNotifier(true);
      addTearDown(node.dispose);
      addTearDown(focusOn.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: focusOn,
          builder: (_, on, _) => page(
            navigator: navigator,
            node: node,
            enableFocus: on,
            tap: TooltipTap.none,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      focusOn.value = false;
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      focusOn.value = true;
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsOneWidget, reason: 'focus left and returned');
    });

    testWidgets(
      'after the dialog, the pointer leaving and returning shows it',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(page(navigator: navigator));
        final mouse = await showThenTapClose(tester);
        await pushDialog(navigator);
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();

        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        await mouse.moveTo(centre(tester));
        await tester.pumpAndSettle();
        expect(find.text('T'), findsOneWidget);
      },
    );

    testWidgets('the pointer moved away under the dialog and back in after '
        'the pop shows it: entering proves it left', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(page(navigator: navigator));
      final mouse = await showThenTapClose(tester);
      await pushDialog(navigator);
      await tester.pumpAndSettle();
      await mouse.moveTo(away);
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('the pointer moved away and back under the dialog, the pop '
        'landing over the child, leaves it closed until the pointer leaves '
        'and returns once more', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(page(navigator: navigator));
      final mouse = await showThenTapClose(tester);
      await pushDialog(navigator);
      await tester.pumpAndSettle();
      await mouse.moveTo(away);
      await tester.pumpAndSettle();
      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'no edge saw it leave');

      await mouse.moveTo(away);
      await tester.pumpAndSettle();
      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('a tooltip that was not dismissed shows again after the '
        'dialog under the still pointer, as before', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(page(navigator: navigator));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: away);
      await tester.pump();
      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);

      await pushDialog(navigator);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'covered');
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('a hold of the pointer does not outlast enableHover turned '
        'off: focus arriving by key shows it, and hover turned back on under '
        'the still pointer keeps it shown', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final node = FocusNode();
      final hover = ValueNotifier(true);
      addTearDown(node.dispose);
      addTearDown(hover.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: hover,
          builder: (_, on, _) => page(
            navigator: navigator,
            node: node,
            enableFocus: true,
            enableHover: on,
            tap: TooltipTap.observe,
          ),
        ),
      );
      await showThenTapClose(tester);

      hover.value = false;
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsOneWidget, reason: 'focus is a new trigger');

      hover.value = true;
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('dismissed under the pointer, then focus arriving: the pointer '
        'leaving keeps it closed while focus stays', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        page(
          navigator: navigator,
          node: node,
          enableFocus: true,
          tap: TooltipTap.observe,
        ),
      );
      final mouse = await showThenTapClose(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsNothing, reason: 'still dismissed');

      await mouse.moveTo(away);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'focus came in meanwhile');
    });

    testWidgets('dismissed with Escape under focus, then the pointer '
        'arriving: focus leaving keeps it closed while the pointer stays', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        page(
          navigator: navigator,
          node: node,
          enableFocus: true,
          tap: TooltipTap.none,
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: away);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      expect(
        find.text('T'),
        findsNothing,
        reason: 'the pointer came in meanwhile',
      );

      await mouse.moveTo(away);
      await tester.pumpAndSettle();
      await mouse.moveTo(centre(tester));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget, reason: 'left and returned');
    });

    group('a hold whose trigger is not inside does not block another', () {
      testWidgets('the pointer left under the dialog: Tab after the pop shows '
          'it', (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          page(
            navigator: navigator,
            node: node,
            enableFocus: true,
            tap: TooltipTap.observe,
          ),
        );
        final mouse = await showThenTapClose(tester);
        await pushDialog(navigator);
        await tester.pumpAndSettle();
        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('T'), findsNothing);

        node.unfocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(find.text('T'), findsOneWidget);
      });

      testWidgets('the pointer left while enableHover was off: Tab after it is '
          'back on shows it', (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final node = FocusNode();
        final hover = ValueNotifier(true);
        addTearDown(node.dispose);
        addTearDown(hover.dispose);
        await tester.pumpWidget(
          ValueListenableBuilder<bool>(
            valueListenable: hover,
            builder: (_, on, _) => page(
              navigator: navigator,
              node: node,
              enableFocus: true,
              enableHover: on,
              tap: TooltipTap.observe,
            ),
          ),
        );
        final mouse = await showThenTapClose(tester);
        hover.value = false;
        await tester.pumpAndSettle();
        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        hover.value = true;
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(find.text('T'), findsOneWidget);
      });

      testWidgets(
        'enableFocus turned off and on with focus inside: the pointer '
        'entering shows it',
        (tester) async {
          final navigator = GlobalKey<NavigatorState>();
          final node = FocusNode();
          final focusOn = ValueNotifier(true);
          addTearDown(node.dispose);
          addTearDown(focusOn.dispose);
          await tester.pumpWidget(
            ValueListenableBuilder<bool>(
              valueListenable: focusOn,
              builder: (_, on, _) => page(
                navigator: navigator,
                node: node,
                enableFocus: on,
                tap: TooltipTap.none,
              ),
            ),
          );
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          await mouse.addPointer(location: away);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(find.text('T'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          focusOn.value = false;
          await tester.pumpAndSettle();
          focusOn.value = true;
          await tester.pumpAndSettle();
          expect(node.hasFocus, isTrue);

          await mouse.moveTo(centre(tester));
          await tester.pumpAndSettle();
          expect(find.text('T'), findsOneWidget);
        },
      );
    });

    testWidgets('a focus tooltip dismissed with Escape shows again when focus '
        'leaves and returns by key, and not after a dialog', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        page(
          navigator: navigator,
          node: node,
          enableFocus: true,
          enableHover: false,
          tap: TooltipTap.none,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);

      await pushDialog(navigator);
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing, reason: 'focus given back, no key');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('T'), findsOneWidget, reason: 'left and returned');
    });
  });
}
