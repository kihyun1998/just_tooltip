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
}
