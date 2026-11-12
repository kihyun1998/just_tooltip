import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/src/tooltip_registry.dart';

class _FakeDismissible implements DismissibleTooltip {
  int dismissCount = 0;
  int reviveCount = 0;

  @override
  void dismissTooltip() => dismissCount++;

  @override
  void reviveTooltip() => reviveCount++;
}

void main() {
  group('TooltipRegistry', () {
    test('showing an entry dismisses previously-shown entries', () {
      final registry = TooltipRegistry();
      final first = _FakeDismissible();
      final second = _FakeDismissible();

      registry.show(first);
      registry.show(second);

      expect(
        first.dismissCount,
        1,
        reason: 'first is dismissed when second shows',
      );
      expect(
        second.dismissCount,
        0,
        reason: 'the newly shown entry is not dismissed',
      );
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

      expect(
        a.dismissCount,
        0,
        reason: 'showing in a different registry does not dismiss a',
      );
    });

    test('an evicted entry is revived once no entry holds the place', () {
      final registry = TooltipRegistry();
      final evicted = _FakeDismissible();
      final first = _FakeDismissible();
      final second = _FakeDismissible();

      registry.show(evicted);
      registry.show(first);
      registry.show(second);
      registry.remove(evicted);
      registry.remove(first);
      expect(evicted.reviveCount, 0, reason: 'second still holds the place');
      expect(first.reviveCount, 0);

      registry.remove(second);
      expect(evicted.reviveCount, 1);
      expect(first.reviveCount, 1);
      expect(second.reviveCount, 0, reason: 'second was never evicted');

      registry.show(second);
      registry.remove(second);
      expect(evicted.reviveCount, 1, reason: 'revived once, then forgotten');
    });

    test('an entry removed in another registry revives nothing', () {
      final registry = TooltipRegistry();
      final other = TooltipRegistry();
      final evicted = _FakeDismissible();
      final holder = _FakeDismissible();
      final elsewhere = _FakeDismissible();

      registry.show(evicted);
      registry.show(holder);
      other.show(elsewhere);
      other.remove(elsewhere);
      expect(evicted.reviveCount, 0);
    });

    test('an entry that was not registered revives nothing', () {
      final registry = TooltipRegistry();
      final evicted = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(evicted);
      registry.show(holder);
      registry.remove(holder);
      registry.show(holder);
      registry.remove(_FakeDismissible());
      expect(evicted.reviveCount, 1, reason: 'only the first remove revived');
    });

    test('an evicted entry shown again stops waiting to be revived', () {
      final registry = TooltipRegistry();
      final evicted = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(evicted);
      registry.show(holder);
      registry.show(evicted);
      registry.remove(evicted);
      expect(evicted.reviveCount, 0);
      expect(holder.reviveCount, 1, reason: 'evicted took the place back');
    });

    test('a forgotten entry is not revived', () {
      final registry = TooltipRegistry();
      final evicted = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(evicted);
      registry.show(holder);
      registry.forget(evicted);
      registry.remove(holder);
      expect(evicted.reviveCount, 0);
    });

    test('a holder that leaves revives the evicted entries', () {
      final registry = TooltipRegistry();
      final evicted = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(evicted);
      registry.show(holder);
      expect(registry.leave(holder), isFalse, reason: 'holder was not evicted');
      expect(evicted.reviveCount, 1);
    });

    test('an evicted entry that leaves is not revived', () {
      final registry = TooltipRegistry();
      final evicted = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(evicted);
      registry.show(holder);
      expect(registry.leave(evicted), isTrue);
      registry.remove(holder);
      expect(evicted.reviveCount, 0);
    });

    test(
      'an entry waiting where no entry holds the place is revived at once',
      () {
        final registry = TooltipRegistry();
        final entry = _FakeDismissible();

        registry.wait(entry);
        expect(entry.reviveCount, 1);
        registry.show(_FakeDismissible());
        expect(entry.dismissCount, 0, reason: 'it did not take the place');
      },
    );

    test(
      'take records the previous holder as evicted without dismissing it',
      () {
        final registry = TooltipRegistry();
        final previous = _FakeDismissible();
        final entry = _FakeDismissible();

        registry.show(previous);
        expect(registry.take(entry), same(previous));
        expect(previous.dismissCount, 0);
        registry.dismissEvicted(previous);
        expect(previous.dismissCount, 1);
        registry.remove(entry);
        expect(previous.reviveCount, 1, reason: 'it was recorded as evicted');
      },
    );

    test('dismissEvicted skips an entry that took the place back', () {
      final registry = TooltipRegistry();
      final previous = _FakeDismissible();
      final entry = _FakeDismissible();

      registry.show(previous);
      registry.take(entry);
      registry.show(previous);
      expect(entry.dismissCount, 1);
      registry.dismissEvicted(previous);
      expect(previous.dismissCount, 0);
    });

    test('an entry waiting where one holds the place is revived when it '
        'leaves', () {
      final registry = TooltipRegistry();
      final entry = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(holder);
      registry.wait(entry);
      expect(entry.reviveCount, 0);
      registry.remove(holder);
      expect(entry.reviveCount, 1);
    });

    test('isEvicted holds from the eviction until the revival', () {
      final registry = TooltipRegistry();
      final entry = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(entry);
      expect(registry.isEvicted(entry), isFalse);
      registry.show(holder);
      expect(registry.isEvicted(entry), isTrue);
      expect(registry.isEvicted(holder), isFalse);
      registry.remove(holder);
      expect(registry.isEvicted(entry), isFalse);
    });

    test('isEvicted ends when the evicted entry takes the place back', () {
      final registry = TooltipRegistry();
      final entry = _FakeDismissible();
      final holder = _FakeDismissible();

      registry.show(entry);
      registry.show(holder);
      registry.show(entry);
      expect(registry.isEvicted(entry), isFalse);
      expect(registry.isEvicted(holder), isTrue);
    });
  });
}
