import 'package:meta/meta.dart';

/// The internal contract a tooltip implements so the [TooltipRegistry] can
/// dismiss it when another tooltip is shown, and re-derive it once no tooltip
/// holds the place.
///
/// [reviveTooltip] may act later; when it does, it asks its registry's
/// [TooltipRegistry.keepsWaiting] first.
@internal
abstract interface class DismissibleTooltip {
  void dismissTooltip();

  void reviveTooltip();
}

/// Enforces the "one tooltip visible at a time" policy.
///
/// A [JustTooltip] registers on show and is removed when its show ends.
/// Showing a tooltip dismisses the one that held the place; the tooltips
/// dismissed this way are revived once no tooltip in the registry holds the
/// place.
///
/// Defaults to an app-global shared instance. Pass an explicit
/// `TooltipRegistry()` to [JustTooltip.registry] to isolate a group (or a
/// test) from the shared one.
class TooltipRegistry {
  TooltipRegistry();

  /// The tooltip that holds the place: shown, or fading out on its own hide,
  /// and not dismissed by another one's show.
  DismissibleTooltip? _holder;

  /// The tooltips dismissed by another one's show, waiting to be revived.
  final Set<DismissibleTooltip> _evicted = {};

  /// Registers [entry], dismissing the tooltip that held the place.
  @internal
  void show(DismissibleTooltip entry) => take(entry)?.dismissTooltip();

  /// Makes [entry] the holder and records the tooltip that held the place as
  /// evicted, without dismissing it. Returns that tooltip, if any.
  @internal
  DismissibleTooltip? take(DismissibleTooltip entry) {
    final previous = _holder;
    _evicted.remove(entry);
    _holder = entry;
    if (previous == null || identical(previous, entry)) return null;
    _evicted.add(previous);
    return previous;
  }

  /// Whether [entry] is recorded here as evicted: dismissed by another
  /// tooltip's show and waiting to be revived.
  @internal
  bool isEvicted(DismissibleTooltip entry) => _evicted.contains(entry);

  /// Dismisses [entry] if it is still evicted here.
  @internal
  void dismissEvicted(DismissibleTooltip entry) {
    if (_evicted.contains(entry)) entry.dismissTooltip();
  }

  /// Called when [entry]'s show ends. When [entry] holds the place, clears it
  /// and revives every evicted tooltip; otherwise does nothing, and an evicted
  /// [entry] stays evicted.
  @internal
  void remove(DismissibleTooltip entry) {
    if (!identical(_holder, entry)) return;
    _holder = null;
    final evicted = _evicted.toList();
    _evicted.clear();
    for (final tooltip in evicted) {
      tooltip.reviveTooltip();
    }
  }

  /// Stops waiting to revive [entry]. Called when a tooltip is disposed.
  @internal
  void forget(DismissibleTooltip entry) => _evicted.remove(entry);

  /// Takes every record of [entry] out of this registry: it stops waiting to
  /// be revived, and when it holds the place, the place is cleared and the
  /// evicted tooltips are revived. Returns whether [entry] was waiting to be
  /// revived.
  @internal
  bool leave(DismissibleTooltip entry) {
    final wasEvicted = _evicted.remove(entry);
    remove(entry);
    return wasEvicted;
  }

  /// Makes [entry], evicted in another registry, wait in this one: it is
  /// revived once no tooltip here holds the place, at once when none does.
  @internal
  void wait(DismissibleTooltip entry) {
    if (!keepsWaiting(entry)) entry.reviveTooltip();
  }

  /// Whether a tooltip other than [entry] holds the place. When one does,
  /// [entry] waits again to be revived.
  @internal
  bool keepsWaiting(DismissibleTooltip entry) {
    if (_holder == null || identical(_holder, entry)) return false;
    _evicted.add(entry);
    return true;
  }
}
