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
}
