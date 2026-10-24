import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip inside another tooltip's content shares a registry with the
/// other tooltips in that content, not with its host (#84).
void main() {
  /// A host tooltip whose content is [content], and an unrelated tooltip
  /// further down the page.
  Widget hostApp({
    required JustTooltipController host,
    required Widget content,
    bool hostHover = false,
    TooltipRegistry? hostRegistry,
    JustTooltipController? other,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            JustTooltip(
              controller: host,
              enableHover: hostHover,
              registry: hostRegistry,
              direction: TooltipDirection.bottom,
              tooltipBuilder: (_) => SizedBox(
                key: const Key('hostBody'),
                width: 300,
                height: 100,
                child: content,
              ),
              child: const SizedBox(key: Key('host'), width: 80, height: 30),
            ),
            const SizedBox(height: 300),
            JustTooltip(
              controller: other,
              enableHover: false,
              message: 'other',
              child: const SizedBox(width: 40, height: 20),
            ),
          ],
        ),
      ),
    );
  }

  final hostBody = find.byKey(const Key('hostBody'));

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    return gesture;
  }

  for (final hostHover in [false, true]) {
    testWidgets(
        'hovering a tooltip in the content keeps its host '
        '(host shown by ${hostHover ? 'hover' : 'its controller'})',
        (tester) async {
      final host = JustTooltipController();
      await tester.pumpWidget(hostApp(
        host: host,
        hostHover: hostHover,
        content: Center(
          child: JustTooltip(
            message: 'inner',
            child: const SizedBox(key: Key('inner'), width: 60, height: 20),
          ),
        ),
      ));
      final gesture = await mouse(tester);
      if (hostHover) {
        await gesture.moveTo(tester.getCenter(find.byKey(const Key('host'))));
      } else {
        host.show();
      }
      await tester.pumpAndSettle();

      await gesture.moveTo(tester.getCenter(hostBody) + const Offset(0, 30));
      await tester.pumpAndSettle();
      await gesture.moveTo(tester.getCenter(find.byKey(const Key('inner'))));
      await tester.pumpAndSettle();

      expect(find.text('inner'), findsOneWidget);
      expect(hostBody, findsOneWidget);
    });
  }

  testWidgets('a touch tap on a tooltip in the content keeps its host',
      (tester) async {
    final host = JustTooltipController();
    await tester.pumpWidget(hostApp(
      host: host,
      content: Center(
        child: JustTooltip(
          message: 'inner',
          tap: TooltipTap.claim,
          enableHover: false,
          child: const SizedBox(key: Key('inner'), width: 60, height: 20),
        ),
      ),
    ));
    host.show();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inner')));
    await tester.pumpAndSettle();

    expect(find.text('inner'), findsOneWidget);
    expect(hostBody, findsOneWidget);
  });

  testWidgets('a tooltip nested inside a content tooltip keeps the host',
      (tester) async {
    final host = JustTooltipController();
    await tester.pumpWidget(hostApp(
      host: host,
      content: Center(
        child: JustTooltip(
          message: 'middle',
          enableHover: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: JustTooltip(
              message: 'deep',
              tap: TooltipTap.claim,
              enableHover: false,
              child: const SizedBox(key: Key('deep'), width: 60, height: 20),
            ),
          ),
        ),
      ),
    ));
    host.show();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deep')));
    await tester.pumpAndSettle();

    expect(find.text('deep'), findsOneWidget);
    expect(hostBody, findsOneWidget);
  });

  testWidgets('tooltips in the same content are still one at a time',
      (tester) async {
    final host = JustTooltipController();
    await tester.pumpWidget(hostApp(
      host: host,
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final name in ['A', 'B'])
            JustTooltip(
              message: name,
              tap: TooltipTap.claim,
              enableHover: false,
              child: SizedBox(key: Key(name), width: 60, height: 20),
            ),
        ],
      ),
    ));
    host.show();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('A')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('B')));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(hostBody, findsOneWidget);
  });

  testWidgets('another tooltip showing still dismisses the host',
      (tester) async {
    final host = JustTooltipController();
    final other = JustTooltipController();
    await tester.pumpWidget(hostApp(
      host: host,
      other: other,
      content: Center(
        child: JustTooltip(
          message: 'inner',
          tap: TooltipTap.claim,
          enableHover: false,
          child: const SizedBox(key: Key('inner'), width: 60, height: 20),
        ),
      ),
    ));
    host.show();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inner')));
    await tester.pumpAndSettle();

    other.show();
    await tester.pumpAndSettle();

    expect(find.text('other'), findsOneWidget);
    expect(hostBody, findsNothing);
    expect(find.text('inner'), findsNothing);
  });

  testWidgets('an explicit registry on a content tooltip is still used',
      (tester) async {
    final host = JustTooltipController();
    final registry = TooltipRegistry();
    await tester.pumpWidget(hostApp(
      host: host,
      hostRegistry: registry,
      content: Center(
        child: JustTooltip(
          message: 'inner',
          tap: TooltipTap.claim,
          enableHover: false,
          registry: registry,
          child: const SizedBox(key: Key('inner'), width: 60, height: 20),
        ),
      ),
    ));
    host.show();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inner')));
    await tester.pumpAndSettle();

    expect(hostBody, findsNothing,
        reason: 'host and inner share the registry they were given');
  });
}
