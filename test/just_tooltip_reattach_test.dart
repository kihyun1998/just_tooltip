import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A controller belongs to the tooltip State that is in the tree: one that has
/// left it — replaced in the same frame, or moved by a [GlobalKey] — lets go,
/// and one that comes back takes the controller again.
void main() {
  Widget tooltip(JustTooltipController controller, {Key? key}) => JustTooltip(
    key: key,
    controller: controller,
    message: 'tip',
    enableHover: false,
    child: const SizedBox(width: 60, height: 30),
  );

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a parent key change rebuilds the tooltip with its controller', (
    tester,
  ) async {
    final c = JustTooltipController();
    final key = ValueNotifier(0);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<int>(
          valueListenable: key,
          builder: (_, k, _) =>
              KeyedSubtree(key: ValueKey(k), child: tooltip(c)),
        ),
      ),
    );

    key.value = 1;
    await tester.pump();
    expect(tester.takeException(), isNull);

    c.show();
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);
    expect(c.isShowing, isTrue);
  });

  testWidgets('a wrapper added above the tooltip keeps its controller', (
    tester,
  ) async {
    final c = JustTooltipController();
    final wrap = ValueNotifier(false);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: wrap,
          builder: (_, on, _) => on
              ? Padding(padding: const EdgeInsets.all(8), child: tooltip(c))
              : tooltip(c),
        ),
      ),
    );

    wrap.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);

    c.show();
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);
  });

  testWidgets('a tooltip moved by a GlobalKey keeps its controller', (
    tester,
  ) async {
    final c = JustTooltipController();
    final key = GlobalKey();
    final left = ValueNotifier(true);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: left,
          builder: (_, l, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 100, child: l ? tooltip(c, key: key) : null),
              SizedBox(width: 100, child: l ? null : tooltip(c, key: key)),
            ],
          ),
        ),
      ),
    );

    left.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);

    c.show();
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);
    expect(c.isShowing, isTrue);
  });

  testWidgets('a removed tooltip lets go of its controller', (tester) async {
    final c = JustTooltipController();
    final shown = ValueNotifier(true);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (_, on, _) => on ? tooltip(c) : const SizedBox(),
        ),
      ),
    );
    c.show();
    await tester.pumpAndSettle();
    expect(c.isShowing, isTrue);

    shown.value = false;
    await tester.pumpAndSettle();
    expect(c.isShowing, isFalse);

    // A queued show waits for the next tooltip.
    c.show();
    shown.value = true;
    await tester.pumpAndSettle();
    expect(find.text('tip'), findsOneWidget);
  });
}
