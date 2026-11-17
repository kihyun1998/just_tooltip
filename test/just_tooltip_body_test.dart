import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// The body of an interactive tooltip holds it as its child does: the pointer
/// resting on it pauses `showDuration`, whatever shows the tooltip meanwhile.
void main() {
  const fade = Duration(milliseconds: 300);
  const step = Duration(milliseconds: 20);

  Widget app({
    required JustTooltipController controller,
    required List<String> log,
    bool enableHover = true,
    bool interactive = true,
    bool enableFocus = false,
    Duration? showDuration,
    Widget child = const SizedBox(key: Key('child'), width: 80, height: 30),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            controller: controller,
            message: 'tip',
            enableHover: enableHover,
            interactive: interactive,
            enableFocus: enableFocus,
            showDuration: showDuration,
            animationDuration: fade,
            onShow: () => log.add('show'),
            onHide: () => log.add('hide'),
            child: child,
          ),
        ),
      ),
    );
  }

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

  group('with enableHover off', () {
    testWidgets('the pointer crossing the body pauses showDuration, and '
        'leaving it resumes the countdown', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        app(
          controller: controller,
          log: log,
          enableHover: false,
          showDuration: const Duration(milliseconds: 600),
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, fade);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 900));
      expect(shown(), isTrue, reason: 'paused while the pointer is on it');

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(shown(), isTrue, reason: 'the countdown restarts on leaving');
      await pumpFor(tester, const Duration(milliseconds: 100) + fade + step);
      expect(shown(), isFalse, reason: 'the countdown resumed on leaving');
      expect(log, ['show', 'hide']);
    });
  });

  testWidgets('interactive turned off with the pointer on the body resumes '
      'showDuration', (tester) async {
    final controller = JustTooltipController();
    final log = <String>[];
    Widget build({required bool interactive}) => app(
      controller: controller,
      log: log,
      interactive: interactive,
      showDuration: const Duration(milliseconds: 600),
    );
    await tester.pumpWidget(build(interactive: true));
    final gesture = await mouse(tester);

    controller.show();
    await pumpFor(tester, fade);
    await gesture.moveTo(tester.getCenter(find.text('tip')));
    await pumpFor(tester, const Duration(milliseconds: 900));
    expect(shown(), isTrue, reason: 'paused while the pointer is on it');

    await tester.pumpWidget(build(interactive: false));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(shown(), isTrue, reason: 'the countdown restarts on leaving');
    await pumpFor(tester, const Duration(milliseconds: 100) + fade + step);
    expect(shown(), isFalse, reason: 'the body no longer takes the pointer');
    expect(log, ['show', 'hide']);
  });

  group('interactive turned off with the pointer on a hover-shown body', () {
    Widget build({
      required JustTooltipController controller,
      required List<String> log,
      required bool interactive,
      bool enableHover = true,
      bool enableFocus = false,
      FocusNode? node,
    }) => app(
      controller: controller,
      log: log,
      interactive: interactive,
      enableHover: enableHover,
      enableFocus: enableFocus,
      child: node == null
          ? const SizedBox(key: Key('child'), width: 80, height: 30)
          : TextButton(
              key: const Key('child'),
              focusNode: node,
              onPressed: () {},
              child: const Text('btn'),
            ),
    );

    testWidgets('hides it at once, as leaving a non-interactive child does', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, interactive: true),
      );
      final gesture = await mouse(tester);

      await gesture.moveTo(tester.getCenter(find.byKey(const Key('child'))));
      await pumpFor(tester, fade);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(shown(), isTrue, reason: 'the body holds it');
      expect(log, ['show']);

      await tester.pumpWidget(
        build(controller: controller, log: log, interactive: false),
      );
      await pumpFor(tester, fade + step * 2);
      expect(shown(), isFalse, reason: 'no bridge to wait out');
      expect(log, ['show', 'hide']);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('tip'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('a pointer going on to the child turns the fade back', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, interactive: true),
      );
      final gesture = await mouse(tester);

      final child = tester.getCenter(find.byKey(const Key('child')));
      await gesture.moveTo(child);
      await pumpFor(tester, fade);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 400));

      await tester.pumpWidget(
        build(controller: controller, log: log, interactive: false),
      );
      await pumpFor(tester, fade ~/ 3);
      expect(opacity(tester), inExclusiveRange(0.0, 1.0), reason: 'fading out');
      await gesture.moveTo(child);
      await pumpFor(tester, fade * 2);
      expect(opacity(tester), 1.0, reason: 'turned back');
      expect(log, ['show']);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, fade + step * 2);
      expect(shown(), isFalse, reason: 'leaving a non-interactive child');
      expect(log, ['show', 'hide']);
    });

    testWidgets('keyboard focus in the child still holds it', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        build(
          controller: controller,
          log: log,
          interactive: true,
          enableFocus: true,
          node: node,
        ),
      );
      final gesture = await mouse(tester);

      await gesture.moveTo(tester.getCenter(find.byKey(const Key('child'))));
      await pumpFor(tester, fade);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 400));

      await tester.pumpWidget(
        build(
          controller: controller,
          log: log,
          interactive: false,
          enableFocus: true,
          node: node,
        ),
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'focus holds it');
      expect(log, ['show']);
    });

    testWidgets('with enableHover off, a controller-shown tooltip stays', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(
          controller: controller,
          log: log,
          interactive: true,
          enableHover: false,
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, fade);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 400));

      await tester.pumpWidget(
        build(
          controller: controller,
          log: log,
          interactive: false,
          enableHover: false,
        ),
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'no hover policy to hide it');
      expect(log, ['show']);
    });
  });

  group('enableHover turned off with the pointer on the body', () {
    Widget build({
      required JustTooltipController controller,
      required List<String> log,
      required bool enableHover,
      bool interactive = true,
      bool enableFocus = false,
      TooltipTap? tap,
      Duration? showDuration,
      FocusNode? node,
    }) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            controller: controller,
            message: 'tip',
            enableHover: enableHover,
            interactive: interactive,
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

    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('tip'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    Offset child(WidgetTester tester) =>
        tester.getCenter(find.byKey(const Key('child')));
    Offset body(WidgetTester tester) => tester.getCenter(find.text('tip'));

    /// Shows the tooltip by a pointer on its child and moves the pointer onto
    /// its body.
    Future<TestGesture> restOnHoverShownBody(WidgetTester tester) async {
      final gesture = await mouse(tester);
      await gesture.moveTo(child(tester));
      await pumpFor(tester, fade);
      await gesture.moveTo(body(tester));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(shown(), isTrue, reason: 'the body holds it');
      return gesture;
    }

    /// Leaves the body and checks the tooltip hides at once: fading out
    /// before the Hover Bridge would have run out, and gone after the fade.
    Future<void> leaveAndExpectHideAtOnce(
      WidgetTester tester,
      TestGesture gesture,
      List<String> log,
    ) async {
      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      await tester.pump(step * 2);
      expect(opacity(tester), lessThan(1.0), reason: 'no bridge to wait out');
      await pumpFor(tester, fade);
      expect(shown(), isFalse, reason: 'leaving the body is a hover exit');
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    }

    testWidgets('changes nothing at the toggle, and hides a hover-shown '
        'tooltip at once when the pointer leaves the body', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      final gesture = await restOnHoverShownBody(tester);

      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: false),
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'nothing happens at the toggle');
      expect(log, ['show']);

      await leaveAndExpectHideAtOnce(tester, gesture, log);
    });

    testWidgets('hides a tap-shown tooltip at once when the pointer leaves '
        'the body', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      Widget at(bool enableHover) => build(
        controller: controller,
        log: log,
        enableHover: enableHover,
        tap: TooltipTap.claim,
      );
      await tester.pumpWidget(at(true));
      final gesture = await mouse(tester);
      await tester.tapAt(child(tester));
      await pumpFor(tester, fade);
      await gesture.moveTo(body(tester));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(shown(), isTrue);

      await tester.pumpWidget(at(false));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'nothing happens at the toggle');

      await leaveAndExpectHideAtOnce(tester, gesture, log);
    });

    testWidgets('hides a controller-shown tooltip at once when the pointer '
        'leaves the body', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      final gesture = await mouse(tester);
      controller.show();
      await pumpFor(tester, fade);
      await gesture.moveTo(body(tester));
      await pumpFor(tester, const Duration(milliseconds: 400));

      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: false),
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'nothing happens at the toggle');

      await leaveAndExpectHideAtOnce(tester, gesture, log);
    });

    testWidgets('keeps a tooltip keyboard focus holds', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      Widget at(bool enableHover) => build(
        controller: controller,
        log: log,
        enableHover: enableHover,
        enableFocus: true,
        node: node,
      );
      await tester.pumpWidget(at(true));
      final gesture = await mouse(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      await gesture.moveTo(body(tester));
      await pumpFor(tester, const Duration(milliseconds: 400));

      await tester.pumpWidget(at(false));
      await pumpFor(tester, step);
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'focus holds it');
      expect(log, ['show']);
    });

    testWidgets('restarts showDuration when the pointer leaves the body', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      Widget at(bool enableHover) => build(
        controller: controller,
        log: log,
        enableHover: enableHover,
        showDuration: const Duration(milliseconds: 600),
      );
      await tester.pumpWidget(at(true));
      final gesture = await mouse(tester);
      await gesture.moveTo(child(tester));
      await pumpFor(tester, fade);
      await gesture.moveTo(body(tester));
      await pumpFor(tester, const Duration(milliseconds: 900));
      expect(shown(), isTrue, reason: 'paused while the pointer is on it');

      await tester.pumpWidget(at(false));
      await pumpFor(tester, step);
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(shown(), isTrue, reason: 'the countdown restarts on leaving');
      await pumpFor(tester, const Duration(milliseconds: 100) + fade + step);
      expect(shown(), isFalse, reason: 'the countdown ran out');
      expect(log, ['show', 'hide']);
    });

    testWidgets('with interactive turned off too, hides at once', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      final gesture = await restOnHoverShownBody(tester);

      await tester.pumpWidget(
        build(
          controller: controller,
          log: log,
          enableHover: false,
          interactive: false,
        ),
      );
      await tester.pump();
      await tester.pump(step * 2);
      expect(opacity(tester), lessThan(1.0), reason: 'no bridge to wait out');
      await pumpFor(tester, fade);
      expect(shown(), isFalse, reason: 'the body stopped taking the pointer');
      expect(log, ['show', 'hide']);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('leaving during a controller.hide() fade adds nothing to it', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      final gesture = await restOnHoverShownBody(tester);
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: false),
      );
      await pumpFor(tester, step);

      controller.hide();
      await pumpFor(tester, fade ~/ 3);
      expect(opacity(tester), inExclusiveRange(0.0, 1.0), reason: 'fading out');
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, fade);
      expect(shown(), isFalse);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('a pointer coming back onto the body during the fade does not '
        'turn it back', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      final gesture = await restOnHoverShownBody(tester);
      final onBody = body(tester);
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: false),
      );
      await pumpFor(tester, step);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, fade ~/ 3);
      expect(opacity(tester), inExclusiveRange(0.0, 1.0), reason: 'fading out');
      await gesture.moveTo(onBody);
      await pumpFor(tester, fade + step);
      expect(shown(), isFalse, reason: 'a hover show, and hover is off');
      expect(log, ['show', 'hide']);
    });

    testWidgets('with enableHover on again before the pointer leaves, arms '
        'the Hover Bridge', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      final gesture = await restOnHoverShownBody(tester);
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: false),
      );
      await pumpFor(tester, step);
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: true),
      );
      await pumpFor(tester, step);

      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      await tester.pump(step * 2);
      expect(opacity(tester), 1.0, reason: 'the bridge is waiting');
      await pumpFor(tester, const Duration(milliseconds: 100) + fade);
      expect(shown(), isFalse, reason: 'the bridge ran out');
      expect(log, ['show', 'hide']);
    });

    testWidgets('a body entered with enableHover already off arms nothing', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        build(controller: controller, log: log, enableHover: false),
      );
      final gesture = await mouse(tester);
      controller.show();
      await pumpFor(tester, fade);
      await gesture.moveTo(body(tester));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isTrue, reason: 'the pointer is no trigger');
      expect(log, ['show']);
    });

    for (final leaves in [false, true]) {
      testWidgets('an eviction ends it, and the tooltip that took its place '
          'hiding does not bring it back'
          '${leaves ? ', the pointer leaving during the fade' : ''}', (
        tester,
      ) async {
        final registry = TooltipRegistry();
        final b = JustTooltipController();
        final log = <String>[];
        Widget at(bool enableHover) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JustTooltip(
                    message: 'tip',
                    registry: registry,
                    enableHover: enableHover,
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
                    controller: b,
                    message: 'B',
                    registry: registry,
                    enableHover: false,
                    animationDuration: fade,
                    onShow: () => log.add('B show'),
                    onHide: () => log.add('B hide'),
                    child: const SizedBox(width: 80, height: 30),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(at(true));
        final gesture = await restOnHoverShownBody(tester);
        await tester.pumpWidget(at(false));
        await pumpFor(tester, step);

        b.show();
        await pumpFor(tester, fade ~/ 3);
        expect(opacity(tester), inExclusiveRange(0.0, 1.0), reason: 'evicted');
        if (leaves) await gesture.moveTo(const Offset(1, 1));
        await pumpFor(tester, fade);
        expect(shown(), isFalse);
        expect(log, ['show', 'B show', 'hide']);

        b.hide();
        await pumpFor(tester, fade * 2);
        if (!leaves) await gesture.moveTo(const Offset(1, 1));
        await pumpFor(tester, const Duration(seconds: 1));
        expect(shown(), isFalse, reason: 'no trigger inside to revive it');
        expect(log, ['show', 'B show', 'hide', 'B hide']);
      });
    }
  });

  group('while the pointer rests on the body', () {
    testWidgets('a second controller.show() does not start showDuration; '
        'leaving the body does', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        app(
          controller: controller,
          log: log,
          showDuration: const Duration(milliseconds: 300),
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(shown(), isTrue, reason: 'paused while the pointer is on it');

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(shown(), isTrue, reason: 'the show did not restart the countdown');
      expect(log, ['show']);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(shown(), isTrue, reason: 'the countdown starts on leaving');

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(shown(), isTrue, reason: 'a show off the body restarts it');
      await pumpFor(tester, const Duration(milliseconds: 100) + fade + step);
      expect(shown(), isFalse, reason: 'and the restarted countdown runs');
      expect(log, ['show', 'hide']);
    });

    testWidgets('keyboard focus arriving in the child does not start '
        'showDuration', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          log: log,
          enableFocus: true,
          showDuration: const Duration(milliseconds: 300),
          child: TextButton(
            focusNode: node,
            onPressed: () {},
            child: const Text('btn'),
          ),
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(shown(), isTrue, reason: 'still paused under the pointer');
      expect(log, ['show']);
    });

    testWidgets('a show in the same frame as the hide keeps the countdown '
        'paused under the resting pointer', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                controller: controller,
                message: 'tip',
                showDuration: const Duration(milliseconds: 300),
                animationDuration: Duration.zero,
                onShow: () => log.add('show'),
                onHide: () => log.add('hide'),
                child: const SizedBox(width: 80, height: 30),
              ),
            ),
          ),
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 100));
      // A zero-length fade ends the show at once; the body never leaves.
      controller.hide();
      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(shown(), isTrue, reason: 'still paused under the pointer');
    });

    testWidgets('a body entered after the show ended, before it left the '
        'tree, holds no later show', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                controller: controller,
                message: 'tip',
                showDuration: const Duration(milliseconds: 300),
                animationDuration: Duration.zero,
                onShow: () => log.add('show'),
                onHide: () => log.add('hide'),
                child: const SizedBox(width: 80, height: 30),
              ),
            ),
          ),
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await tester.pump();
      final body = tester.getCenter(find.text('tip'));
      // A zero-length fade ends the show at once; the body leaves the tree
      // with the next frame.
      controller.hide();
      await gesture.moveTo(body);
      await tester.pump();
      expect(shown(), isFalse);
      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 300) + step * 2);
      expect(shown(), isFalse, reason: 'the countdown ran');
      expect(log, ['show', 'hide', 'show', 'hide']);
    });

    testWidgets('a body that faded out from under the pointer holds no later '
        'show', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        app(
          controller: controller,
          log: log,
          showDuration: const Duration(milliseconds: 300),
        ),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 100));
      controller.hide();
      await pumpFor(tester, fade + step * 2);
      expect(shown(), isFalse, reason: 'the body left with the fade');
      // No body is there to send an exit for this move.
      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();

      controller.show();
      await pumpFor(tester, const Duration(milliseconds: 300) + fade + step);
      expect(shown(), isFalse, reason: 'the countdown ran though no exit came');
      expect(log, ['show', 'hide', 'show', 'hide']);
    });
  });

  group('the pointer entering the body while the tooltip fades out', () {
    /// Where the pointer goes to enter: the child, or the tooltip's body.
    Offset spot(WidgetTester tester, String where) => where == 'child'
        ? tester.getCenter(find.byKey(const Key('child')))
        : tester.getCenter(find.text('tip'));

    Widget focusChild(FocusNode node) => TextButton(
      key: const Key('child'),
      focusNode: node,
      onPressed: () {},
      child: const Text('btn'),
    );

    testWidgets('turns it back when the Hover Bridge ran out', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(app(controller: controller, log: log));
      final gesture = await mouse(tester);

      await gesture.moveTo(spot(tester, 'child'));
      await pumpFor(tester, fade);
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 100) + fade ~/ 3);
      expect(shown(), isTrue, reason: 'fading out');
      await gesture.moveTo(spot(tester, 'body'));
      await pumpFor(tester, fade * 2);
      expect(shown(), isTrue);
      expect(log, ['show']);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 100) + fade + step);
      expect(shown(), isFalse, reason: 'leaving the body arms the bridge');
      expect(log, ['show', 'hide']);
    });

    testWidgets('turns back an auto-hide fade, and pauses showDuration', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        app(
          controller: controller,
          log: log,
          showDuration: const Duration(milliseconds: 300),
        ),
      );
      final gesture = await mouse(tester);

      await gesture.moveTo(spot(tester, 'child'));
      await pumpFor(tester, const Duration(milliseconds: 300) + fade ~/ 3);
      expect(shown(), isTrue, reason: 'fading out');
      await gesture.moveTo(spot(tester, 'body'));
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(shown(), isTrue, reason: 'turned back, and paused');
      expect(log, ['show']);

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 300) + fade + step);
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    for (final where in ['child', 'body']) {
      testWidgets('turns back a controller.hide() fade, entering the $where', (
        tester,
      ) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(app(controller: controller, log: log));
        final gesture = await mouse(tester);

        controller.show();
        await pumpFor(tester, fade);
        final target = spot(tester, where);
        controller.hide();
        await pumpFor(tester, fade ~/ 3);
        expect(shown(), isTrue, reason: 'fading out');
        await gesture.moveTo(target);
        await pumpFor(tester, fade * 2);
        expect(shown(), isTrue);
        expect(log, ['show']);
      });

      testWidgets('turns back an Escape fade with the pointer away, entering '
          'the $where', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        await tester.pumpWidget(app(controller: controller, log: log));
        final gesture = await mouse(tester);

        controller.show();
        await pumpFor(tester, fade);
        final target = spot(tester, where);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await pumpFor(tester, fade ~/ 3);
        expect(shown(), isTrue, reason: 'fading out');
        await gesture.moveTo(target);
        await pumpFor(tester, fade * 2);
        expect(shown(), isTrue);
        expect(log, ['show']);
      });

      testWidgets('does not turn back a fade Escape began while keyboard '
          'focus holds it, entering the $where', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          app(
            controller: controller,
            log: log,
            enableFocus: true,
            child: focusChild(node),
          ),
        );
        final gesture = await mouse(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpFor(tester, fade);
        expect(shown(), isTrue, reason: 'shown by keyboard focus');
        final target = spot(tester, where);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await pumpFor(tester, fade ~/ 3);
        expect(shown(), isTrue, reason: 'fading out');
        await gesture.moveTo(target);
        await pumpFor(tester, fade * 2);
        expect(shown(), isFalse, reason: 'focus still holds the dismissal');
        expect(log, ['show', 'hide']);
      });

      testWidgets('does not turn back an auto-hide fade while keyboard focus '
          'still gives it show intent, entering the $where', (tester) async {
        final controller = JustTooltipController();
        final log = <String>[];
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          app(
            controller: controller,
            log: log,
            enableFocus: true,
            showDuration: const Duration(milliseconds: 300),
            child: focusChild(node),
          ),
        );
        final gesture = await mouse(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpFor(tester, const Duration(milliseconds: 200));
        final target = spot(tester, where);
        await pumpFor(tester, const Duration(milliseconds: 100) + fade ~/ 3);
        expect(shown(), isTrue, reason: 'fading out');
        await gesture.moveTo(target);
        await pumpFor(tester, fade * 2);
        expect(shown(), isFalse);
        expect(log, ['show', 'hide']);
      });
    }

    testWidgets('with enableHover off does not turn back an eviction fade, '
        'though keyboard focus is inside', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final b = JustTooltipController();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JustTooltip(
                    message: 'A',
                    registry: registry,
                    enableHover: false,
                    enableFocus: true,
                    animationDuration: fade,
                    onShow: () => log.add('show A'),
                    onHide: () => log.add('hide A'),
                    child: TextButton(
                      focusNode: node,
                      onPressed: () {},
                      child: const Text('btn'),
                    ),
                  ),
                  const SizedBox(height: 150),
                  JustTooltip(
                    controller: b,
                    message: 'B',
                    registry: registry,
                    animationDuration: fade,
                    onShow: () => log.add('show B'),
                    onHide: () => log.add('hide B'),
                    child: const SizedBox(width: 80, height: 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final gesture = await mouse(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(find.text('A'), findsOneWidget, reason: 'shown by keyboard focus');
      final body = tester.getCenter(find.text('A'));
      b.show();
      await pumpFor(tester, fade ~/ 3);
      expect(find.text('A'), findsOneWidget, reason: 'A fading out');
      await gesture.moveTo(body);
      await pumpFor(tester, fade * 2);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(log, ['show A', 'show B', 'hide A']);
    });

    testWidgets('with enableHover off does not turn it back', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        app(controller: controller, log: log, enableHover: false),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, fade);
      final target = spot(tester, 'body');
      controller.hide();
      await pumpFor(tester, fade ~/ 3);
      expect(shown(), isTrue, reason: 'fading out');
      await gesture.moveTo(target);
      await pumpFor(tester, fade * 2);
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('of a non-interactive tooltip changes nothing', (tester) async {
      final controller = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        app(controller: controller, log: log, interactive: false),
      );
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, fade);
      final target = spot(tester, 'body');
      controller.hide();
      await pumpFor(tester, fade ~/ 3);
      expect(shown(), isTrue, reason: 'fading out');
      await gesture.moveTo(target);
      await pumpFor(tester, fade * 2);
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('turns back a fade its registry began, and takes the registry '
        'back', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final b = JustTooltipController();
      Widget tip(String name, JustTooltipController controller) => JustTooltip(
        controller: controller,
        message: name,
        registry: registry,
        animationDuration: fade,
        onShow: () => log.add('show $name'),
        onHide: () => log.add('hide $name'),
        child: SizedBox(key: Key(name), width: 80, height: 30),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tip('A', a),
                  const SizedBox(height: 150),
                  tip('B', b),
                ],
              ),
            ),
          ),
        ),
      );
      final gesture = await mouse(tester);

      a.show();
      await pumpFor(tester, fade);
      final body = tester.getCenter(find.text('A'));
      b.show();
      await pumpFor(tester, fade ~/ 3);
      expect(find.text('A'), findsOneWidget, reason: 'A fading out');
      await gesture.moveTo(body);
      await pumpFor(tester, fade * 2);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(log, ['show A', 'show B', 'hide B']);
    });

    group('as the tooltip moves under a still pointer', () {
      /// A at [dx] across, B below it, on one registry.
      Widget pair({
        required double dx,
        double dy = 0,
        required JustTooltipController a,
        required JustTooltipController b,
        required TooltipRegistry registry,
        required List<String> log,
      }) {
        Widget tip(String name, JustTooltipController controller) =>
            JustTooltip(
              controller: controller,
              message: name,
              registry: registry,
              animationDuration: fade,
              onShow: () => log.add('show $name'),
              onHide: () => log.add('hide $name'),
              child: SizedBox(key: Key(name), width: 80, height: 30),
            );
        return MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: dx, top: 100 + dy),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tip('A', a),
                    const SizedBox(height: 150),
                    tip('B', b),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('a fade Escape began with the pointer on the child is not '
          'turned back, as the body comes under it', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final a = JustTooltipController();
        final b = JustTooltipController();
        Widget build(double dy) =>
            pair(dx: 50, dy: dy, a: a, b: b, registry: registry, log: log);
        await tester.pumpWidget(build(0));
        final gesture = await mouse(tester);

        final child = tester.getCenter(find.byKey(const Key('A')));
        await gesture.moveTo(child);
        await pumpFor(tester, fade);
        expect(find.text('A'), findsOneWidget, reason: 'shown by hover');
        final rise = child.dy - tester.getCenter(find.text('A')).dy;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await pumpFor(tester, fade ~/ 3);
        await tester.pumpWidget(build(rise));
        await tester.pump();
        expect(
          tester.getCenter(find.text('A')),
          child,
          reason: 'the body under the still pointer',
        );
        await pumpFor(tester, fade * 2);
        expect(find.text('A'), findsNothing, reason: 'the dismissal holds');
        expect(log, ['show A', 'hide A']);
      });

      for (final where in ['child', 'body']) {
        testWidgets('a fade Escape began with the pointer on the child, which '
            'then slid away from it, is turned back by moving onto the '
            '$where', (tester) async {
          final log = <String>[];
          final registry = TooltipRegistry();
          final a = JustTooltipController();
          final b = JustTooltipController();
          Widget build(double dx) =>
              pair(dx: dx, a: a, b: b, registry: registry, log: log);
          await tester.pumpWidget(build(50));
          final gesture = await mouse(tester);

          await gesture.moveTo(tester.getCenter(find.byKey(const Key('A'))));
          await pumpFor(tester, fade);
          expect(find.text('A'), findsOneWidget, reason: 'shown by hover');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          // The child slides out from under the still pointer.
          await tester.pumpWidget(build(350));
          await tester.pump();
          await pumpFor(tester, fade ~/ 3);
          expect(find.text('A'), findsOneWidget, reason: 'fading out');
          await gesture.moveTo(
            where == 'child'
                ? tester.getCenter(find.byKey(const Key('A')))
                : tester.getCenter(find.text('A')),
          );
          await pumpFor(tester, fade * 2);
          expect(find.text('A'), findsOneWidget);
          expect(log, ['show A']);
        });

        Offset spotOfA(WidgetTester tester) => where == 'child'
            ? tester.getCenter(find.byKey(const Key('A')))
            : tester.getCenter(find.text('A'));

        testWidgets('a controller.hide() fade is turned back, as the $where '
            'comes under it', (tester) async {
          final log = <String>[];
          final registry = TooltipRegistry();
          final a = JustTooltipController();
          final b = JustTooltipController();
          Widget build(double dx) =>
              pair(dx: dx, a: a, b: b, registry: registry, log: log);
          await tester.pumpWidget(build(50));
          final gesture = await mouse(tester);

          a.show();
          await pumpFor(tester, fade);
          final target = spotOfA(tester) + const Offset(200, 0);
          await gesture.moveTo(target);
          await tester.pump();
          a.hide();
          await pumpFor(tester, fade ~/ 3);
          await tester.pumpWidget(build(250));
          await tester.pump();
          expect(spotOfA(tester), target, reason: 'under the still pointer');
          await pumpFor(tester, fade * 2);
          expect(find.text('A'), findsOneWidget);
          expect(log, ['show A']);
        });

        testWidgets('an eviction fade is not turned back, as the $where '
            'comes under it', (tester) async {
          final log = <String>[];
          final registry = TooltipRegistry();
          final a = JustTooltipController();
          final b = JustTooltipController();
          Widget build(double dx) =>
              pair(dx: dx, a: a, b: b, registry: registry, log: log);
          await tester.pumpWidget(build(50));
          final gesture = await mouse(tester);

          a.show();
          await pumpFor(tester, fade);
          final target = spotOfA(tester) + const Offset(200, 0);
          await gesture.moveTo(target);
          await tester.pump();
          b.show();
          await pumpFor(tester, fade ~/ 3);
          await tester.pumpWidget(build(250));
          await tester.pump();
          expect(spotOfA(tester), target, reason: 'under the still pointer');
          await pumpFor(tester, fade * 2);
          expect(find.text('A'), findsNothing, reason: 'no act: A waits');
          expect(find.text('B'), findsOneWidget);
          expect(log, ['show A', 'show B', 'hide A']);
        });
      }
    });

    testWidgets('does not turn back a fade its child scrolling out of sight '
        'began', (tester) async {
      final controller = JustTooltipController();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 100, top: 200),
                child: SizedBox(
                  width: 400,
                  height: 100,
                  child: SingleChildScrollView(
                    controller: scroll,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        JustTooltip(
                          controller: controller,
                          message: 'tip',
                          animationDuration: fade,
                          onShow: () => log.add('show'),
                          onHide: () => log.add('hide'),
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
      final gesture = await mouse(tester);

      controller.show();
      await pumpFor(tester, fade);
      scroll.jumpTo(300);
      await pumpFor(tester, fade ~/ 3);
      expect(shown(), isTrue, reason: 'fading out at the clip edge');
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, fade * 2);
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });
  });

  group('the pointer leaving the body', () {
    testWidgets('hides a tooltip that keyboard focus is inside but does not '
        'hold, after the body turned its fade back', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final registry = TooltipRegistry();
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'A',
                registry: registry,
                enableFocus: true,
                direction: TooltipDirection.top,
                animationDuration: fade,
                onShow: () => log.add('show A'),
                onHide: () => log.add('hide A'),
                child: SizedBox(
                  key: const Key('a'),
                  width: 300,
                  height: 100,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: JustTooltip(
                      message: 'B',
                      registry: registry,
                      enableFocus: true,
                      direction: TooltipDirection.bottom,
                      animationDuration: fade,
                      onShow: () => log.add('show B'),
                      onHide: () => log.add('hide B'),
                      child: TextButton(
                        focusNode: node,
                        onPressed: () {},
                        child: const Text('b'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      final gesture = await mouse(tester);
      await gesture.moveTo(
        tester.getTopLeft(find.byKey(const Key('a'))) + const Offset(10, 10),
      );
      await pumpFor(tester, fade * 2);
      expect(log, ['show B', 'show A', 'hide B'], reason: 'the pointer wins');

      await gesture.moveTo(tester.getCenter(find.text('A')));
      await pumpFor(tester, fade ~/ 2);
      expect(find.text('A'), findsOneWidget, reason: 'the body holds A');

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 100) + fade * 2);
      expect(find.text('A'), findsNothing, reason: "B's focus suppresses A");
      expect(find.text('B'), findsOneWidget, reason: 'B revives');
      expect(log, ['show B', 'show A', 'hide B', 'hide A', 'show B']);
    });

    testWidgets('hides a tooltip closed with Escape while keyboard focus was '
        'inside and then shown by its controller, as with no focus', (
      tester,
    ) async {
      final controller = JustTooltipController();
      final node = FocusNode();
      addTearDown(node.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        app(
          controller: controller,
          log: log,
          enableFocus: true,
          child: TextButton(
            key: const Key('child'),
            focusNode: node,
            onPressed: () {},
            child: const Text('btn'),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade * 2);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFor(tester, fade * 2);
      expect(shown(), isFalse, reason: 'Escape closed it');
      controller.show();
      await pumpFor(tester, fade);
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, fade);
      expect(shown(), isTrue, reason: 'the body holds it');

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 100) + fade * 2);
      expect(shown(), isFalse, reason: 'focus holds the dismissal, not it');
      expect(log, ['show', 'hide', 'show', 'hide']);
    });

    testWidgets('keeps a tooltip keyboard focus holds after the body turned '
        'back its eviction fade', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final registry = TooltipRegistry();
      final d = JustTooltipController();
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                JustTooltip(
                  message: 'A',
                  registry: registry,
                  enableFocus: true,
                  direction: TooltipDirection.top,
                  animationDuration: fade,
                  onShow: () => log.add('show A'),
                  onHide: () => log.add('hide A'),
                  child: TextButton(
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('a'),
                  ),
                ),
                const SizedBox(height: 100),
                JustTooltip(
                  message: 'D',
                  registry: registry,
                  controller: d,
                  direction: TooltipDirection.bottom,
                  animationDuration: fade,
                  onShow: () => log.add('show D'),
                  onHide: () => log.add('hide D'),
                  child: const SizedBox(width: 40, height: 20),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade * 2);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      final gesture = await mouse(tester);
      final bodyOfA = tester.getCenter(find.text('A'));
      d.show();
      await pumpFor(tester, fade ~/ 3);
      expect(find.text('A'), findsOneWidget, reason: 'A fading out');
      await gesture.moveTo(bodyOfA);
      await pumpFor(tester, fade * 2);
      expect(log, ['show A', 'show D', 'hide D'], reason: 'A took it back');

      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(milliseconds: 100) + fade * 2);
      expect(find.text('A'), findsOneWidget, reason: 'focus holds A');
      expect(log, ['show A', 'show D', 'hide D']);
    });
  });

  group('a tooltip keyboard focus holds, its eviction fade turned back from '
      'the body, closes as one turned back from the child', () {
    const bridge = Duration(milliseconds: 100);

    /// A shown by keyboard focus, evicted by D's `show()`, the pointer
    /// entering [where] of A during the fade, then resting on A's body.
    Future<
      ({
        TestGesture gesture,
        FocusNode a,
        FocusNode other,
        List<String> log,
        ScrollController scroll,
        void Function(void Function(_EvictionConfig)) configure,
      })
    >
    turnBack(
      WidgetTester tester,
      String where, {
      Duration? showDuration,
    }) async {
      final a = FocusNode();
      final other = FocusNode();
      final scroll = ScrollController();
      addTearDown(a.dispose);
      addTearDown(other.dispose);
      addTearDown(scroll.dispose);
      final registry = TooltipRegistry();
      final second = TooltipRegistry();
      final d = JustTooltipController();
      final log = <String>[];
      final config = _EvictionConfig();
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 60,
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: Column(
                          children: [
                            JustTooltip(
                              message: 'A',
                              registry: config.secondRegistry
                                  ? second
                                  : registry,
                              enableFocus: config.enableFocus,
                              enableHover: config.enableHover,
                              interactive: config.interactive,
                              showDuration: showDuration,
                              direction: TooltipDirection.right,
                              animationDuration: fade,
                              onShow: () => log.add('show A'),
                              onHide: () => log.add('hide A'),
                              child: TextButton(
                                key: const Key('a'),
                                focusNode: a,
                                onPressed: () {},
                                child: const Text('a'),
                              ),
                            ),
                            const SizedBox(height: 300),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                    JustTooltip(
                      message: 'D',
                      registry: registry,
                      controller: d,
                      direction: TooltipDirection.bottom,
                      animationDuration: fade,
                      onShow: () => log.add('show D'),
                      onHide: () => log.add('hide D'),
                      child: const SizedBox(width: 40, height: 20),
                    ),
                    TextButton(
                      focusNode: other,
                      onPressed: () {},
                      child: const Text('other'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade ~/ 3);
      expect(a.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      final gesture = await mouse(tester);
      final bodyOfA = tester.getCenter(find.text('A'));
      d.show();
      await pumpFor(tester, fade ~/ 3);
      expect(find.text('A'), findsOneWidget, reason: 'A fading out');
      await gesture.moveTo(
        where == 'body'
            ? bodyOfA
            : tester.getCenter(find.byKey(const Key('a'))),
      );
      await pumpFor(tester, fade);
      if (where == 'child') await gesture.moveTo(bodyOfA);
      await pumpFor(tester, fade);
      expect(log, ['show A', 'show D', 'hide D'], reason: 'A took it back');
      return (
        gesture: gesture,
        a: a,
        other: other,
        log: log,
        scroll: scroll,
        configure: (void Function(_EvictionConfig) change) =>
            rebuild(() => change(config)),
      );
    }

    for (final where in ['child', 'body']) {
      testWidgets('hides once focus leaves after the pointer has left, '
          'entering the $where', (tester) async {
        final s = await turnBack(tester, where);
        await s.gesture.moveTo(const Offset(1, 1));
        await pumpFor(tester, bridge + fade * 2);
        expect(find.text('A'), findsOneWidget, reason: 'focus holds A');

        s.other.requestFocus();
        await pumpFor(tester, bridge + fade * 2);
        expect(find.text('A'), findsNothing, reason: 'nothing holds A');
        expect(s.log, ['show A', 'show D', 'hide D', 'hide A']);
      });

      testWidgets('kept once focus leaves under the resting pointer, hides '
          'after the Hover Bridge once the pointer leaves, entering the '
          '$where', (tester) async {
        final s = await turnBack(tester, where);
        s.other.requestFocus();
        await pumpFor(tester, bridge + fade * 2);
        expect(find.text('A'), findsOneWidget, reason: 'the body holds A');
        expect(s.log, ['show A', 'show D', 'hide D']);

        await s.gesture.moveTo(const Offset(1, 1));
        await pumpFor(tester, bridge ~/ 2);
        expect(find.text('A'), findsOneWidget, reason: 'the bridge waits');
        await pumpFor(tester, bridge + fade * 2);
        expect(find.text('A'), findsNothing, reason: 'nothing holds A');
        expect(s.log, ['show A', 'show D', 'hide D', 'hide A']);
      });

      testWidgets('hides once enableFocus is turned off, entering the $where', (
        tester,
      ) async {
        final s = await turnBack(tester, where);
        await s.gesture.moveTo(const Offset(1, 1));
        await pumpFor(tester, bridge + fade * 2);
        s.configure((c) => c.enableFocus = false);
        await pumpFor(tester, bridge + fade * 2);
        expect(find.text('A'), findsNothing);
        expect(s.log, ['show A', 'show D', 'hide D', 'hide A']);
      });

      for (final change in ['interactive off', 'a registry change']) {
        testWidgets('kept through $change while focus holds it, hides once '
            'nothing holds it, entering the $where', (tester) async {
          final s = await turnBack(tester, where);
          s.configure(
            (c) => change == 'interactive off'
                ? c.interactive = false
                : c.secondRegistry = true,
          );
          await pumpFor(tester, bridge + fade * 2);
          expect(find.text('A'), findsOneWidget, reason: 'focus holds A');

          s.other.requestFocus();
          await pumpFor(tester, bridge + fade * 2);
          if (change == 'a registry change') {
            // The pointer still rests on the body, which holds A.
            expect(find.text('A'), findsOneWidget, reason: 'the body holds A');
            await s.gesture.moveTo(const Offset(1, 1));
            await pumpFor(tester, bridge + fade * 2);
          }
          expect(find.text('A'), findsNothing, reason: 'nothing holds A');
          expect(s.log, ['show A', 'show D', 'hide D', 'hide A']);
        });
      }

      testWidgets('hides when its child is scrolled out of sight and comes '
          'back with it, entering the $where', (tester) async {
        final s = await turnBack(tester, where);
        s.scroll.jumpTo(200);
        await pumpFor(tester, fade * 2);
        expect(find.text('A'), findsNothing, reason: 'clipped away');
        s.scroll.jumpTo(0);
        await pumpFor(tester, fade * 2);
        expect(find.text('A'), findsOneWidget, reason: 'focus still holds A');
        expect(s.log, ['show A', 'show D', 'hide D', 'hide A', 'show A']);
      });

      testWidgets('closed by showDuration, stays closed when its trigger is '
          're-derived, entering the $where', (tester) async {
        final s = await turnBack(
          tester,
          where,
          showDuration: const Duration(milliseconds: 500),
        );
        await s.gesture.moveTo(const Offset(1, 1));
        await pumpFor(tester, const Duration(milliseconds: 500) + fade * 2);
        expect(find.text('A'), findsNothing, reason: 'the auto-hide closed A');
        expect(s.a.hasPrimaryFocus, isTrue);

        s.configure((c) => c.enableHover = false);
        await pumpFor(tester, fade * 2);
        expect(find.text('A'), findsNothing, reason: 'focus holds the close');
        expect(s.log, ['show A', 'show D', 'hide D', 'hide A']);
      });
    }
  });

  group('a pointer resting on the body, entered with enableHover on, holds '
      'the tooltip against another trigger leaving', () {
    const bridge = Duration(milliseconds: 100);

    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('A'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    /// A shown by keyboard focus, the pointer moved onto its body and resting
    /// there.
    Future<
      ({
        TestGesture gesture,
        FocusNode other,
        JustTooltipController a,
        JustTooltipController d,
        List<String> log,
        ScrollController scroll,
        GlobalKey<NavigatorState> navigator,
        void Function(void Function(_HoldConfig)) configure,
      })
    >
    restOnFocusShownBody(WidgetTester tester, {Duration? showDuration}) async {
      final node = FocusNode();
      final other = FocusNode();
      final scroll = ScrollController();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      addTearDown(scroll.dispose);
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final d = JustTooltipController();
      final navigator = GlobalKey<NavigatorState>();
      final log = <String>[];
      final config = _HoldConfig()..showDuration = showDuration;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 60,
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: Column(
                          children: [
                            JustTooltip(
                              message: 'A',
                              controller: a,
                              registry: registry,
                              enableFocus: config.enableFocus,
                              enableHover: config.enableHover,
                              showDuration: config.showDuration,
                              direction: TooltipDirection.right,
                              animationDuration: fade,
                              onShow: () => log.add('show A'),
                              onHide: () => log.add('hide A'),
                              child: TextButton(
                                key: const Key('a'),
                                focusNode: node,
                                onPressed: () {},
                                child: const Text('a'),
                              ),
                            ),
                            const SizedBox(height: 300),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                    JustTooltip(
                      message: 'D',
                      registry: registry,
                      controller: d,
                      direction: TooltipDirection.bottom,
                      animationDuration: fade,
                      onShow: () => log.add('show D'),
                      onHide: () => log.add('hide D'),
                      child: const SizedBox(width: 40, height: 20),
                    ),
                    TextButton(
                      focusNode: other,
                      onPressed: () {},
                      child: const Text('other'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final gesture = await mouse(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('A'), findsOneWidget);
      expect(log, ['show A']);
      return (
        gesture: gesture,
        other: other,
        a: a,
        d: d,
        log: log,
        scroll: scroll,
        navigator: navigator,
        configure: (void Function(_HoldConfig) change) =>
            rebuild(() => change(config)),
      );
    }

    /// Leaves the body and checks the tooltip hides after the Hover Bridge:
    /// not fading out halfway through it, and gone after it and the fade.
    Future<void> leaveAndExpectBridge(
      WidgetTester tester,
      TestGesture gesture,
    ) async {
      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      await pumpFor(tester, bridge ~/ 2);
      expect(find.text('A'), findsOneWidget);
      expect(opacity(tester), 1.0, reason: 'the bridge is still waiting');
      await pumpFor(tester, bridge + fade + step);
      expect(find.text('A'), findsNothing, reason: 'the bridge ran out');
    }

    testWidgets('keyboard focus leaving does not hide it; leaving the body '
        'hides it after the Hover Bridge', (tester) async {
      final s = await restOnFocusShownBody(tester);
      s.other.requestFocus();
      await pumpFor(tester, bridge + fade * 2);
      expect(find.text('A'), findsOneWidget, reason: 'the body holds it');
      expect(s.log, ['show A']);

      await leaveAndExpectBridge(tester, s.gesture);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('A'), findsNothing);
      expect(s.log, ['show A', 'hide A']);
    });

    testWidgets('enableFocus turned off does not hide it; leaving the body '
        'hides it after the Hover Bridge', (tester) async {
      final s = await restOnFocusShownBody(tester);
      s.configure((c) => c.enableFocus = false);
      await pumpFor(tester, bridge + fade * 2);
      expect(find.text('A'), findsOneWidget, reason: 'the body holds it');
      expect(s.log, ['show A']);

      await leaveAndExpectBridge(tester, s.gesture);
      expect(s.log, ['show A', 'hide A']);
    });

    testWidgets('with enableHover turned off since the entry it still holds '
        'it, and leaving the body hides it at once', (tester) async {
      final s = await restOnFocusShownBody(tester);
      s.configure((c) => c.enableHover = false);
      await pumpFor(tester, step);
      s.other.requestFocus();
      await pumpFor(tester, bridge + fade * 2);
      expect(find.text('A'), findsOneWidget, reason: 'the body holds it');
      expect(s.log, ['show A']);

      await s.gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      await tester.pump(step * 2);
      expect(opacity(tester), lessThan(1.0), reason: 'no bridge to wait out');
      await pumpFor(tester, fade);
      expect(find.text('A'), findsNothing);
      expect(s.log, ['show A', 'hide A']);
    });

    testWidgets('with showDuration set, the countdown still owns the hide', (
      tester,
    ) async {
      const show = Duration(milliseconds: 500);
      final s = await restOnFocusShownBody(tester, showDuration: show);
      s.other.requestFocus();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('A'), findsOneWidget, reason: 'paused on the body');

      await s.gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, show - bridge);
      expect(find.text('A'), findsOneWidget, reason: 'restarted on leaving');
      await pumpFor(tester, bridge + fade + step);
      expect(find.text('A'), findsNothing, reason: 'the countdown ran out');
      expect(s.log, ['show A', 'hide A']);
    });

    testWidgets('a body that appears under a still pointer holds it too; '
        'leaving the body hides it after the Hover Bridge', (tester) async {
      final s = await restOnFocusShownBody(tester);
      final bodyOfA = tester.getCenter(find.text('A'));
      await s.gesture.moveTo(const Offset(1, 1));
      s.other.requestFocus();
      await pumpFor(tester, bridge + fade * 2);
      expect(find.text('A'), findsNothing, reason: 'nothing holds A');
      await s.gesture.moveTo(bodyOfA);
      await pumpFor(tester, step);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await pumpFor(tester, fade);
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'focus came back by a key',
      );
      expect(tester.getCenter(find.text('A')), bodyOfA);

      s.other.requestFocus();
      await pumpFor(tester, bridge + fade * 2);
      expect(find.text('A'), findsOneWidget, reason: 'the body holds it');

      await leaveAndExpectBridge(tester, s.gesture);
      expect(s.log, ['show A', 'hide A', 'show A', 'hide A']);
    });

    for (final close in [
      'an eviction',
      'Escape',
      'controller.hide()',
      'its child scrolled out of sight',
      'a route covering it',
    ]) {
      testWidgets('does not keep it from $close', (tester) async {
        final s = await restOnFocusShownBody(tester);
        s.other.requestFocus();
        await pumpFor(tester, bridge + fade * 2);
        expect(find.text('A'), findsOneWidget, reason: 'the body holds it');

        switch (close) {
          case 'an eviction':
            s.d.show();
          case 'Escape':
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          case 'controller.hide()':
            s.a.hide();
          case 'its child scrolled out of sight':
            s.scroll.jumpTo(200);
          case 'a route covering it':
            showDialog<void>(
              context: s.navigator.currentContext!,
              builder: (_) => const Text('dialog'),
            );
        }
        await pumpFor(tester, fade * 2);
        expect(find.text('A'), findsNothing, reason: '$close hid it');
        expect(s.log.where((e) => e.endsWith('A')), ['show A', 'hide A']);

        if (close == 'an eviction') s.d.hide();
        if (close == 'its child scrolled out of sight') s.scroll.jumpTo(0);
        if (close == 'a route covering it') s.navigator.currentState!.pop();
        await pumpFor(tester, const Duration(seconds: 1));
        expect(find.text('A'), findsNothing, reason: 'nothing brings A back');
        expect(s.log.where((e) => e.endsWith('A')), ['show A', 'hide A']);
      });
    }
  });

  group('a body entered with enableHover off holds nothing against the '
      'Hover Bridge', () {
    const bridge = Duration(milliseconds: 100);

    Widget build({
      required List<String> log,
      required bool enableHover,
      bool enableFocus = false,
      Duration? showDuration,
      FocusNode? node,
      FocusNode? other,
    }) => MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            JustTooltip(
              message: 'tip',
              enableHover: enableHover,
              enableFocus: enableFocus,
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
            if (other != null)
              TextButton(
                focusNode: other,
                onPressed: () {},
                child: const Text('other'),
              ),
          ],
        ),
      ),
    );

    /// Moves the pointer onto the body during the bridge, rests it there for
    /// 200 ms and moves it away: the bridge hid the tooltip, for good.
    Future<void> enterBodyAndExpectBridge(
      WidgetTester tester,
      TestGesture gesture,
      List<String> log,
    ) async {
      await pumpFor(tester, step);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, bridge + fade + step);
      expect(shown(), isFalse, reason: 'the entry left the bridge armed');
      await pumpFor(tester, const Duration(milliseconds: 200) - fade);
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    }

    testWidgets('armed by the child exit enableHover off causes: the bridge '
        'hides it', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(build(log: log, enableHover: true));
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byKey(const Key('child'))));
      await pumpFor(tester, fade);
      expect(shown(), isTrue);

      await tester.pumpWidget(build(log: log, enableHover: false));
      await enterBodyAndExpectBridge(tester, gesture, log);
    });

    Future<({TestGesture gesture, FocusNode other})> focusShownThenAway(
      WidgetTester tester,
      List<String> log,
    ) async {
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        build(
          log: log,
          enableHover: false,
          enableFocus: true,
          node: node,
          other: other,
        ),
      );
      final gesture = await mouse(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      expect(shown(), isTrue);
      other.requestFocus();
      return (gesture: gesture, other: other);
    }

    testWidgets('armed by keyboard focus leaving: the bridge hides it', (
      tester,
    ) async {
      final log = <String>[];
      final s = await focusShownThenAway(tester, log);
      await enterBodyAndExpectBridge(tester, s.gesture, log);
    });

    testWidgets('a body entered with enableHover off holds nothing: '
        'keyboard focus leaving under the resting pointer hides it after '
        'the bridge', (tester) async {
      final log = <String>[];
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        build(
          log: log,
          enableHover: false,
          enableFocus: true,
          node: node,
          other: other,
        ),
      );
      final gesture = await mouse(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(shown(), isTrue);

      other.requestFocus();
      await pumpFor(tester, bridge + fade + step);
      expect(shown(), isFalse, reason: 'the pointer is not a trigger here');
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('armed by keyboard focus leaving, showDuration set and '
        'cleared under the pointer: nothing is left shown', (tester) async {
      final log = <String>[];
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      Widget at(Duration? showDuration) => build(
        log: log,
        enableHover: false,
        enableFocus: true,
        showDuration: showDuration,
        node: node,
        other: other,
      );
      await tester.pumpWidget(at(null));
      final gesture = await mouse(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpFor(tester, fade);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus arrived by a key');
      other.requestFocus();
      await pumpFor(tester, step);
      await gesture.moveTo(tester.getCenter(find.text('tip')));
      await tester.pump(step);
      await tester.pumpWidget(at(const Duration(milliseconds: 500)));
      await tester.pump(step);
      await tester.pumpWidget(at(null));
      await pumpFor(tester, bridge + fade + step);
      expect(shown(), isFalse, reason: 'the bridge still hid it');
      await gesture.moveTo(const Offset(1, 1));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(shown(), isFalse);
      expect(log, ['show', 'hide']);
    });
  });
}

class _EvictionConfig {
  bool enableFocus = true;
  bool enableHover = true;
  bool interactive = true;
  bool secondRegistry = false;
}

class _HoldConfig {
  bool enableFocus = true;
  bool enableHover = true;
  Duration? showDuration;
}
