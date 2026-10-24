import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';
import 'package:just_tooltip/src/tooltip_shape_painter.dart';

/// The tooltip follows the inherited widgets at the [JustTooltip]'s location,
/// not the ones above the [Overlay] it draws into.
void main() {
  /// Pumps a tooltip with [wrap] placed between the `Scaffold` and the
  /// [JustTooltip] — below the Navigator's Overlay — and shows it.
  Future<void> showWrapped(
    WidgetTester tester, {
    required Widget Function(Widget tooltip) wrap,
    required WidgetBuilder tooltipBuilder,
    TooltipDirection direction = TooltipDirection.top,
    TooltipAlignment alignment = TooltipAlignment.center,
    JustTooltipTheme theme = const JustTooltipTheme(),
  }) async {
    final controller = JustTooltipController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: wrap(
              JustTooltip(
                controller: controller,
                enableHover: false,
                direction: direction,
                alignment: alignment,
                theme: theme,
                tooltipBuilder: tooltipBuilder,
                child: const SizedBox(
                  key: Key('target'),
                  width: 100,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
  }

  testWidgets('the content sees a Directionality set around the tooltip', (
    tester,
  ) async {
    TextDirection? seen;
    await showWrapped(
      tester,
      wrap: (t) => Directionality(textDirection: TextDirection.rtl, child: t),
      tooltipBuilder: (context) {
        seen = Directionality.of(context);
        return const SizedBox(width: 200, height: 30);
      },
    );
    expect(seen, TextDirection.rtl);
  });

  testWidgets('the content sees a Theme set around the tooltip', (
    tester,
  ) async {
    Color? seen;
    await showWrapped(
      tester,
      wrap: (t) => Theme(
        data: ThemeData(primaryColor: const Color(0xFFFF0000)),
        child: t,
      ),
      tooltipBuilder: (context) {
        seen = Theme.of(context).primaryColor;
        return const SizedBox(width: 200, height: 30);
      },
    );
    expect(seen, const Color(0xFFFF0000));
  });

  testWidgets('the content sees a MediaQuery set around the tooltip', (
    tester,
  ) async {
    TextScaler? seen;
    await showWrapped(
      tester,
      wrap: (t) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: t,
        ),
      ),
      tooltipBuilder: (context) {
        seen = MediaQuery.textScalerOf(context);
        return const SizedBox(width: 200, height: 30);
      },
    );
    expect(seen, const TextScaler.linear(2));
  });

  testWidgets('the content stays out of a SelectionArea around the tooltip', (
    tester,
  ) async {
    Object? seen = 'unbuilt';
    await showWrapped(
      tester,
      wrap: (t) => SelectionArea(child: t),
      tooltipBuilder: (context) {
        seen = SelectionContainer.maybeOf(context);
        return const SizedBox(width: 200, height: 30);
      },
    );
    expect(seen, isNull);
  });

  testWidgets('RTL alignment mirroring follows a Directionality set around the '
      'tooltip', (tester) async {
    await showWrapped(
      tester,
      wrap: (t) => Directionality(textDirection: TextDirection.rtl, child: t),
      alignment: TooltipAlignment.start,
      theme: const JustTooltipTheme(showArrow: true),
      tooltipBuilder: (context) => const SizedBox(width: 200, height: 30),
    );
    final target = tester.getRect(find.byKey(const Key('target')));
    final body = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TooltipShapePainter,
      ),
    );
    // `start` is the target's right edge in RTL.
    expect(body.right, target.right);
  });
}
