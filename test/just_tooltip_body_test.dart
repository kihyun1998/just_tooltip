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
}
