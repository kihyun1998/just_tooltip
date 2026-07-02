import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/src/tooltip_registry.dart';

class _FakeDismissible implements DismissibleTooltip {
  int dismissCount = 0;

  @override
  void dismissTooltip() => dismissCount++;
}

void main() {
  group('TooltipRegistry', () {
    test('showing an entry dismisses previously-shown entries', () {
      final registry = TooltipRegistry();
      final first = _FakeDismissible();
      final second = _FakeDismissible();

      registry.show(first);
      registry.show(second);

      expect(first.dismissCount, 1, reason: 'first is dismissed when second shows');
      expect(second.dismissCount, 0, reason: 'the newly shown entry is not dismissed');
    });

    test('a removed entry is not dismissed by a later show', () {
      final registry = TooltipRegistry();
      final first = _FakeDismissible();
      final second = _FakeDismissible();

      registry.show(first);
      registry.remove(first);
      registry.show(second);

      expect(first.dismissCount, 0, reason: 'removed before second was shown');
    });

    test('separate registry instances are isolated', () {
      final registryA = TooltipRegistry();
      final registryB = TooltipRegistry();
      final a = _FakeDismissible();
      final b = _FakeDismissible();

      registryA.show(a);
      registryB.show(b);

      expect(a.dismissCount, 0,
          reason: 'showing in a different registry does not dismiss a');
    });
  });
}
