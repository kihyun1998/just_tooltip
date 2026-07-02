import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/src/enums.dart';
import 'package:just_tooltip/src/tooltip_transitions.dart';

void main() {
  group('TooltipTransitions', () {
    AnimationController makeController(WidgetTester tester) {
      final c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('none returns the child unchanged', (tester) async {
      final controller = makeController(tester);

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(type: TooltipAnimation.none),
          child: const SizedBox(key: Key('child')),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('fade wraps in a FadeTransition, transparent at t=0',
        (tester) async {
      final controller = makeController(tester); // value defaults to 0

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(type: TooltipAnimation.fade),
          child: const SizedBox(),
        ),
      );

      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 0.0);
    });

    testWidgets('fade honours a non-zero fadeBegin at t=0', (tester) async {
      final controller = makeController(tester);

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(
            type: TooltipAnimation.fade,
            fadeBegin: 0.5,
          ),
          child: const SizedBox(),
        ),
      );

      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 0.5);
    });

    testWidgets('scale wraps in a ScaleTransition, scale 0 at t=0',
        (tester) async {
      final controller = makeController(tester);

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(type: TooltipAnimation.scale),
          child: const SizedBox(),
        ),
      );

      final scale = tester.widget<ScaleTransition>(find.byType(ScaleTransition));
      expect(scale.scale.value, 0.0);
    });

    testWidgets('slide begin offset follows the preferred direction',
        (tester) async {
      const d = 0.3;
      const expected = <TooltipDirection, Offset>{
        TooltipDirection.top: Offset(0, -d),
        TooltipDirection.bottom: Offset(0, d),
        TooltipDirection.left: Offset(-d, 0),
        TooltipDirection.right: Offset(d, 0),
      };

      for (final entry in expected.entries) {
        final controller = makeController(tester);
        await tester.pumpWidget(
          TooltipTransitions.build(
            animation: controller,
            spec: TooltipTransitionSpec(
              type: TooltipAnimation.slide,
              slideOffset: d,
              direction: entry.key,
            ),
            child: const SizedBox(),
          ),
        );

        final slide =
            tester.widget<SlideTransition>(find.byType(SlideTransition));
        expect(slide.position.value, entry.value, reason: '${entry.key}');
      }
    });

    testWidgets('fadeScale composes a FadeTransition and a ScaleTransition',
        (tester) async {
      final controller = makeController(tester);

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(type: TooltipAnimation.fadeScale),
          child: const SizedBox(),
        ),
      );

      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(ScaleTransition), findsOneWidget);
    });

    testWidgets('fadeSlide composes a FadeTransition and a SlideTransition',
        (tester) async {
      final controller = makeController(tester);

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(type: TooltipAnimation.fadeSlide),
          child: const SizedBox(),
        ),
      );

      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(SlideTransition), findsOneWidget);
    });

    testWidgets('rotation composes fade + rotation starting at rotationBegin',
        (tester) async {
      final controller = makeController(tester);

      await tester.pumpWidget(
        TooltipTransitions.build(
          animation: controller,
          spec: const TooltipTransitionSpec(
            type: TooltipAnimation.rotation,
            rotationBegin: -0.05,
          ),
          child: const SizedBox(),
        ),
      );

      expect(find.byType(FadeTransition), findsOneWidget);
      final rotation =
          tester.widget<RotationTransition>(find.byType(RotationTransition));
      expect(rotation.turns.value, -0.05);
    });
  });
}
