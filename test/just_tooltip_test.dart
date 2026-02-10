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
  // tooltip_position_utils tests
  // ===========================================================================
  group('computeTooltipPosition', () {
    const gap = 8.0;

    // ---- top ----
    test('top + start', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.start,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.topLeft);
      expect(data.followerAnchor, Alignment.bottomLeft);
      expect(data.offset, const Offset(0, -gap));
    });

    test('top + center', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.center,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.topCenter);
      expect(data.followerAnchor, Alignment.bottomCenter);
      expect(data.offset, const Offset(0, -gap));
    });

    test('top + end', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.end,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.topRight);
      expect(data.followerAnchor, Alignment.bottomRight);
      expect(data.offset, const Offset(0, -gap));
    });

    // ---- bottom ----
    test('bottom + start', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.bottom,
        alignment: TooltipAlignment.start,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.bottomLeft);
      expect(data.followerAnchor, Alignment.topLeft);
      expect(data.offset, const Offset(0, gap));
    });

    test('bottom + center', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.bottom,
        alignment: TooltipAlignment.center,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.bottomCenter);
      expect(data.followerAnchor, Alignment.topCenter);
      expect(data.offset, const Offset(0, gap));
    });

    test('bottom + end', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.bottom,
        alignment: TooltipAlignment.end,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.bottomRight);
      expect(data.followerAnchor, Alignment.topRight);
      expect(data.offset, const Offset(0, gap));
    });

    // ---- left ----
    test('left + start', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.left,
        alignment: TooltipAlignment.start,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.topLeft);
      expect(data.followerAnchor, Alignment.topRight);
      expect(data.offset, const Offset(-gap, 0));
    });

    test('left + center', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.left,
        alignment: TooltipAlignment.center,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.centerLeft);
      expect(data.followerAnchor, Alignment.centerRight);
      expect(data.offset, const Offset(-gap, 0));
    });

    test('left + end', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.left,
        alignment: TooltipAlignment.end,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.bottomLeft);
      expect(data.followerAnchor, Alignment.bottomRight);
      expect(data.offset, const Offset(-gap, 0));
    });

    // ---- right ----
    test('right + start', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.right,
        alignment: TooltipAlignment.start,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.topRight);
      expect(data.followerAnchor, Alignment.topLeft);
      expect(data.offset, const Offset(gap, 0));
    });

    test('right + center', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.right,
        alignment: TooltipAlignment.center,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.centerRight);
      expect(data.followerAnchor, Alignment.centerLeft);
      expect(data.offset, const Offset(gap, 0));
    });

    test('right + end', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.right,
        alignment: TooltipAlignment.end,
        gap: gap,
      );
      expect(data.targetAnchor, Alignment.bottomRight);
      expect(data.followerAnchor, Alignment.bottomLeft);
      expect(data.offset, const Offset(gap, 0));
    });

    // ---- RTL ----
    test('top + start with RTL resolves to end', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.start,
        gap: gap,
        textDirection: TextDirection.rtl,
      );
      expect(data.targetAnchor, Alignment.topRight);
      expect(data.followerAnchor, Alignment.bottomRight);
    });

    test('top + end with RTL resolves to start', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.end,
        gap: gap,
        textDirection: TextDirection.rtl,
      );
      expect(data.targetAnchor, Alignment.topLeft);
      expect(data.followerAnchor, Alignment.bottomLeft);
    });

    test('top + center with RTL stays center', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.top,
        alignment: TooltipAlignment.center,
        gap: gap,
        textDirection: TextDirection.rtl,
      );
      expect(data.targetAnchor, Alignment.topCenter);
      expect(data.followerAnchor, Alignment.bottomCenter);
    });

    test('left + start with RTL is not affected', () {
      final data = computeTooltipPosition(
        direction: TooltipDirection.left,
        alignment: TooltipAlignment.start,
        gap: gap,
        textDirection: TextDirection.rtl,
      );
      // left/right directions should not be affected by RTL.
      expect(data.targetAnchor, Alignment.topLeft);
      expect(data.followerAnchor, Alignment.topRight);
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
}
