import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip the registry hid for another one, while its trigger is still
/// inside, comes back only once no tooltip in its own registry holds the
/// place.
void main() {
  const fade = Duration(milliseconds: 200);

  Widget controlled({
    required JustTooltipController controller,
    required String message,
    required TooltipRegistry registry,
    required List<String> log,
    Duration animationDuration = fade,
  }) {
    return JustTooltip(
      controller: controller,
      message: message,
      registry: registry,
      enableHover: false,
      animationDuration: animationDuration,
      onShow: () => log.add('$message show'),
      onHide: () => log.add('$message hide'),
      child: const SizedBox(width: 100, height: 40),
    );
  }

  /// Pumps A — shown by a pointer resting on its child — above [others], and
  /// returns once A is shown.
  Future<void> pumpHovered(
    WidgetTester tester, {
    required TooltipRegistry registry,
    required List<String> log,
    required List<Widget> others,
  }) async {
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
                  animationDuration: fade,
                  onShow: () => log.add('A show'),
                  onHide: () => log.add('A hide'),
                  child: const SizedBox(key: Key('a'), width: 100, height: 40),
                ),
                for (final other in others) ...[
                  const SizedBox(height: 60),
                  other,
                ],
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
  }

  testWidgets('stays hidden when the tooltip that took its place is itself '
      'evicted, and comes back when the last one hides', (tester) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final d = JustTooltipController();
    final b = JustTooltipController();
    await pumpHovered(
      tester,
      registry: registry,
      log: log,
      others: [
        controlled(controller: d, message: 'D', registry: registry, log: log),
        controlled(controller: b, message: 'B', registry: registry, log: log),
      ],
    );

    d.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'D evicted A');

    b.show();
    await tester.pumpAndSettle();
    expect(find.text('D'), findsNothing, reason: 'B evicted D');
    expect(find.text('B'), findsOneWidget, reason: 'B still holds the place');
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'D show', 'A hide', 'B show', 'D hide']);

    b.hide();
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(find.text('D'), findsNothing, reason: 'no trigger inside D');
    expect(find.text('A'), findsOneWidget);
    expect(log, [
      'A show',
      'D show',
      'A hide',
      'B show',
      'D hide',
      'B hide',
      'A show',
    ]);
  });

  testWidgets('stays hidden when the tooltip that took its place is evicted '
      'with no fade', (tester) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final d = JustTooltipController();
    final b = JustTooltipController();
    await pumpHovered(
      tester,
      registry: registry,
      log: log,
      others: [
        controlled(
          controller: d,
          message: 'D',
          registry: registry,
          log: log,
          animationDuration: Duration.zero,
        ),
        controlled(controller: b, message: 'B', registry: registry, log: log),
      ],
    );

    d.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'D evicted A');

    b.show();
    await tester.pumpAndSettle();
    expect(find.text('D'), findsNothing, reason: 'B evicted D');
    expect(find.text('B'), findsOneWidget, reason: 'B still holds the place');
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'D show', 'A hide', 'D hide', 'B show']);
  });

  testWidgets('stays hidden when a show ends in another registry', (
    tester,
  ) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final other = TooltipRegistry();
    final b = JustTooltipController();
    final c = JustTooltipController();
    await pumpHovered(
      tester,
      registry: registry,
      log: log,
      others: [
        controlled(controller: b, message: 'B', registry: registry, log: log),
        controlled(controller: c, message: 'C', registry: other, log: log),
      ],
    );

    b.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'B evicted A');

    c.show();
    await tester.pumpAndSettle();
    c.hide();
    await tester.pumpAndSettle();
    expect(find.text('C'), findsNothing);
    expect(find.text('B'), findsOneWidget, reason: 'B still holds the place');
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'B show', 'A hide', 'C show', 'C hide']);

    b.hide();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(log, [
      'A show',
      'B show',
      'A hide',
      'C show',
      'C hide',
      'B hide',
      'A show',
    ]);
  });
}
