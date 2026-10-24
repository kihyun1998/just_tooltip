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

    testWidgets('moving the cursor away hides after the bridge delay', (
      tester,
    ) async {
      await tester.pumpWidget(hoverApp());
      final gesture = await hoverOverTarget(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsOneWidget);

      await gesture.moveTo(const Offset(600, 550)); // off the child
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text('Hover'),
        findsOneWidget,
        reason: 'still within the 100ms hover bridge',
      );

      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsNothing);
    });

    testWidgets('moving the cursor onto an interactive tooltip keeps it open', (
      tester,
    ) async {
      await tester.pumpWidget(hoverApp());
      final gesture = await hoverOverTarget(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsOneWidget);

      // Leaving the child arms the hover bridge; reaching the tooltip body
      // must cancel it. Settle, or a tooltip that has merely *begun* its
      // fade-out still reads as present.
      await gesture.moveTo(tester.getCenter(find.text('Hover')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        find.text('Hover'),
        findsOneWidget,
        reason: 'the cursor is on the tooltip, well past the 100ms bridge',
      );
    });

    testWidgets('returning from the tooltip to the child keeps it open', (
      tester,
    ) async {
      await tester.pumpWidget(hoverApp());
      final gesture = await hoverOverTarget(tester);
      await tester.pumpAndSettle();

      await gesture.moveTo(tester.getCenter(find.text('Hover')));
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsOneWidget);

      // Back onto the child. Leaving the tooltip arms the bridge again, and
      // re-entering the child must cancel it -- there is nothing to bridge to
      // when the pointer is already home. Otherwise it fires unseen, and the
      // fade-out that follows can never be revived: the pointer never leaves
      // the child, so no further onEnter arrives.
      await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.text('Hover'),
        findsOneWidget,
        reason: 'the bridge deadline passed while the cursor was home',
      );

      await tester.pumpAndSettle();
      expect(
        find.text('Hover'),
        findsOneWidget,
        reason: 'and no fade-out was left running to remove it',
      );
    });

    testWidgets('a non-interactive tooltip hides even under the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(hoverApp(interactive: false));
      final gesture = await hoverOverTarget(tester);
      await tester.pumpAndSettle();
      final tooltipCentre = tester.getCenter(find.text('Hover'));

      await gesture.moveTo(tooltipCentre);
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsNothing);
    });

    testWidgets(
      'a non-interactive tooltip clamped over the pointer stays shown (#65)',
      (tester) async {
        // A 300-wide body fits on neither side of the target in a 390-wide
        // view, so the clamp lays it over the target and the pointer.
        tester.view.physicalSize = const Size(390, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 100,
                    top: 90,
                    child: JustTooltip(
                      direction: TooltipDirection.left,
                      interactive: false,
                      tooltipBuilder: (_) => const SizedBox(
                        key: Key('body'),
                        width: 300,
                        height: 120,
                      ),
                      child: const SizedBox(
                        key: Key('target'),
                        width: 76,
                        height: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await hoverOverTarget(tester);
        var samples = '';
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          samples += find.byKey(const Key('body')).evaluate().isEmpty
              ? '-'
              : 'T';
        }

        expect(samples, 'T' * 20);
        expect(
          tester
              .getRect(find.byKey(const Key('body')))
              .contains(tester.getCenter(find.byKey(const Key('target')))),
          isTrue,
          reason: 'the body covers the pointer',
        );
      },
    );

    for (final interactive in [false, true]) {
      testWidgets(
        interactive
            ? 'a tap on an interactive tooltip stops at it'
            : 'a tap on a non-interactive tooltip reaches what lies beneath it',
        (tester) async {
          var beneath = 0;
          final controller = JustTooltipController();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(onTap: () => beneath++),
                    ),
                    Positioned(
                      left: 100,
                      top: 300,
                      child: JustTooltip(
                        controller: controller,
                        enableHover: false,
                        interactive: interactive,
                        tooltipBuilder: (_) => const SizedBox(
                          key: Key('body'),
                          width: 200,
                          height: 80,
                        ),
                        child: const SizedBox(width: 50, height: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          controller.show();
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('body')), warnIfMissed: false);
          await tester.pumpAndSettle();

          expect(beneath, interactive ? 0 : 1);
        },
      );
    }

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

    testWidgets(
      're-hovering during fade-out keeps the tooltip (reverse-catch)',
      (tester) async {
        await tester.pumpWidget(hoverApp());
        final gesture = await hoverOverTarget(tester);
        await tester.pumpAndSettle();
        expect(find.text('Hover'), findsOneWidget);

        // Leave: bridge (100ms) then the fade-out begins.
        await gesture.moveTo(const Offset(600, 550));
        await tester.pump(
          const Duration(milliseconds: 160),
        ); // bridge + into fade

        // Return to the child mid-fade — should catch and re-show.
        await gesture.moveTo(tester.getCenter(find.byKey(const Key('target'))));
        await tester.pumpAndSettle();

        expect(
          find.text('Hover'),
          findsOneWidget,
          reason: 'cursor returned before the tooltip finished hiding',
        );
      },
    );

    testWidgets(
      'losing its message drops a lone tooltip past its showDuration',
      (tester) async {
        // No ancestor and no sibling, so nothing else can take the screen: the
        // registry cannot dismiss this one on another tooltip's behalf. Losing
        // content must bypass the scheduler's hide policy exactly as suppression
        // does, or a `showDuration` tooltip keeps a message it no longer has.
        final message = ValueNotifier('Hover');
        addTearDown(message.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ValueListenableBuilder<String>(
                  valueListenable: message,
                  builder: (context, value, _) => JustTooltip(
                    message: value,
                    showDuration: const Duration(seconds: 10),
                    child: const SizedBox(
                      key: Key('target'),
                      width: 100,
                      height: 50,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await hoverOverTarget(tester);
        await tester.pumpAndSettle();
        expect(find.text('Hover'), findsOneWidget);

        message.value = '';
        await tester.pumpAndSettle();

        expect(
          find.text('Hover'),
          findsNothing,
          reason: 'a tooltip with nothing to say must not keep saying it',
        );
      },
    );
  });
}
