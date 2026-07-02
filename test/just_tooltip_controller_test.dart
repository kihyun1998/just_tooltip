import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/src/just_tooltip_controller.dart';

/// A stand-in for the widget State, so the controller's command-forwarding can
/// be tested without pumping a widget.
class _FakeTarget implements JustTooltipControllerTarget {
  int showCount = 0;
  int hideCount = 0;
  int toggleCount = 0;
  bool showing = false;

  @override
  void showTooltip() => showCount++;
  @override
  void hideTooltip() => hideCount++;
  @override
  void toggleTooltip() => toggleCount++;
  @override
  bool get isTooltipShowing => showing;
}

void main() {
  group('JustTooltipController', () {
    test('attached show() forwards to the target', () {
      final controller = JustTooltipController();
      final target = _FakeTarget();
      controller.attach(target);

      controller.show();

      expect(target.showCount, 1);
    });

    test('attached hide() and toggle() forward to the target', () {
      final controller = JustTooltipController();
      final target = _FakeTarget();
      controller.attach(target);

      controller.hide();
      expect(target.hideCount, 1);

      controller.toggle();
      expect(target.toggleCount, 1);
    });

    test('attached isShowing reflects the target', () {
      final controller = JustTooltipController();
      final target = _FakeTarget();
      controller.attach(target);

      expect(controller.isShowing, isFalse);
      target.showing = true;
      expect(controller.isShowing, isTrue);
    });

    test('unattached commands queue a pending intent readable via isShowing',
        () {
      final controller = JustTooltipController();

      expect(controller.isShowing, isFalse);
      controller.show();
      expect(controller.isShowing, isTrue, reason: 'queued show');
      controller.hide();
      expect(controller.isShowing, isFalse, reason: 'queued hide');
      controller.toggle();
      expect(controller.isShowing, isTrue, reason: 'toggle flips the pending');
    });

    test('attach reports whether a show was queued', () {
      final queued = JustTooltipController()..show();
      expect(queued.attach(_FakeTarget()), isTrue,
          reason: 'a queued show is reported so the State can apply it');

      final idle = JustTooltipController();
      expect(idle.attach(_FakeTarget()), isFalse,
          reason: 'nothing queued → nothing to apply');
    });

    test('detached controller reports not showing', () {
      final controller = JustTooltipController();
      final target = _FakeTarget()..showing = true;
      controller.show(); // queue a show before attach
      controller.attach(target);
      expect(controller.isShowing, isTrue, reason: 'reads the attached target');

      controller.detach(target);
      expect(controller.isShowing, isFalse,
          reason: 'detached → false; the consumed pending is not resurrected');
    });

    test('attaching a second target while attached throws', () {
      final controller = JustTooltipController();
      controller.attach(_FakeTarget());

      expect(
        () => controller.attach(_FakeTarget()),
        throwsAssertionError,
        reason: 'one controller drives one tooltip',
      );
    });
  });
}
