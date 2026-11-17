import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A shown tooltip must follow its own widget's configuration. The overlay
/// entry renders `widget.message`, `widget.tooltipBuilder` and `widget.theme`
/// live, so it only ever needs to be asked to rebuild.
void main() {
  Future<void> hover(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
    await tester.pumpAndSettle();
  }

  const target = SizedBox(key: Key('target'), width: 100, height: 50);

  testWidgets('a tooltip whose enableHover comes back on after the pointer '
      'left while it was off stays hidden', (tester) async {
    final hoverOn = ValueNotifier(true);
    addTearDown(hoverOn.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: hoverOn,
              builder: (_, on, _) =>
                  JustTooltip(message: 'tip', enableHover: on, child: target),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);

    hoverOn.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsNothing);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    hoverOn.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsNothing);
  });

  testWidgets('a tooltip whose tap setting changes as its child moves from '
      'under a resting pointer hides', (tester) async {
    final claim = ValueNotifier(false);
    addTearDown(claim.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<bool>(
              valueListenable: claim,
              builder: (_, on, _) => Padding(
                padding: EdgeInsets.only(left: on ? 300 : 0),
                child: JustTooltip(
                  message: 'tip',
                  tap: on ? TooltipTap.claim : TooltipTap.none,
                  child: target,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    final pointer = tester.getCenter(find.byKey(const Key('target')));
    await gesture.moveTo(pointer);
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);

    claim.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('target'))).contains(pointer),
      isFalse,
    );
    expect(find.text('tip'), findsNothing);
  });

  group('a tooltip whose tap setting changes under a resting pointer', () {
    Future<(ValueNotifier<TooltipTap>, List<String>)> pumpHovered(
      WidgetTester tester,
    ) async {
      final tap = ValueNotifier(TooltipTap.none);
      addTearDown(tap.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<TooltipTap>(
                valueListenable: tap,
                builder: (_, t, _) => JustTooltip(
                  message: 'tip',
                  tap: t,
                  onShow: () => log.add('show'),
                  onHide: () => log.add('hide'),
                  child: target,
                ),
              ),
            ),
          ),
        ),
      );
      await hover(tester);
      expect(find.text('tip'), findsOneWidget);
      return (tap, log);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('stays shown', (tester) async {
      final (tap, log) = await pumpHovered(tester);
      tap.value = TooltipTap.claim;
      await settle(tester);
      expect(find.text('tip'), findsOneWidget);
      expect(log, ['show']);
    });

    testWidgets('stays closed after Escape', (tester) async {
      final (tap, log) = await pumpHovered(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('tip'), findsNothing);

      tap.value = TooltipTap.claim;
      await settle(tester);
      expect(find.text('tip'), findsNothing);
      expect(log, ['show', 'hide']);
    });
  });

  testWidgets('a shown tooltip picks up a new message', (tester) async {
    final message = ValueNotifier('FIRST');
    addTearDown(message.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: message,
              builder: (context, value, _) =>
                  JustTooltip(message: value, child: target),
            ),
          ),
        ),
      ),
    );

    await hover(tester);
    expect(find.text('FIRST'), findsOneWidget);

    message.value = 'SECOND';
    await tester.pumpAndSettle();

    expect(find.text('SECOND'), findsOneWidget);
    expect(find.text('FIRST'), findsNothing);
  });

  testWidgets('a shown tooltip picks up new tooltipBuilder content', (
    tester,
  ) async {
    final label = ValueNotifier('FIRST');
    addTearDown(label.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: label,
              builder: (context, value, _) {
                // Captured, not read live. A closure that reads mutable state
                // at call time hides this bug: the stale closure returns the
                // new value, so the tooltip appears to update even when the
                // overlay was never rebuilt. See #47.
                final snapshot = value;
                return JustTooltip(
                  tooltipBuilder: (_) => Text(snapshot),
                  child: target,
                );
              },
            ),
          ),
        ),
      ),
    );

    await hover(tester);
    expect(find.text('FIRST'), findsOneWidget);

    label.value = 'SECOND';
    await tester.pumpAndSettle();

    expect(find.text('SECOND'), findsOneWidget);
    expect(find.text('FIRST'), findsNothing);
  });

  testWidgets('a controller-shown tooltip drops an emptied message', (
    tester,
  ) async {
    // No pointer anywhere, so show intent is false throughout and the
    // reconcile that hides on content loss returns early. Showing is gated on
    // content; hiding must be too, or the rebuilt overlay draws an empty
    // bubble that `hideOnEmptyMessage` says should not exist.
    final controller = JustTooltipController();
    final message = ValueNotifier('FIRST');
    addTearDown(message.dispose);
    var hidden = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: message,
              builder: (context, value, _) => JustTooltip(
                controller: controller,
                message: value,
                onHide: () => hidden++,
                child: target,
              ),
            ),
          ),
        ),
      ),
    );

    controller.show();
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsOneWidget);

    message.value = '';
    await tester.pumpAndSettle();

    expect(
      find.text(''),
      findsNothing,
      reason: 'an emptied tooltip must not linger as an empty bubble',
    );
    expect(
      controller.isShowing,
      isFalse,
      reason: 'the overlay is gone, not merely blank',
    );
    expect(hidden, 1, reason: 'it hid once, through the normal hide path');
  });

  testWidgets('a shown tooltip picks up a new theme', (tester) async {
    final color = ValueNotifier(Colors.red);
    addTearDown(color.dispose);

    Color? shownColor(WidgetTester tester) {
      final material = tester.widgetList<Material>(find.byType(Material));
      return material
          .where((m) => m.color == Colors.red || m.color == Colors.green)
          .firstOrNull
          ?.color;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<Color>(
              valueListenable: color,
              builder: (context, value, _) => JustTooltip(
                message: 'MSG',
                theme: JustTooltipTheme(backgroundColor: value),
                child: target,
              ),
            ),
          ),
        ),
      ),
    );

    await hover(tester);
    expect(shownColor(tester), Colors.red);

    color.value = Colors.green;
    await tester.pumpAndSettle();

    expect(
      shownColor(tester),
      Colors.green,
      reason: 'the overlay renders widget.theme, so it must be rebuilt',
    );
  });
  group('showDuration changed on a shown tooltip', () {
    const fade = Duration(milliseconds: 300);
    const step = Duration(milliseconds: 20);
    const short = Duration(milliseconds: 300);
    const long = Duration(milliseconds: 1000);
    const bridge = Duration(milliseconds: 100);

    Widget build({
      required JustTooltipController controller,
      required List<String> log,
      Duration? showDuration,
      bool enableHover = true,
      bool enableFocus = false,
      TooltipTap? tap,
      FocusNode? node,
    }) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            controller: controller,
            message: 'tip',
            enableHover: enableHover,
            enableFocus: enableFocus,
            tap: tap,
            showDuration: showDuration,
            animationDuration: fade,
            onShow: () => log.add('show'),
            onHide: () => log.add('hide'),
            child: node == null
                ? const SizedBox(key: Key('child'), width: 80, height: 30)
                : TextButton(
                    key: const Key('child'),
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('btn'),
                  ),
          ),
        ),
      ),
    );

    Future<TestGesture> mouse(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(1, 1));
      addTearDown(gesture.removePointer);
      await tester.pump();
      return gesture;
    }

    Future<void> pumpFor(WidgetTester tester, Duration duration) async {
      for (var t = Duration.zero; t < duration; t += step) {
        await tester.pump(step);
      }
    }

    bool shown() => find.text('tip').evaluate().isNotEmpty;
    Offset child(WidgetTester tester) =>
        tester.getCenter(find.byKey(const Key('child')));
    Offset body(WidgetTester tester) => tester.getCenter(find.text('tip'));
    const away = Offset(1, 1);

    FocusNode focusNode() {
      final node = FocusNode();
      addTearDown(node.dispose);
      return node;
    }

    group('set on a tooltip shown with none', () {
      testWidgets('hover: the countdown starts at the change and hides it '
          'once the pointer has left the child', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(build(controller: controller, log: log));
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        expect(shown(), isTrue);

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        await gesture.moveTo(away);
        await pumpFor(tester, short - bridge);
        expect(shown(), isTrue, reason: 'the countdown owns the hide');
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'the countdown started at the change');
        expect(log, ['show', 'hide']);
      });

      testWidgets('hover: the pointer resting on the child, the countdown '
          'closes it and it stays closed', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(build(controller: controller, log: log));
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        await pumpFor(tester, short - bridge);
        expect(shown(), isTrue);
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(shown(), isFalse, reason: 'closed while the trigger stays');
        expect(log, ['show', 'hide']);
      });

      testWidgets('keyboard focus: hides once focus has left', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        final node = focusNode();
        await tester.pumpWidget(
          build(
            controller: controller,
            log: log,
            enableFocus: true,
            node: node,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpFor(tester, fade);
        expect(node.hasPrimaryFocus, isTrue);
        expect(shown(), isTrue);

        await tester.pumpWidget(
          build(
            controller: controller,
            log: log,
            enableFocus: true,
            node: node,
            showDuration: short,
          ),
        );
        node.unfocus();
        await pumpFor(tester, short - bridge);
        expect(shown(), isTrue, reason: 'the countdown owns the hide');
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('controller.show(): hides when the countdown runs out', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(build(controller: controller, log: log));
        controller.show();
        await pumpFor(tester, fade);

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        await pumpFor(tester, short - bridge);
        expect(shown(), isTrue);
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('a touch tap: hides when the countdown runs out', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, tap: TooltipTap.claim),
        );
        await tester.tap(find.byKey(const Key('child')));
        await pumpFor(tester, fade);
        expect(shown(), isTrue);

        await tester.pumpWidget(
          build(
            controller: controller,
            log: log,
            tap: TooltipTap.claim,
            showDuration: short,
          ),
        );
        await pumpFor(tester, short + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('the pointer on the body: paused until it leaves, then '
          'counted from the exit', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(build(controller: controller, log: log));
        final gesture = await mouse(tester);
        controller.show();
        await pumpFor(tester, fade);
        await gesture.moveTo(body(tester));
        await pumpFor(tester, bridge);

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        await pumpFor(tester, const Duration(milliseconds: 800));
        expect(shown(), isTrue, reason: 'paused while the pointer is on it');

        await gesture.moveTo(away);
        await pumpFor(tester, short - bridge);
        expect(shown(), isTrue, reason: 'counted from the exit');
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('during the Hover Bridge: the bridge still hides it', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(build(controller: controller, log: log));
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        await gesture.moveTo(away);
        await pumpFor(tester, const Duration(milliseconds: 40));

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'the exit was taken with none set');
        expect(log, ['show', 'hide']);
      });
    });

    group('changed on a shown tooltip', () {
      testWidgets('to a shorter one: counted from the change', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        controller.show();
        await pumpFor(tester, fade);

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        await pumpFor(tester, short - bridge);
        expect(shown(), isTrue);
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'before the old countdown ran out');
        expect(log, ['show', 'hide']);
      });

      testWidgets('to a longer one: counted from the change', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        controller.show();
        await pumpFor(tester, const Duration(milliseconds: 200));

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(shown(), isTrue, reason: 'past the old countdown');
        await pumpFor(tester, long - const Duration(milliseconds: 500));
        await pumpFor(tester, fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });
    });

    group('cleared on a shown tooltip', () {
      testWidgets('controller.show(): stays until controller.hide()', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        controller.show();
        await pumpFor(tester, bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, long);
        expect(shown(), isTrue, reason: 'the countdown was cancelled');

        controller.hide();
        await pumpFor(tester, fade + step + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('a touch tap: stays until the next tap', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(
            controller: controller,
            log: log,
            tap: TooltipTap.claim,
            showDuration: short,
          ),
        );
        await tester.tap(find.byKey(const Key('child')));
        await pumpFor(tester, bridge);

        await tester.pumpWidget(
          build(controller: controller, log: log, tap: TooltipTap.claim),
        );
        await pumpFor(tester, long);
        expect(shown(), isTrue, reason: 'the countdown was cancelled');

        await tester.tap(find.byKey(const Key('child')));
        await pumpFor(tester, fade + step + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('hover, the pointer resting on the child: stays, and hides '
          'when the pointer leaves', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, const Duration(milliseconds: 800));
        expect(shown(), isTrue, reason: 'the countdown was cancelled');

        await gesture.moveTo(away);
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('hover, the pointer already gone: the exit the countdown '
          'held hides it at once', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge);
        expect(shown(), isTrue, reason: 'the countdown owns the hide');

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'before the old countdown ran out');
        expect(log, ['show', 'hide']);
      });

      testWidgets('keyboard focus already gone: the exit the countdown held '
          'hides it at once', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        final node = focusNode();
        await tester.pumpWidget(
          build(
            controller: controller,
            log: log,
            enableFocus: true,
            node: node,
            showDuration: long,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpFor(tester, fade);
        node.unfocus();
        await pumpFor(tester, bridge);
        expect(shown(), isTrue, reason: 'the countdown owns the hide');

        await tester.pumpWidget(
          build(
            controller: controller,
            log: log,
            enableFocus: true,
            node: node,
          ),
        );
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'before the old countdown ran out');
        expect(log, ['show', 'hide']);
      });

      testWidgets('hover, the pointer crossed onto the body: stays while it '
          'rests there, hides when it leaves', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, bridge);
        await gesture.moveTo(body(tester));
        await pumpFor(tester, bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, const Duration(milliseconds: 800));
        expect(shown(), isTrue);

        await gesture.moveTo(away);
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('keyboard focus gone while the pointer rests on the body, '
          'enableHover off: hides when the pointer leaves the body', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        final node = focusNode();
        Widget at(Duration? d) => build(
          controller: controller,
          log: log,
          enableHover: false,
          enableFocus: true,
          node: node,
          showDuration: d,
        );
        await tester.pumpWidget(at(long));
        final gesture = await mouse(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpFor(tester, fade);
        await gesture.moveTo(body(tester));
        await pumpFor(tester, bridge);
        node.unfocus();
        await pumpFor(tester, bridge);
        expect(shown(), isTrue, reason: 'paused while the pointer is on it');

        await tester.pumpWidget(at(null));
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(shown(), isTrue, reason: 'the pointer still rests on the body');

        await gesture.moveTo(away);
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'the exit the countdown held');
        expect(log, ['show', 'hide']);
      });
      testWidgets('hover, the pointer gone and back on the child: stays', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, long + fade);
        expect(shown(), isTrue, reason: 'the trigger is back');
        expect(log, ['show']);
      });

      testWidgets('hover gone, then controller.show(): stays until '
          'controller.hide()', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge);
        controller.show();
        await pumpFor(tester, bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, long + fade);
        expect(shown(), isTrue, reason: 'the controller showed it last');
        expect(log, ['show']);
      });

      testWidgets('a touch tap after a hover show the countdown ended: stays '
          'until the next tap', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        Widget at(Duration? d) => build(
          controller: controller,
          log: log,
          tap: TooltipTap.claim,
          showDuration: d,
        );
        await tester.pumpWidget(at(short));
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        await gesture.moveTo(away);
        await pumpFor(tester, short + fade + step);
        expect(shown(), isFalse, reason: 'the countdown ended the hover show');

        await tester.tap(find.byKey(const Key('child')));
        await pumpFor(tester, bridge);
        expect(shown(), isTrue);
        await tester.pumpWidget(at(null));
        await pumpFor(tester, long + fade);
        expect(shown(), isTrue, reason: 'a new show, shown by a tap');
        expect(log, ['show', 'hide', 'show']);
      });

      testWidgets('controller.show(), the pointer crossed its body with hover '
          'on: hides at once', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        final gesture = await mouse(tester);
        controller.show();
        await pumpFor(tester, fade);
        await gesture.moveTo(body(tester));
        await pumpFor(tester, bridge);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse, reason: 'the body exit was a hover exit');
        expect(log, ['show', 'hide']);
      });

      testWidgets('controller.show(), the pointer crossed its body with hover '
          'off: stays', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        Widget at(Duration? d) => build(
          controller: controller,
          log: log,
          enableHover: false,
          showDuration: d,
        );
        await tester.pumpWidget(at(long));
        final gesture = await mouse(tester);
        controller.show();
        await pumpFor(tester, fade);
        await gesture.moveTo(body(tester));
        await pumpFor(tester, bridge);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge);

        await tester.pumpWidget(at(null));
        await pumpFor(tester, long + fade);
        expect(shown(), isTrue, reason: 'no hover exit was left to it');
        expect(log, ['show']);
      });

      testWidgets('keyboard focus holding it, the pointer crossed its body: '
          'stays, and hides once focus leaves', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        final node = focusNode();
        Widget at(Duration? d) => build(
          controller: controller,
          log: log,
          enableFocus: true,
          node: node,
          showDuration: d,
        );
        await tester.pumpWidget(at(long));
        final gesture = await mouse(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpFor(tester, fade);
        await gesture.moveTo(body(tester));
        await pumpFor(tester, bridge);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge);

        await tester.pumpWidget(at(null));
        await pumpFor(tester, long + fade);
        expect(shown(), isTrue, reason: 'keyboard focus still holds it');
        expect(log, ['show']);

        node.unfocus();
        await pumpFor(tester, bridge + fade + step);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });
    });

    group('during a fade-out', () {
      testWidgets('set during an eviction fade: arms nothing, and the tooltip '
          'comes back when the other one hides', (tester) async {
        final log = <String>[];
        final other = JustTooltipController();
        Widget at(Duration? d) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JustTooltip(
                    message: 'tip',
                    showDuration: d,
                    animationDuration: fade,
                    onShow: () => log.add('show'),
                    onHide: () => log.add('hide'),
                    child: const SizedBox(
                      key: Key('child'),
                      width: 80,
                      height: 30,
                    ),
                  ),
                  const SizedBox(height: 120),
                  JustTooltip(
                    controller: other,
                    message: 'other',
                    animationDuration: fade,
                    child: const SizedBox(width: 80, height: 30),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(at(null));
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        other.show();
        await pumpFor(tester, bridge);
        expect(shown(), isTrue, reason: 'fading out for the other one');

        await tester.pumpWidget(at(short));
        await pumpFor(tester, long);
        expect(shown(), isFalse);

        other.hide();
        await pumpFor(tester, fade + step + step);
        expect(shown(), isTrue, reason: 'revived: no countdown closed it');
        expect(log, ['show', 'hide', 'show']);
      });

      testWidgets('cleared during the countdown\'s fade: the fade ends', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: short),
        );
        controller.show();
        await pumpFor(tester, short + bridge);

        await tester.pumpWidget(build(controller: controller, log: log));
        await pumpFor(tester, fade + step);
        expect(shown(), isFalse);
        await pumpFor(tester, long);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });

      testWidgets('set during the bridge\'s fade: the fade ends', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(build(controller: controller, log: log));
        final gesture = await mouse(tester);
        await gesture.moveTo(child(tester));
        await pumpFor(tester, fade);
        await gesture.moveTo(away);
        await pumpFor(tester, bridge + bridge);

        await tester.pumpWidget(
          build(controller: controller, log: log, showDuration: long),
        );
        await pumpFor(tester, fade + step);
        expect(shown(), isFalse);
        await pumpFor(tester, long);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });
    });

    testWidgets('set on a hidden tooltip: the next show counts it down', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(build(controller: controller, log: log));
      await tester.pumpWidget(
        build(controller: controller, log: log, showDuration: short),
      );
      await pumpFor(tester, long);
      controller.show();
      await pumpFor(tester, short - bridge);
      expect(shown(), isTrue);
      await pumpFor(tester, bridge + fade + step);
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });
  });
}
