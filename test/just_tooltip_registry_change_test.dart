import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip whose registry changes moves at once: it leaves the old registry
/// and joins the new one.
void main() {
  const fade = Duration(milliseconds: 200);

  Widget controlled({
    required JustTooltipController controller,
    required String message,
    required TooltipRegistry? registry,
    required List<String> log,
  }) {
    return JustTooltip(
      controller: controller,
      message: message,
      registry: registry,
      enableHover: false,
      animationDuration: fade,
      onShow: () => log.add('$message show'),
      onHide: () => log.add('$message hide'),
      child: SizedBox(key: Key(message), width: 100, height: 40),
    );
  }

  Widget hovered({
    required TooltipRegistry? registry,
    required List<String> log,
  }) {
    return JustTooltip(
      message: 'A',
      registry: registry,
      animationDuration: fade,
      onShow: () => log.add('A show'),
      onHide: () => log.add('A hide'),
      child: const SizedBox(key: Key('A'), width: 100, height: 40),
    );
  }

  Widget page(List<Widget> tooltips) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tooltip in tooltips) ...[
                tooltip,
                const SizedBox(height: 60),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
  }

  bool shown(String message) => find.text(message).evaluate().isNotEmpty;

  testWidgets('a shown tooltip given another registry is no longer dismissed '
      'by the old one', (tester) async {
    final log = <String>[];
    final r1 = TooltipRegistry();
    final r2 = TooltipRegistry();
    final t = JustTooltipController();
    final x = JustTooltipController();
    Widget build(TooltipRegistry tRegistry) => page([
      controlled(controller: t, message: 'T', registry: tRegistry, log: log),
      controlled(controller: x, message: 'X', registry: r1, log: log),
    ]);

    await tester.pumpWidget(build(r1));
    t.show();
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(r2));
    await tester.pumpAndSettle();

    x.show();
    await tester.pumpAndSettle();
    expect(shown('T'), isTrue, reason: 'T belongs to r2 now');
    expect(shown('X'), isTrue);
    expect(log, ['T show', 'X show']);
  });

  testWidgets('a shown tooltip given another registry dismisses the tooltip '
      'that held the place there', (tester) async {
    final log = <String>[];
    final r1 = TooltipRegistry();
    final r2 = TooltipRegistry();
    final t = JustTooltipController();
    final y = JustTooltipController();
    Widget build(TooltipRegistry tRegistry) => page([
      controlled(controller: t, message: 'T', registry: tRegistry, log: log),
      controlled(controller: y, message: 'Y', registry: r2, log: log),
    ]);

    await tester.pumpWidget(build(r1));
    t.show();
    y.show();
    await tester.pumpAndSettle();
    expect(log, ['T show', 'Y show']);

    await tester.pumpWidget(build(r2));
    await tester.pumpAndSettle();
    expect(shown('T'), isTrue);
    expect(shown('Y'), isFalse, reason: 'T joined r2, as a show does');
    expect(log, ['T show', 'Y show', 'Y hide']);
  });

  testWidgets('the tooltips a shown tooltip evicted come back when it is '
      'given another registry', (tester) async {
    final log = <String>[];
    final r1 = TooltipRegistry();
    final r2 = TooltipRegistry();
    final x = JustTooltipController();
    Widget build(TooltipRegistry xRegistry) => page([
      hovered(registry: r1, log: log),
      controlled(controller: x, message: 'X', registry: xRegistry, log: log),
    ]);

    await tester.pumpWidget(build(r1));
    await hover(tester, find.byKey(const Key('A')));
    x.show();
    await tester.pumpAndSettle();
    expect(shown('A'), isFalse, reason: 'X evicted A');

    await tester.pumpWidget(build(r2));
    await tester.pumpAndSettle();
    expect(shown('A'), isTrue, reason: 'X left r1, so nothing holds it');
    expect(shown('X'), isTrue);

    x.hide();
    await tester.pumpAndSettle();
    expect(shown('A'), isTrue);
    expect(log, ['A show', 'X show', 'A hide', 'A show', 'X hide']);
  });

  for (final evictedFirst in [true, false]) {
    testWidgets('a registry created in build moves its tooltips together '
        '(evicted tooltip ${evictedFirst ? 'above' : 'below'})', (
      tester,
    ) async {
      final log = <String>[];
      final x = JustTooltipController();
      final rebuild = ValueNotifier(0);
      addTearDown(rebuild.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, _) {
            final registry = TooltipRegistry();
            final a = hovered(registry: registry, log: log);
            final xTooltip = controlled(
              controller: x,
              message: 'X',
              registry: registry,
              log: log,
            );
            return page(evictedFirst ? [a, xTooltip] : [xTooltip, a]);
          },
        ),
      );
      await hover(tester, find.byKey(const Key('A')));
      x.show();
      await tester.pumpAndSettle();
      expect(shown('A'), isFalse, reason: 'X evicted A');

      rebuild.value++;
      await tester.pumpAndSettle();
      expect(shown('X'), isTrue, reason: 'X holds the place in the new one');
      expect(shown('A'), isFalse);

      x.hide();
      await tester.pumpAndSettle();
      expect(shown('A'), isTrue);
      expect(shown('X'), isFalse);
      expect(log, ['A show', 'X show', 'A hide', 'X hide', 'A show']);
    });
  }

  testWidgets('a tooltip fading out on its own hide does not join the new '
      'registry', (tester) async {
    final log = <String>[];
    final r1 = TooltipRegistry();
    final r2 = TooltipRegistry();
    final t = JustTooltipController();
    final y = JustTooltipController();
    Widget build(TooltipRegistry tRegistry) => page([
      controlled(controller: t, message: 'T', registry: tRegistry, log: log),
      controlled(controller: y, message: 'Y', registry: r2, log: log),
    ]);

    await tester.pumpWidget(build(r1));
    t.show();
    y.show();
    await tester.pumpAndSettle();
    t.hide();
    await tester.pump(fade ~/ 2);
    await tester.pumpWidget(build(r2));
    await tester.pumpAndSettle();
    expect(shown('Y'), isTrue);
    expect(shown('T'), isFalse);
    expect(log, ['T show', 'Y show', 'T hide']);
  });

  testWidgets('a shown tooltip given another registry inside a build '
      'dismisses a holder with no fade there', (tester) async {
    final log = <String>[];
    final r1 = TooltipRegistry();
    final r2 = TooltipRegistry();
    final t = JustTooltipController();
    final y = JustTooltipController();
    late StateSetter setRegistry;
    var tRegistry = r1;
    await tester.pumpWidget(
      page([
        StatefulBuilder(
          builder: (context, setState) {
            setRegistry = setState;
            return controlled(
              controller: t,
              message: 'T',
              registry: tRegistry,
              log: log,
            );
          },
        ),
        JustTooltip(
          controller: y,
          message: 'Y',
          registry: r2,
          enableHover: false,
          animation: TooltipAnimation.scale,
          animationDuration: Duration.zero,
          child: const SizedBox(width: 100, height: 40),
        ),
      ]),
    );
    t.show();
    y.show();
    await tester.pumpAndSettle();

    setRegistry(() => tRegistry = r2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(shown('T'), isTrue);
    expect(shown('Y'), isFalse);
  });

  testWidgets('a tooltip that loses its content as its registry changes does '
      'not join the new registry', (tester) async {
    final log = <String>[];
    final r1 = TooltipRegistry();
    final r2 = TooltipRegistry();
    final t = JustTooltipController();
    final y = JustTooltipController();
    Widget build(TooltipRegistry tRegistry, String message) => page([
      JustTooltip(
        controller: t,
        message: message,
        registry: tRegistry,
        enableHover: false,
        animationDuration: fade,
        child: const SizedBox(width: 100, height: 40),
      ),
      controlled(controller: y, message: 'Y', registry: r2, log: log),
    ]);

    await tester.pumpWidget(build(r1, 'T'));
    t.show();
    y.show();
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(r2, ''));
    await tester.pumpAndSettle();
    expect(shown('Y'), isTrue);
    expect(log, ['Y show']);
  });

  group('an evicted tooltip given another registry', () {
    testWidgets('comes back at once when no tooltip holds the place there', (
      tester,
    ) async {
      final log = <String>[];
      final r1 = TooltipRegistry();
      final r2 = TooltipRegistry();
      final x = JustTooltipController();
      Widget build(TooltipRegistry aRegistry) => page([
        hovered(registry: aRegistry, log: log),
        controlled(controller: x, message: 'X', registry: r1, log: log),
      ]);

      await tester.pumpWidget(build(r1));
      await hover(tester, find.byKey(const Key('A')));
      x.show();
      await tester.pumpAndSettle();
      expect(shown('A'), isFalse, reason: 'X evicted A');

      await tester.pumpWidget(build(r2));
      await tester.pumpAndSettle();
      expect(shown('A'), isTrue);
      expect(shown('X'), isTrue, reason: 'A no longer shares a place with X');
    });

    testWidgets('waits for the tooltip holding the place there, not for the '
        'old one', (tester) async {
      final log = <String>[];
      final r1 = TooltipRegistry();
      final r2 = TooltipRegistry();
      final x = JustTooltipController();
      final y = JustTooltipController();
      Widget build(TooltipRegistry aRegistry) => page([
        hovered(registry: aRegistry, log: log),
        controlled(controller: x, message: 'X', registry: r1, log: log),
        controlled(controller: y, message: 'Y', registry: r2, log: log),
      ]);

      await tester.pumpWidget(build(r1));
      await hover(tester, find.byKey(const Key('A')));
      x.show();
      y.show();
      await tester.pumpAndSettle();
      expect(shown('A'), isFalse, reason: 'X evicted A');

      await tester.pumpWidget(build(r2));
      await tester.pumpAndSettle();
      expect(shown('A'), isFalse, reason: 'Y holds the place in r2');

      x.hide();
      await tester.pumpAndSettle();
      expect(shown('A'), isFalse, reason: 'A left r1');
      expect(shown('Y'), isTrue);

      y.hide();
      await tester.pumpAndSettle();
      expect(shown('A'), isTrue);
    });
  });

  group('inside a tooltip content', () {
    final hostBody = find.byKey(const Key('hostBody'));

    Widget hostApp({
      required JustTooltipController host,
      required Widget content,
      required Widget other,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              JustTooltip(
                controller: host,
                enableHover: false,
                direction: TooltipDirection.bottom,
                tooltipBuilder: (_) => SizedBox(
                  key: const Key('hostBody'),
                  width: 300,
                  height: 100,
                  child: content,
                ),
                child: const SizedBox(width: 80, height: 30),
              ),
              const SizedBox(height: 300),
              other,
            ],
          ),
        ),
      );
    }

    testWidgets('a shown tooltip whose registry falls back to the content '
        'registry joins it', (tester) async {
      final log = <String>[];
      final r1 = TooltipRegistry();
      final host = JustTooltipController();
      final t = JustTooltipController();
      final c = JustTooltipController();
      final x = JustTooltipController();
      Widget build(TooltipRegistry? tRegistry) => hostApp(
        host: host,
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            controlled(
              controller: t,
              message: 'T',
              registry: tRegistry,
              log: log,
            ),
            controlled(controller: c, message: 'C', registry: null, log: log),
          ],
        ),
        other: controlled(controller: x, message: 'X', registry: r1, log: log),
      );

      await tester.pumpWidget(build(r1));
      host.show();
      await tester.pumpAndSettle();
      t.show();
      c.show();
      await tester.pumpAndSettle();
      expect(shown('T') && shown('C'), isTrue, reason: 'two registries');

      await tester.pumpWidget(build(null));
      await tester.pumpAndSettle();
      expect(shown('T'), isTrue);
      expect(shown('C'), isFalse, reason: 'T joined the content registry');

      x.show();
      await tester.pumpAndSettle();
      expect(shown('T'), isTrue, reason: 'T left r1');
      expect(hostBody, findsOneWidget);
    });

    testWidgets('a tooltip moved into the content by a GlobalKey shows in '
        'the content registry', (tester) async {
      final log = <String>[];
      final key = GlobalKey();
      final host = JustTooltipController();
      final t = JustTooltipController();
      final c = JustTooltipController();
      // The same widget instance in both places.
      final tooltipWidget = KeyedSubtree(
        key: key,
        child: controlled(
          controller: t,
          message: 'T',
          registry: null,
          log: log,
        ),
      );
      Widget tooltipT() => tooltipWidget;
      Widget build({required bool inContent}) => hostApp(
        host: host,
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (inContent) tooltipT(),
            controlled(controller: c, message: 'C', registry: null, log: log),
          ],
        ),
        other: inContent ? const SizedBox() : tooltipT(),
      );

      await tester.pumpWidget(build(inContent: false));
      host.show();
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(inContent: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('T')), findsOneWidget);

      c.show();
      await tester.pumpAndSettle();
      t.show();
      await tester.pumpAndSettle();
      expect(shown('T'), isTrue);
      expect(shown('C'), isFalse, reason: 'T is in the content registry');
      expect(hostBody, findsOneWidget, reason: 'T left the shared registry');
    });
  });
}
