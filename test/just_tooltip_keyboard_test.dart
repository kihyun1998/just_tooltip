import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A keyboard user can show a tooltip with focus and dismiss any tooltip with
/// Escape (ADR-0010).
void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// A focusable button wrapped in a tooltip.
  Widget focusable({
    required FocusNode node,
    String message = 'Hello',
    bool enableFocus = true,
    Duration? waitDuration,
    JustTooltipController? controller,
  }) => JustTooltip(
    message: message,
    enableFocus: enableFocus,
    waitDuration: waitDuration,
    controller: controller,
    child: TextButton(
      focusNode: node,
      onPressed: () {},
      child: const Text('btn'),
    ),
  );

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
      node.requestFocus();
      await tester.pumpAndSettle();
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
          JustTooltip(
            message: 'Hello',
            enableFocus: true,
            onShow: () => shows++,
            onHide: () => hides++,
            child: TextButton(
              focusNode: node,
              onPressed: () {},
              child: const Text('btn'),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);

      node.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect((shows, hides), (1, 1));
    });

    testWidgets('counts only in the keyboard highlight mode', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(app(focusable(node: node)));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(find.text('Hello'), findsNothing);

      // The mode turning to keyboard while focus stays shows it; turning
      // back to touch hides it.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
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
      node.requestFocus();
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
      Widget build(String message) => app(
        JustTooltip(
          message: message,
          enableFocus: true,
          onShow: () => shows++,
          child: TextButton(
            focusNode: node,
            onPressed: () {},
            child: const Text('btn'),
          ),
        ),
      );
      await tester.pumpWidget(build(''));
      node.requestFocus();
      await tester.pumpAndSettle();
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
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);
      expect(find.text('OUTER'), findsNothing);
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

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
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
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
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
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect(node.hasFocus, isTrue);

      node.unfocus();
      await tester.pumpAndSettle();
      node.requestFocus();
      await tester.pumpAndSettle();
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

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isShowing, isFalse);
    });

    testWidgets('lets a tap open the tooltip again', (tester) async {
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            tap: TooltipTap.claim,
            enableHover: false,
            child: Text('child'),
          ),
        ),
      );
      await tester.tap(find.text('child'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      await tester.tap(find.text('child'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
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

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect((first.isShowing, second.isShowing), (true, false));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect((first.isShowing, second.isShowing), (false, false));
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
      /// A dialog whose button may carry a tooltip.
      Future<FocusNode> openDialog(
        WidgetTester tester, {
        required bool withTooltip,
        bool enableFocus = true,
      }) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        final Widget button = TextButton(
          focusNode: node,
          onPressed: () {},
          child: const Text('btn'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('dialog'),
                      content: withTooltip
                          ? JustTooltip(
                              message: 'Hello',
                              enableFocus: enableFocus,
                              child: button,
                            )
                          : button,
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
        final node = await openDialog(tester, withTooltip: true);
        node.requestFocus();
        await tester.pumpAndSettle();
        expect(find.text('Hello'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Hello'), findsNothing);
        expect(find.text('dialog'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('dialog'), findsNothing);
      });

      testWidgets('with no tooltip shown, the press reaches the dialog', (
        tester,
      ) async {
        final node = await openDialog(
          tester,
          withTooltip: true,
          enableFocus: false,
        );
        node.requestFocus();
        await tester.pumpAndSettle();
        expect(find.text('Hello'), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('dialog'), findsNothing);
      });

      testWidgets('a hovered tooltip closes with the dialog', (tester) async {
        await openDialog(tester, withTooltip: true, enableFocus: false);
        await mouseAt(tester, tester.getCenter(find.text('btn')));
        expect(find.text('Hello'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Hello'), findsNothing);
        expect(find.text('dialog'), findsNothing);
      });
    });
  });
}
