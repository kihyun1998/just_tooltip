import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

void main() {
  group('JustTooltip hover', () {
    Widget hoverApp({
      Duration? waitDuration,
      Duration? showDuration,
      bool interactive = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: 'Hover',
              waitDuration: waitDuration,
              showDuration: showDuration,
              interactive: interactive,
              child: const SizedBox(key: Key('target'), width: 80, height: 30),
            ),
          ),
        ),
      );
    }

    Future<TestGesture> hoverOverTarget(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
      return gesture;
    }

    testWidgets('hovering the child shows the tooltip', (tester) async {
      await tester.pumpWidget(hoverApp());

      await hoverOverTarget(tester);
      await tester.pumpAndSettle();

      expect(find.text('Hover'), findsOneWidget);
    });

    testWidgets('moving the cursor away hides after the bridge delay',
        (tester) async {
      await tester.pumpWidget(hoverApp());
      final gesture = await hoverOverTarget(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsOneWidget);

      await gesture.moveTo(const Offset(600, 550)); // off the child
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Hover'), findsOneWidget,
          reason: 'still within the 100ms hover bridge');

      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsNothing);
    });

    testWidgets('waitDuration delays the hover show', (tester) async {
      await tester.pumpWidget(
        hoverApp(waitDuration: const Duration(milliseconds: 300)),
      );

      await hoverOverTarget(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hover'), findsNothing, reason: 'before waitDuration');

      await tester.pump(const Duration(milliseconds: 250)); // past 300 total
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsOneWidget);
    });

    testWidgets('showDuration auto-hides while still hovering', (tester) async {
      await tester.pumpWidget(
        hoverApp(showDuration: const Duration(seconds: 1)),
      );

      await hoverOverTarget(tester);
      await tester.pump(); // trigger show
      await tester.pump(const Duration(milliseconds: 200)); // finish show anim
      expect(find.text('Hover'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000)); // reach auto-hide
      await tester.pump(const Duration(milliseconds: 200)); // finish hide anim
      expect(find.text('Hover'), findsNothing);
    });

    testWidgets('re-hovering during fade-out keeps the tooltip (reverse-catch)',
        (tester) async {
      await tester.pumpWidget(hoverApp());
      final gesture = await hoverOverTarget(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsOneWidget);

      // Leave: bridge (100ms) then the fade-out begins.
      await gesture.moveTo(const Offset(600, 550));
      await tester
          .pump(const Duration(milliseconds: 160)); // bridge + into fade

      // Return to the child mid-fade — should catch and re-show.
      await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
      await tester.pumpAndSettle();

      expect(find.text('Hover'), findsOneWidget,
          reason: 'cursor returned before the tooltip finished hiding');
    });
  });
}
