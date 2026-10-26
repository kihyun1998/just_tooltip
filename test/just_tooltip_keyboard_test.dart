import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A keyboard user can show a tooltip with focus and dismiss any tooltip with
/// Escape (ADR-0010).
void main() {
  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// A focusable button wrapped in a tooltip.
  Widget focusable({
    required FocusNode node,
    String message = 'Hello',
    bool enableFocus = true,
    Duration? waitDuration,
    TooltipRegistry? registry,
    VoidCallback? onShow,
    VoidCallback? onHide,
  }) => JustTooltip(
    message: message,
    enableFocus: enableFocus,
    waitDuration: waitDuration,
    registry: registry,
    onShow: onShow,
    onHide: onHide,
    child: TextButton(
      focusNode: node,
      onPressed: () {},
      child: const Text('btn'),
    ),
  );

  /// Moves focus with the Tab key, the way a keyboard user does.
  Future<void> tab(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  Future<TestGesture> mouseAt(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(position);
    await tester.pumpAndSettle();
    return gesture;
  }

  group('focus', () {
    testWidgets('does not show a tooltip by default', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(app(focusable(node: node, enableFocus: false)));
      await tab(tester);
      expect(node.hasFocus, isTrue);
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('shows it with enableFocus, and losing focus hides it', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var shows = 0, hides = 0;
      await tester.pumpWidget(
        app(
          focusable(node: node, onShow: () => shows++, onHide: () => hides++),
        ),
      );
      await tab(tester);
      expect(node.hasFocus, isTrue);
      expect(find.text('Hello'), findsOneWidget);

      node.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect((shows, hides), (1, 1));
    });

    testWidgets('counts only focus that arrives by a key', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(app(focusable(node: node)));

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('Hello'), findsNothing);

      node.unfocus();
      await tester.pumpAndSettle();
      await tab(tester);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('does not count a click that focuses a text field', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'Hello',
            enableFocus: true,
            child: SizedBox(width: 200, child: TextField(focusNode: node)),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.down(tester.getCenter(find.byType(TextField)));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('hides when enableFocus is turned off under focus', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(app(focusable(node: node)));
      await tab(tester);
      expect(find.text('Hello'), findsOneWidget);
      await tester.pumpWidget(app(focusable(node: node, enableFocus: false)));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('Hello'), findsNothing);

      // Turned back on, it waits for focus to arrive by a key again.
      await tester.pumpWidget(app(focusable(node: node)));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('follows a focused tooltip moved under another one', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final key = GlobalKey();
      Widget build({required bool underA}) {
        Widget slot(bool here) => here
            ? KeyedSubtree(
                key: key,
                child: focusable(node: node, message: 'INNER'),
              )
            : const SizedBox(width: 10, height: 10);
        return app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JustTooltip(message: 'A', enableFocus: true, child: slot(underA)),
              JustTooltip(
                message: 'B',
                enableFocus: true,
                child: slot(!underA),
              ),
            ],
          ),
        );
      }

      await tester.pumpWidget(build(underA: true));
      await tab(tester);
      expect(find.text('INNER'), findsOneWidget);

      await tester.pumpWidget(build(underA: false));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('INNER'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
    });

    testWidgets('waits for waitDuration, as a hover does', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          focusable(
            node: node,
            waitDuration: const Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Hello'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('needs content, as a hover does', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var shows = 0;
      Widget build(String message) =>
          app(focusable(node: node, message: message, onShow: () => shows++));
      await tester.pumpWidget(build(''));
      await tab(tester);
      expect(shows, 0);

      // Content arriving under a focus that never moved shows it.
      await tester.pumpWidget(build('Hello'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(shows, 1);
    });

    testWidgets('nested, shows only the innermost tooltip', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'OUTER',
            enableFocus: true,
            child: focusable(node: node, message: 'INNER'),
          ),
        ),
      );
      await tab(tester);
      expect(find.text('INNER'), findsOneWidget);
      expect(find.text('OUTER'), findsNothing);
    });

    testWidgets('loses to a pointer hovering the outer child elsewhere', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'OUTER',
            child: Container(
              key: const Key('outer'),
              width: 400,
              height: 200,
              alignment: Alignment.center,
              child: focusable(node: node, message: 'INNER'),
            ),
          ),
        ),
      );
      await tab(tester);
      expect(find.text('INNER'), findsOneWidget);

      await mouseAt(
        tester,
        tester.getTopLeft(find.byKey(const Key('outer'))) +
            const Offset(10, 10),
      );
      expect(find.text('OUTER'), findsOneWidget);
    });

    testWidgets('comes back when the tooltip that took its place hides', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              focusable(node: node, message: 'Focused'),
              const SizedBox(height: 40),
              const JustTooltip(
                message: 'Hovered',
                child: SizedBox(key: Key('hover'), width: 100, height: 40),
              ),
            ],
          ),
        ),
      );
      await tab(tester);
      expect(find.text('Focused'), findsOneWidget);

      final mouse = await mouseAt(
        tester,
        tester.getCenter(find.byKey(const Key('hover'))),
      );
      expect(find.text('Hovered'), findsOneWidget);
      expect(find.text('Focused'), findsNothing);

      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('Hovered'), findsNothing);
      expect(find.text('Focused'), findsOneWidget);
    });

    testWidgets('stays open while focus moves into its content', (
      tester,
    ) async {
      final node = FocusNode();
      final inContent = FocusNode();
      addTearDown(node.dispose);
      addTearDown(inContent.dispose);
      await tester.pumpWidget(
        app(
          JustTooltip(
            enableFocus: true,
            tooltipBuilder: (_) => TextButton(
              focusNode: inContent,
              onPressed: () {},
              child: const Text('in content'),
            ),
            child: TextButton(
              focusNode: node,
              onPressed: () {},
              child: const Text('btn'),
            ),
          ),
        ),
      );
      await tab(tester);
      expect(find.text('in content'), findsOneWidget);

      inContent.requestFocus();
      await tester.pumpAndSettle();
      expect(inContent.hasFocus, isTrue);
      expect(find.text('in content'), findsOneWidget);

      await escape(tester);
      expect(find.text('in content'), findsNothing);
    });

    testWidgets('leaves Focus.of to the consumer', (tester) async {
      final outer = FocusNode();
      addTearDown(outer.dispose);
      late BuildContext inner;
      await tester.pumpWidget(
        app(
          Focus(
            focusNode: outer,
            child: JustTooltip(
              message: 'Hello',
              child: Builder(
                builder: (context) {
                  inner = context;
                  return const Text('child');
                },
              ),
            ),
          ),
        ),
      );
      expect(Focus.of(inner), same(outer));
    });
  });

  group('Escape', () {
    testWidgets('dismisses a hovered tooltip until the pointer comes back', (
      tester,
    ) async {
      var hides = 0;
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'Hello',
            onHide: () => hides++,
            child: const SizedBox(key: Key('child'), width: 100, height: 40),
          ),
        ),
      );
      final child = find.byKey(const Key('child'));
      final mouse = await mouseAt(tester, tester.getCenter(child));
      expect(find.text('Hello'), findsOneWidget);

      await escape(tester);
      expect(find.text('Hello'), findsNothing);
      expect(hides, 1);

      // Still inside: a move does not bring it back.
      await mouse.moveTo(tester.getCenter(child) + const Offset(10, 0));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);

      // Out and back in does.
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(child));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('stays dismissed when a nested tooltip lets go of it', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'OUTER',
            child: Container(
              key: const Key('outer'),
              width: 300,
              height: 200,
              alignment: Alignment.center,
              child: const JustTooltip(
                message: 'INNER',
                child: SizedBox(key: Key('inner'), width: 60, height: 30),
              ),
            ),
          ),
        ),
      );
      final outerOnly =
          tester.getTopLeft(find.byKey(const Key('outer'))) +
          const Offset(10, 10);
      final mouse = await mouseAt(tester, outerOnly);
      expect(find.text('OUTER'), findsOneWidget);
      await escape(tester);
      expect(find.text('OUTER'), findsNothing);

      // Into the inner tooltip and back: the pointer never left the outer
      // child, so its release must not reopen the dismissed outer one.
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('inner'))));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);
      await mouse.moveTo(outerOnly);
      await tester.pumpAndSettle();
      expect(find.text('OUTER'), findsNothing);
    });

    testWidgets('dismisses a focused tooltip until focus comes back', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(app(focusable(node: node)));
      await tab(tester);
      expect(find.text('Hello'), findsOneWidget);

      await escape(tester);
      expect(find.text('Hello'), findsNothing);
      expect(node.hasFocus, isTrue);

      node.unfocus();
      await tester.pumpAndSettle();
      await tab(tester);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('dismisses a tooltip shown by its controller', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'Hello',
            controller: controller,
            child: const Text('child'),
          ),
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      expect(controller.isShowing, isTrue);

      await escape(tester);
      expect(controller.isShowing, isFalse);
    });

    testWidgets('lets a tap open a hovered tooltip it dismissed', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            tap: TooltipTap.claim,
            child: SizedBox(key: Key('child'), width: 100, height: 40),
          ),
        ),
      );
      final child = find.byKey(const Key('child'));
      await mouseAt(tester, tester.getCenter(child));
      expect(find.text('Hello'), findsOneWidget);
      await escape(tester);
      expect(find.text('Hello'), findsNothing);

      await tester.tap(child, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('cancels a show still waiting for waitDuration', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            waitDuration: Duration(milliseconds: 500),
            child: SizedBox(key: Key('child'), width: 100, height: 40),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('child'))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('closes the most recently shown tooltip, one per press', (
      tester,
    ) async {
      final first = JustTooltipController();
      final second = JustTooltipController();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JustTooltip(
                message: 'First',
                controller: first,
                registry: TooltipRegistry(),
                child: const Text('a'),
              ),
              JustTooltip(
                message: 'Second',
                controller: second,
                registry: TooltipRegistry(),
                child: const Text('b'),
              ),
            ],
          ),
        ),
      );
      first.show();
      await tester.pumpAndSettle();
      second.show();
      await tester.pumpAndSettle();
      expect((first.isShowing, second.isShowing), (true, true));

      await escape(tester);
      expect((first.isShowing, second.isShowing), (true, false));

      await escape(tester);
      expect((first.isShowing, second.isShowing), (false, false));
    });

    testWidgets('closes one per press across the focus and hover paths', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              focusable(node: node, message: 'Focused'),
              const SizedBox(height: 40),
              JustTooltip(
                message: 'Hovered',
                registry: TooltipRegistry(),
                child: const SizedBox(
                  key: Key('hover'),
                  width: 100,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      );
      await tab(tester);
      await mouseAt(tester, tester.getCenter(find.byKey(const Key('hover'))));
      expect(find.text('Focused'), findsOneWidget);
      expect(find.text('Hovered'), findsOneWidget);

      await escape(tester);
      expect(find.text('Hovered'), findsNothing);
      expect(find.text('Focused'), findsOneWidget);

      await escape(tester);
      expect(find.text('Focused'), findsNothing);
    });

    testWidgets('closes a focused tooltip whose child takes Escape itself', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var childDismissals = 0;
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'Hello',
            enableFocus: true,
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) => childDismissals++,
                ),
              },
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
      expect(find.text('Hello'), findsOneWidget);

      await escape(tester);
      expect(childDismissals, 1);
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('keeps an inner tooltip suppressing its outer one', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'OUTER',
            child: Container(
              width: 300,
              height: 200,
              alignment: Alignment.center,
              child: const JustTooltip(
                message: 'INNER',
                child: SizedBox(key: Key('inner'), width: 60, height: 30),
              ),
            ),
          ),
        ),
      );
      final mouse = await mouseAt(
        tester,
        tester.getCenter(find.byKey(const Key('inner'))),
      );
      expect(find.text('INNER'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('inner'))) + const Offset(5, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsNothing);
      expect(find.text('OUTER'), findsNothing);
    });

    group('inside a dialog', () {
      /// A dialog whose button carries a tooltip.
      Future<FocusNode> openDialog(
        WidgetTester tester, {
        bool enableFocus = true,
        VoidCallback? onHide,
      }) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('dialog'),
                      content: JustTooltip(
                        message: 'Hello',
                        enableFocus: enableFocus,
                        animationDuration: const Duration(milliseconds: 10),
                        onHide: onHide,
                        child: TextButton(
                          focusNode: node,
                          onPressed: () {},
                          child: const Text('btn'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        return node;
      }

      testWidgets('a focused tooltip takes the first press, the dialog the '
          'next', (tester) async {
        final node = await openDialog(tester);
        await tab(tester);
        expect(node.hasFocus, isTrue);
        expect(find.text('Hello'), findsOneWidget);

        await escape(tester);
        expect(find.text('Hello'), findsNothing);
        expect(find.text('dialog'), findsOneWidget);

        await escape(tester);
        expect(find.text('dialog'), findsNothing);
      });

      testWidgets('with no tooltip shown, the press reaches the dialog', (
        tester,
      ) async {
        final node = await openDialog(tester, enableFocus: false);
        await tab(tester);
        expect(node.hasFocus, isTrue);
        expect(find.text('Hello'), findsNothing);

        await escape(tester);
        expect(find.text('dialog'), findsNothing);
      });

      testWidgets('a hovered tooltip closes, and the dialog with it', (
        tester,
      ) async {
        var hides = 0;
        await openDialog(tester, enableFocus: false, onHide: () => hides++);
        await mouseAt(tester, tester.getCenter(find.text('btn')));
        expect(find.text('Hello'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(hides, 1);
        await tester.pumpAndSettle();
        expect(find.text('dialog'), findsNothing);
      });
    });
  });
}
