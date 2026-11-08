import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip torn down without animation — moved by a [GlobalKey] — starts
/// its next show from hidden, as a fresh one does.
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
}
