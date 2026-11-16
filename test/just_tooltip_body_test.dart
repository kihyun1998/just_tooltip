import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
    Duration? showDuration,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            controller: controller,
            message: 'tip',
            enableHover: enableHover,
            interactive: interactive,
            showDuration: showDuration,
            animationDuration: fade,
            onShow: () => log.add('show'),
            onHide: () => log.add('hide'),
            child: const SizedBox(key: Key('child'), width: 80, height: 30),
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
}
