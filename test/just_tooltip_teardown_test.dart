import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip torn down without animation — moved by a [GlobalKey] — starts
/// its next show from hidden, as a fresh one does; one removed while shown
/// brings back the tooltips the registry hid for it.
void main() {
  const fade = Duration(milliseconds: 200);

  Future<(JustTooltipController, ValueNotifier<bool>)> pumpMovable(
    WidgetTester tester,
    List<String> log,
  ) async {
    final c = JustTooltipController();
    final key = GlobalKey();
    final left = ValueNotifier(true);
    Widget tooltip() => KeyedSubtree(
      key: key,
      child: JustTooltip(
        controller: c,
        message: 'tip',
        enableHover: false,
        animationDuration: fade,
        onShow: () => log.add('show'),
        onHide: () => log.add('hide'),
        child: const SizedBox(width: 60, height: 30),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: left,
              builder: (_, l, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 100, child: l ? tooltip() : null),
                  SizedBox(width: 100, child: l ? null : tooltip()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return (c, left);
  }

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

  testWidgets('a tooltip moved while shown fades in on its next show', (
    tester,
  ) async {
    final log = <String>[];
    final (c, left) = await pumpMovable(tester, log);
    c.show();
    await tester.pump();
    expect(opacity(tester), 0.0, reason: 'a fresh show starts hidden');
    await tester.pumpAndSettle();

    left.value = false;
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsNothing);

    c.show();
    await tester.pump();
    expect(opacity(tester), 0.0);
    await tester.pumpAndSettle();
    expect(opacity(tester), 1.0);
    expect(log, ['show', 'show']);
  });

  testWidgets('a tooltip moved while fading out fades in on its next show', (
    tester,
  ) async {
    final log = <String>[];
    final (c, left) = await pumpMovable(tester, log);
    c.show();
    await tester.pumpAndSettle();
    c.hide();
    await tester.pump();
    await tester.pump(fade ~/ 4);

    left.value = false;
    await tester.pump();
    await tester.pump();
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'the fade stopped with the teardown',
    );

    c.show();
    await tester.pump();
    expect(opacity(tester), 0.0);
    await tester.pumpAndSettle();
    expect(log, ['show', 'show']);
  });

  testWidgets('a tooltip moved after a show opens and closes by hover', (
    tester,
  ) async {
    final log = <String>[];
    final key = GlobalKey();
    final left = ValueNotifier(true);
    final c = JustTooltipController();
    Widget tooltip() => KeyedSubtree(
      key: key,
      child: JustTooltip(
        controller: c,
        message: 'tip',
        interactive: false,
        animationDuration: fade,
        onShow: () => log.add('show'),
        onHide: () => log.add('hide'),
        child: const SizedBox(key: Key('child'), width: 60, height: 30),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: left,
              builder: (_, l, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 100, child: l ? tooltip() : null),
                  SizedBox(width: 100, child: l ? null : tooltip()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    c.show();
    await tester.pumpAndSettle();
    left.value = false;
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('child'))));
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsNothing);
    expect(log, ['show', 'show', 'hide']);
  });

  group('an evicted tooltip', () {
    /// A is shown by a pointer resting on its child; B, in the same registry,
    /// is shown by its controller and evicts A. [b] stays in the tree while
    /// `present` is true. [c] is a third tooltip in the registry, never shown.
    /// With [settle] false it returns while A is still fading out.
    Future<(JustTooltipController, ValueNotifier<bool>, ValueNotifier<bool>)>
    pumpEvicted(
      WidgetTester tester,
      List<String> log, {
      bool settle = true,
    }) async {
      final b = JustTooltipController();
      final bPresent = ValueNotifier(true);
      final cPresent = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JustTooltip(
                    message: 'A',
                    animationDuration: fade,
                    onShow: () => log.add('A show'),
                    onHide: () => log.add('A hide'),
                    child: const SizedBox(
                      key: Key('a'),
                      width: 100,
                      height: 40,
                    ),
                  ),
                  const SizedBox(height: 80),
                  ValueListenableBuilder<bool>(
                    valueListenable: bPresent,
                    builder: (_, present, _) => present
                        ? JustTooltip(
                            controller: b,
                            message: 'B',
                            enableHover: false,
                            animationDuration: fade,
                            child: const SizedBox(width: 100, height: 40),
                          )
                        : const SizedBox(width: 100, height: 40),
                  ),
                  const SizedBox(height: 80),
                  ValueListenableBuilder<bool>(
                    valueListenable: cPresent,
                    builder: (_, present, _) => present
                        ? const JustTooltip(
                            message: 'C',
                            enableHover: false,
                            child: SizedBox(width: 100, height: 40),
                          )
                        : const SizedBox(width: 100, height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);

      b.show();
      if (!settle) {
        await tester.pump();
        await tester.pump(fade ~/ 4);
        expect(find.text('A'), findsOneWidget, reason: 'A is fading out');
        return (b, bPresent, cPresent);
      }
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing, reason: 'B evicted A');
      return (b, bPresent, cPresent);
    }

    testWidgets('comes back when the tooltip that took its place hides', (
      tester,
    ) async {
      final log = <String>[];
      final (b, _, _) = await pumpEvicted(tester, log);

      b.hide();
      await tester.pumpAndSettle();
      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'A hide', 'A show']);
    });

    testWidgets('comes back when the tooltip that took its place leaves '
        'the tree while shown', (tester) async {
      final log = <String>[];
      final (_, bPresent, _) = await pumpEvicted(tester, log);

      bPresent.value = false;
      await tester.pumpAndSettle();
      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'A hide', 'A show']);
    });

    testWidgets('comes back when the tooltip that took its place leaves '
        'the tree while fading out', (tester) async {
      final log = <String>[];
      final (b, bPresent, _) = await pumpEvicted(tester, log);

      b.hide();
      await tester.pump();
      await tester.pump(fade ~/ 4);
      expect(find.text('B'), findsOneWidget, reason: 'B is fading out');
      expect(find.text('A'), findsNothing);

      bPresent.value = false;
      await tester.pumpAndSettle();
      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'A hide', 'A show']);
    });

    testWidgets('comes back when the tooltip that took its place leaves '
        'the tree while it is still fading out', (tester) async {
      final log = <String>[];
      final (_, bPresent, _) = await pumpEvicted(tester, log, settle: false);

      bPresent.value = false;
      await tester.pumpAndSettle();
      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show']);
    });

    testWidgets('stays hidden when a tooltip that was not showing leaves the '
        'tree', (tester) async {
      final log = <String>[];
      final (_, _, cPresent) = await pumpEvicted(tester, log);

      cPresent.value = false;
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget, reason: 'B still holds its place');
      expect(find.text('A'), findsNothing);
      expect(log, ['A show', 'A hide']);
    });
  });
}
