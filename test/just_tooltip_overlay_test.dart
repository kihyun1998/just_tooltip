import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:just_tooltip/src/just_tooltip_overlay.dart';

void main() {
  testWidgets('non-arrow overlay with a border renders a bordered DecoratedBox',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltipOverlay(
              direction: TooltipDirection.top,
              alignment: TooltipAlignment.center,
              theme: JustTooltipTheme(
                showArrow: false,
                borderColor: Color(0xFFFF0000),
                borderWidth: 1,
              ),
              message: 'x',
            ),
          ),
        ),
      ),
    );

    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(JustTooltipOverlay),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNotNull,
        reason: 'border theme takes the DecoratedBox path');
  });

  testWidgets('a bare theme adds no surface around the builder\'s widget',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltipOverlay(
              direction: TooltipDirection.top,
              alignment: TooltipAlignment.center,
              theme: const JustTooltipTheme.bare(),
              tooltipBuilder: (_) => const SizedBox(
                key: ValueKey('card'),
                width: 100,
                height: 40,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(JustTooltipOverlay),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
      reason: 'no boxShadow and no border means no DecoratedBox path',
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(JustTooltipOverlay),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color?.a, 0, reason: 'the surface is fully transparent');
    expect(material.elevation, 0.0, reason: 'the surface casts no shadow');

    // The builder's widget keeps its own size: the tooltip adds no padding.
    expect(tester.getSize(find.byKey(const ValueKey('card'))),
        const Size(100, 40));
    expect(
      tester.getSize(find.byType(JustTooltipOverlay)),
      const Size(100, 40),
      reason: 'the overlay is exactly the card, with nothing around it',
    );
  });

  testWidgets('a bare theme survives the JustTooltip hover path',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              theme: const JustTooltipTheme.bare(),
              tooltipBuilder: (_) => const SizedBox(
                key: ValueKey('card'),
                width: 100,
                height: 40,
              ),
              child: const SizedBox(key: Key('target'), width: 80, height: 30),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('card')), findsOneWidget,
        reason: 'the tooltip showed');

    // The theme reaches the overlay intact: the card is still the whole of it.
    expect(
      tester.getSize(find.byType(JustTooltipOverlay)),
      const Size(100, 40),
    );
  });
}
