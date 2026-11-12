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
}
