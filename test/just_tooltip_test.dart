import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:just_tooltip/just_tooltip.dart';

// =============================================================================
// JustTooltipController tests
// =============================================================================
void main() {
  group('JustTooltipController', () {
    test('initial state is hidden', () {
      final controller = JustTooltipController();
      expect(controller.shouldShow, isFalse);
    });

    test('show() sets shouldShow to true', () {
      final controller = JustTooltipController();
      controller.show();
      expect(controller.shouldShow, isTrue);
    });

    test('hide() sets shouldShow to false', () {
      final controller = JustTooltipController();
      controller.show();
      controller.hide();
      expect(controller.shouldShow, isFalse);
    });

    test('toggle() flips shouldShow', () {
      final controller = JustTooltipController();
      controller.toggle();
      expect(controller.shouldShow, isTrue);
      controller.toggle();
      expect(controller.shouldShow, isFalse);
    });

    test('notifies listeners on show/hide/toggle', () {
      final controller = JustTooltipController();
      var callCount = 0;
      controller.addListener(() => callCount++);

      controller.show();
      expect(callCount, 1);

      controller.hide();
      expect(callCount, 2);

      controller.toggle();
      expect(callCount, 3);
    });

    test('show() when already shown does not notify', () {
      final controller = JustTooltipController();
      controller.show();
      var callCount = 0;
      controller.addListener(() => callCount++);
      controller.show();
      expect(callCount, 0);
    });

    test('hide() when already hidden does not notify', () {
      final controller = JustTooltipController();
      var callCount = 0;
      controller.addListener(() => callCount++);
      controller.hide();
      expect(callCount, 0);
    });
  });

  // ===========================================================================
  // JustTooltipPositionDelegate tests
  // ===========================================================================
  group('JustTooltipPositionDelegate', () {
    // Viewport: 800x600, target centered at (350,280) size 100x40.
    const viewportSize = Size(800, 600);
    final centerTarget = const Offset(350, 280) & const Size(100, 40);
    const gap = 8.0;
    const margin = 8.0;

    Offset position({
      required TooltipDirection direction,
      TooltipAlignment alignment = TooltipAlignment.center,
      double crossAxisOffset = 0,
      double screenMargin = margin,
      TextDirection textDirection = TextDirection.ltr,
      Rect? target,
      Size childSize = const Size(120, 30),
    }) {
      final delegate = JustTooltipPositionDelegate(
        targetRect: target ?? centerTarget,
        direction: direction,
        alignment: alignment,
        gap: gap,
        crossAxisOffset: crossAxisOffset,
        screenMargin: screenMargin,
        textDirection: textDirection,
      );
      return delegate.getPositionForChild(viewportSize, childSize);
    }

    // ---- basic positioning (centered target, no overflow) ----

    group('basic positioning', () {
      test('top + center', () {
        final pos = position(direction: TooltipDirection.top);
        // x: target.center.dx - childWidth/2 = 400 - 60 = 340
        // y: target.top - gap - childHeight = 280 - 8 - 30 = 242
        expect(pos, const Offset(340, 242));
      });

      test('top + start', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.start,
        );
        // x: target.left = 350
        // y: 280 - 8 - 30 = 242
        expect(pos, const Offset(350, 242));
      });

      test('top + end', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.end,
        );
        // x: target.right - childWidth = 450 - 120 = 330
        // y: 242
        expect(pos, const Offset(330, 242));
      });

      test('bottom + center', () {
        final pos = position(direction: TooltipDirection.bottom);
        // x: 340
        // y: target.bottom + gap = 320 + 8 = 328
        expect(pos, const Offset(340, 328));
      });

      test('bottom + start', () {
        final pos = position(
          direction: TooltipDirection.bottom,
          alignment: TooltipAlignment.start,
        );
        expect(pos, const Offset(350, 328));
      });

      test('bottom + end', () {
        final pos = position(
          direction: TooltipDirection.bottom,
          alignment: TooltipAlignment.end,
        );
        expect(pos, const Offset(330, 328));
      });

      test('left + center', () {
        final pos = position(direction: TooltipDirection.left);
        // x: target.left - gap - childWidth = 350 - 8 - 120 = 222
        // y: target.center.dy - childHeight/2 = 300 - 15 = 285
        expect(pos, const Offset(222, 285));
      });

      test('left + start', () {
        final pos = position(
          direction: TooltipDirection.left,
          alignment: TooltipAlignment.start,
        );
        // x: 222
        // y: target.top = 280
        expect(pos, const Offset(222, 280));
      });

      test('left + end', () {
        final pos = position(
          direction: TooltipDirection.left,
          alignment: TooltipAlignment.end,
        );
        // x: 222
        // y: target.bottom - childHeight = 320 - 30 = 290
        expect(pos, const Offset(222, 290));
      });

      test('right + center', () {
        final pos = position(direction: TooltipDirection.right);
        // x: target.right + gap = 450 + 8 = 458
        // y: 285
        expect(pos, const Offset(458, 285));
      });

      test('right + start', () {
        final pos = position(
          direction: TooltipDirection.right,
          alignment: TooltipAlignment.start,
        );
        expect(pos, const Offset(458, 280));
      });

      test('right + end', () {
        final pos = position(
          direction: TooltipDirection.right,
          alignment: TooltipAlignment.end,
        );
        expect(pos, const Offset(458, 290));
      });
    });

    // ---- RTL ----

    group('RTL', () {
      test('top + start with RTL resolves to end', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.start,
          textDirection: TextDirection.rtl,
        );
        // RTL swaps start→end: x = target.right - childWidth = 450 - 120 = 330
        expect(pos, const Offset(330, 242));
      });

      test('top + end with RTL resolves to start', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.end,
          textDirection: TextDirection.rtl,
        );
        // RTL swaps end→start: x = target.left = 350
        expect(pos, const Offset(350, 242));
      });

      test('top + center with RTL stays center', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          textDirection: TextDirection.rtl,
        );
        expect(pos, const Offset(340, 242));
      });

      test('left + start with RTL is not affected', () {
        final pos = position(
          direction: TooltipDirection.left,
          alignment: TooltipAlignment.start,
          textDirection: TextDirection.rtl,
        );
        // left/right directions are not affected by RTL.
        expect(pos, const Offset(222, 280));
      });
    });

    // ---- crossAxisOffset ----

    group('crossAxisOffset', () {
      test('top + start with crossAxisOffset shifts right', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.start,
          crossAxisOffset: 10,
        );
        // x: target.left + 10 = 360
        expect(pos, const Offset(360, 242));
      });

      test('top + end with crossAxisOffset shifts left', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.end,
          crossAxisOffset: 10,
        );
        // x: target.right - childWidth - 10 = 450 - 120 - 10 = 320
        expect(pos, const Offset(320, 242));
      });

      test('top + center with crossAxisOffset shifts right', () {
        final pos = position(
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          crossAxisOffset: 10,
        );
        // x: 340 + 10 = 350
        expect(pos, const Offset(350, 242));
      });

      test('left + start with crossAxisOffset shifts down', () {
        final pos = position(
          direction: TooltipDirection.left,
          alignment: TooltipAlignment.start,
          crossAxisOffset: 5,
        );
        // y: target.top + 5 = 285
        expect(pos, const Offset(222, 285));
      });

      test('left + end with crossAxisOffset shifts up', () {
        final pos = position(
          direction: TooltipDirection.left,
          alignment: TooltipAlignment.end,
          crossAxisOffset: 5,
        );
        // y: target.bottom - childHeight - 5 = 320 - 30 - 5 = 285
        expect(pos, const Offset(222, 285));
      });

      test('right + center with crossAxisOffset shifts down', () {
        final pos = position(
          direction: TooltipDirection.right,
          alignment: TooltipAlignment.center,
          crossAxisOffset: 7,
        );
        // y: 285 + 7 = 292
        expect(pos, const Offset(458, 292));
      });

      test('zero crossAxisOffset has no effect', () {
        final pos = position(
          direction: TooltipDirection.bottom,
          alignment: TooltipAlignment.start,
          crossAxisOffset: 0,
        );
        expect(pos, const Offset(350, 328));
      });
    });

    // ---- auto direction flip ----

    group('auto direction flip', () {
      test('flips top to bottom when target near top edge', () {
        // Target at top of screen: y=5, not enough space above.
        final topTarget = const Offset(350, 5) & const Size(100, 40);
        final pos = position(
          direction: TooltipDirection.top,
          target: topTarget,
        );
        // Flipped to bottom: y = target.bottom + gap = 45 + 8 = 53
        expect(pos.dy, 53);
      });

      test('flips bottom to top when target near bottom edge', () {
        // Target at bottom of screen.
        final bottomTarget = const Offset(350, 555) & const Size(100, 40);
        final pos = position(
          direction: TooltipDirection.bottom,
          target: bottomTarget,
        );
        // Flipped to top: y = target.top - gap - childHeight = 555 - 8 - 30 = 517
        expect(pos.dy, 517);
      });

      test('flips left to right when target near left edge', () {
        final leftTarget = const Offset(5, 280) & const Size(100, 40);
        final pos = position(
          direction: TooltipDirection.left,
          target: leftTarget,
        );
        // Flipped to right: x = target.right + gap = 105 + 8 = 113
        expect(pos.dx, 113);
      });

      test('flips right to left when target near right edge', () {
        final rightTarget = const Offset(695, 280) & const Size(100, 40);
        final pos = position(
          direction: TooltipDirection.right,
          target: rightTarget,
        );
        // Flipped to left: x = target.left - gap - childWidth = 695 - 8 - 120 = 567
        expect(pos.dx, 567);
      });

      test('keeps original direction when neither side has space', () {
        // Very tall tooltip, no space on either side vertically.
        final pos = position(
          direction: TooltipDirection.top,
          childSize: const Size(120, 600),
        );
        // Neither top nor bottom has space. Keeps top, clamped to margin.
        expect(pos.dy, margin);
      });
    });

    // ---- viewport clamping ----

    group('viewport clamping', () {
      test('clamps left edge when tooltip extends past left', () {
        // Target at left edge, alignment=center, tooltip wider than space.
        final leftTarget = const Offset(10, 280) & const Size(40, 40);
        final pos = position(
          direction: TooltipDirection.top,
          target: leftTarget,
          childSize: const Size(120, 30),
        );
        // Ideal x: target.center.dx - 60 = 30 - 60 = -30 → clamped to margin
        expect(pos.dx, margin);
      });

      test('clamps right edge when tooltip extends past right', () {
        final rightTarget = const Offset(750, 280) & const Size(40, 40);
        final pos = position(
          direction: TooltipDirection.top,
          target: rightTarget,
          childSize: const Size(120, 30),
        );
        // Ideal x: 770 - 60 = 710 → clamped to 800 - 120 - 8 = 672
        expect(pos.dx, 672);
      });

      test('clamps top edge', () {
        final topTarget = const Offset(350, 2) & const Size(100, 40);
        final pos = position(
          direction: TooltipDirection.top,
          target: topTarget,
          childSize: const Size(120, 30),
        );
        // Both top and bottom: flips to bottom → y = 42 + 8 = 50, no clamp needed.
        // But if we force a scenario where even flipped it still clips...
        // In this case bottom has space, so it flips. y = 50.
        expect(pos.dy, greaterThanOrEqualTo(margin));
      });

      test('clamps bottom edge', () {
        final bottomTarget = const Offset(350, 560) & const Size(100, 40);
        final pos = position(
          direction: TooltipDirection.bottom,
          target: bottomTarget,
          childSize: const Size(120, 30),
        );
        // Flips to top: y = 560 - 8 - 30 = 522 → within bounds.
        expect(pos.dy, lessThanOrEqualTo(600 - 30 - margin));
      });
    });

    // ---- constraints ----

    group('getConstraintsForChild', () {
      test('constrains child to viewport minus margin', () {
        final delegate = JustTooltipPositionDelegate(
          targetRect: centerTarget,
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          gap: gap,
          screenMargin: 16,
        );
        final constraints = delegate.getConstraintsForChild(
          BoxConstraints.tight(viewportSize),
        );
        expect(constraints.maxWidth, 800 - 32);
        expect(constraints.maxHeight, 600 - 32);
      });

      test('constraints do not go negative with large margin', () {
        final delegate = JustTooltipPositionDelegate(
          targetRect: centerTarget,
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          gap: gap,
          screenMargin: 500,
        );
        final constraints = delegate.getConstraintsForChild(
          BoxConstraints.tight(viewportSize),
        );
        expect(constraints.maxWidth, 0);
        expect(constraints.maxHeight, 0);
      });
    });

    // ---- shouldRelayout ----

    group('shouldRelayout', () {
      test('returns false for identical delegates', () {
        final a = JustTooltipPositionDelegate(
          targetRect: centerTarget,
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          gap: gap,
        );
        final b = JustTooltipPositionDelegate(
          targetRect: centerTarget,
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          gap: gap,
        );
        expect(a.shouldRelayout(b), isFalse);
      });

      test('returns true when direction changes', () {
        final a = JustTooltipPositionDelegate(
          targetRect: centerTarget,
          direction: TooltipDirection.top,
          alignment: TooltipAlignment.center,
          gap: gap,
        );
        final b = JustTooltipPositionDelegate(
          targetRect: centerTarget,
          direction: TooltipDirection.bottom,
          alignment: TooltipAlignment.center,
          gap: gap,
        );
        expect(a.shouldRelayout(b), isTrue);
      });
    });
  });

  // ===========================================================================
  // JustTooltip widget tests
  // ===========================================================================
  group('JustTooltip widget', () {
    Widget buildApp({
      String message = 'Tooltip',
      TooltipDirection direction = TooltipDirection.top,
      TooltipAlignment alignment = TooltipAlignment.center,
      bool enableTap = false,
      bool enableHover = true,
      JustTooltipController? controller,
      WidgetBuilder? tooltipBuilder,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: tooltipBuilder != null ? null : message,
              tooltipBuilder: tooltipBuilder,
              direction: direction,
              alignment: alignment,
              enableTap: enableTap,
              enableHover: enableHover,
              controller: controller,
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      );
    }

    testWidgets('tap trigger shows and hides tooltip', (tester) async {
      await tester.pumpWidget(buildApp(enableTap: true, enableHover: false));

      // Tooltip text not visible initially.
      expect(find.text('Tooltip'), findsNothing);

      // Tap to show.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsOneWidget);

      // Tap again to hide.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsNothing);
    });

    testWidgets('controller show/hide works', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        buildApp(controller: controller, enableHover: false),
      );

      expect(find.text('Tooltip'), findsNothing);

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsOneWidget);

      controller.hide();
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsNothing);
    });

    testWidgets('custom tooltipBuilder renders', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        buildApp(
          controller: controller,
          enableHover: false,
          tooltipBuilder: (_) => const Text('Custom'),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('onShow and onHide callbacks fire', (tester) async {
      var showCount = 0;
      var hideCount = 0;
      final controller = JustTooltipController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'Tooltip',
                controller: controller,
                enableHover: false,
                onShow: () => showCount++,
                onHide: () => hideCount++,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(showCount, 1);
      expect(hideCount, 0);

      controller.hide();
      await tester.pumpAndSettle();
      expect(showCount, 1);
      expect(hideCount, 1);
    });

    testWidgets('tooltip removed on widget disposal', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        buildApp(controller: controller, enableHover: false),
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsOneWidget);

      // Navigate away, disposing the widget.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tooltip'), findsNothing);
    });
  });

  // ===========================================================================
  // TooltipShapePainter tests
  // ===========================================================================
  group('TooltipShapePainter', () {
    test('shouldRepaint returns false for identical painters', () {
      const theme = JustTooltipTheme(
        backgroundColor: Color(0xFF616161),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      );
      const a = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: theme,
      );
      const b = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: theme,
      );
      expect(a.shouldRepaint(b), isFalse);
    });

    test('shouldRepaint returns true when direction changes', () {
      const theme = JustTooltipTheme(
        backgroundColor: Color(0xFF616161),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      );
      const a = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: theme,
      );
      const b = TooltipShapePainter(
        direction: TooltipDirection.bottom,
        theme: theme,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint returns true when showArrow changes', () {
      const themeA = JustTooltipTheme(
        backgroundColor: Color(0xFF616161),
        borderRadius: BorderRadius.all(Radius.circular(6)),
        showArrow: false,
      );
      const themeB = JustTooltipTheme(
        backgroundColor: Color(0xFF616161),
        borderRadius: BorderRadius.all(Radius.circular(6)),
        showArrow: true,
      );
      const a = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: themeA,
      );
      const b = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: themeB,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint returns true when color changes', () {
      const themeA = JustTooltipTheme(
        backgroundColor: Color(0xFF616161),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      );
      const themeB = JustTooltipTheme(
        backgroundColor: Color(0xFF000000),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      );
      const a = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: themeA,
      );
      const b = TooltipShapePainter(
        direction: TooltipDirection.top,
        theme: themeB,
      );
      expect(a.shouldRepaint(b), isTrue);
    });
  });

  // ===========================================================================
  // onDirectionResolved callback tests
  // ===========================================================================
  group('JustTooltipPositionDelegate onDirectionResolved', () {
    test('calls callback with resolved direction after flip', () {
      TooltipDirection? resolved;
      final delegate = JustTooltipPositionDelegate(
        targetRect: const Offset(350, 5) & const Size(100, 40),
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.center,
        gap: 8.0,
        onDirectionResolved: (dir) => resolved = dir,
      );
      delegate.getPositionForChild(const Size(800, 600), const Size(120, 30));
      // Target near top → flips to bottom.
      expect(resolved, TooltipDirection.bottom);
    });

    test('calls callback with original direction when no flip needed', () {
      TooltipDirection? resolved;
      final delegate = JustTooltipPositionDelegate(
        targetRect: const Offset(350, 280) & const Size(100, 40),
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.center,
        gap: 8.0,
        onDirectionResolved: (dir) => resolved = dir,
      );
      delegate.getPositionForChild(const Size(800, 600), const Size(120, 30));
      expect(resolved, TooltipDirection.top);
    });

    test('callback is not called when null', () {
      // Should not throw.
      final delegate = JustTooltipPositionDelegate(
        targetRect: const Offset(350, 280) & const Size(100, 40),
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.center,
        gap: 8.0,
      );
      delegate.getPositionForChild(const Size(800, 600), const Size(120, 30));
    });
  });

  // ===========================================================================
  // Arrow widget tests
  // ===========================================================================
  group('JustTooltip arrow', () {
    testWidgets('arrow is rendered when showArrow is true', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'With arrow',
                theme: const JustTooltipTheme(showArrow: true),
                controller: controller,
                enableHover: false,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TooltipShapePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('arrow is not rendered when showArrow is false',
        (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'No arrow',
                theme: const JustTooltipTheme(showArrow: false),
                controller: controller,
                enableHover: false,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TooltipShapePainter,
        ),
        findsNothing,
      );
    });

    testWidgets('arrow tooltip still shows message text', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'Arrow tooltip',
                theme: const JustTooltipTheme(showArrow: true),
                controller: controller,
                enableHover: false,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();

      expect(find.text('Arrow tooltip'), findsOneWidget);
    });
  });
}
