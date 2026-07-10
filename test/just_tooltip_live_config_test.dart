import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A shown tooltip must follow its own widget's configuration. The overlay
/// entry renders `widget.message`, `widget.tooltipBuilder` and `widget.theme`
/// live, so it only ever needs to be asked to rebuild.
void main() {
  Future<void> hover(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
    await tester.pumpAndSettle();
  }

  const target = SizedBox(key: Key('target'), width: 100, height: 50);

  testWidgets('a shown tooltip picks up a new message', (tester) async {
    final message = ValueNotifier('FIRST');
    addTearDown(message.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: message,
              builder: (context, value, _) =>
                  JustTooltip(message: value, child: target),
            ),
          ),
        ),
      ),
    );

    await hover(tester);
    expect(find.text('FIRST'), findsOneWidget);

    message.value = 'SECOND';
    await tester.pumpAndSettle();

    expect(find.text('SECOND'), findsOneWidget);
    expect(find.text('FIRST'), findsNothing);
  });

  testWidgets('a shown tooltip picks up new tooltipBuilder content',
      (tester) async {
    final label = ValueNotifier('FIRST');
    addTearDown(label.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: label,
              builder: (context, value, _) {
                // Captured, not read live. A closure that reads mutable state
                // at call time hides this bug: the stale closure returns the
                // new value, so the tooltip appears to update even when the
                // overlay was never rebuilt. See #47.
                final snapshot = value;
                return JustTooltip(
                  tooltipBuilder: (_) => Text(snapshot),
                  child: target,
                );
              },
            ),
          ),
        ),
      ),
    );

    await hover(tester);
    expect(find.text('FIRST'), findsOneWidget);

    label.value = 'SECOND';
    await tester.pumpAndSettle();

    expect(find.text('SECOND'), findsOneWidget);
    expect(find.text('FIRST'), findsNothing);
  });

  testWidgets('a controller-shown tooltip drops an emptied message',
      (tester) async {
    // No pointer anywhere, so hover intent is false throughout and the
    // reconcile that hides on content loss returns early. Showing is gated on
    // content; hiding must be too, or the rebuilt overlay draws an empty
    // bubble that `hideOnEmptyMessage` says should not exist.
    final controller = JustTooltipController();
    final message = ValueNotifier('FIRST');
    addTearDown(message.dispose);
    var hidden = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: message,
              builder: (context, value, _) => JustTooltip(
                controller: controller,
                message: value,
                onHide: () => hidden++,
                child: target,
              ),
            ),
          ),
        ),
      ),
    );

    controller.show();
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsOneWidget);

    message.value = '';
    await tester.pumpAndSettle();

    expect(find.text(''), findsNothing,
        reason: 'an emptied tooltip must not linger as an empty bubble');
    expect(controller.isShowing, isFalse,
        reason: 'the overlay is gone, not merely blank');
    expect(hidden, 1, reason: 'it hid once, through the normal hide path');
  });

  testWidgets('a shown tooltip picks up a new theme', (tester) async {
    final color = ValueNotifier(Colors.red);
    addTearDown(color.dispose);

    Color? shownColor(WidgetTester tester) {
      final material = tester.widgetList<Material>(find.byType(Material));
      return material
          .where((m) => m.color == Colors.red || m.color == Colors.green)
          .firstOrNull
          ?.color;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<Color>(
              valueListenable: color,
              builder: (context, value, _) => JustTooltip(
                message: 'MSG',
                theme: JustTooltipTheme(backgroundColor: value),
                child: target,
              ),
            ),
          ),
        ),
      ),
    );

    await hover(tester);
    expect(shownColor(tester), Colors.red);

    color.value = Colors.green;
    await tester.pumpAndSettle();

    expect(shownColor(tester), Colors.green,
        reason: 'the overlay renders widget.theme, so it must be rebuilt');
  });
}
