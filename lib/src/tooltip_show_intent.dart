import 'dart:async';

import 'package:meta/meta.dart';

import 'tooltip_key_dismissal.dart';
import 'tooltip_registry.dart';

/// The pointer facts Show Intent is derived from.
///
/// [TooltipShowIntent.pointer] holds them as the tooltip last recorded them;
/// the variants are the cases the derivation also asks about.
@internal
@immutable
class PointerFacts {
  const PointerFacts({
    required this.inside,
    required this.onBody,
    required this.hold,
  });

  /// The pointer counted outside the child and off the body, holding no
  /// dismissal.
  static const away = PointerFacts(inside: false, onBody: false, hold: false);

  /// Whether the pointer is inside the child.
  final bool inside;

  /// Whether the pointer is on the tooltip's body.
  final bool onBody;

  /// Whether the pointer holds a dismissal.
  final bool hold;

  /// These facts with the pointer counted off the body.
  PointerFacts get offBody =>
      PointerFacts(inside: inside, onBody: false, hold: hold);

  /// These facts with the pointer entering the body counted as the pointer
  /// entering the child: inside, and holding a dismissal only when it did not
  /// move there ([moved] false: the body came under a still pointer).
  PointerFacts enteringBody({required bool moved}) =>
      PointerFacts(inside: true, onBody: onBody, hold: hold && !moved);
}

/// The internal contract a tooltip implements so [TooltipShowIntent] can
/// derive its show intent: the facts and gates it reads, and the transitions
/// it reports.
@internal
abstract interface class ShowIntentTooltip
    implements DismissibleTooltip, KeyDismissibleTooltip {
  bool get enableHover;

  bool get enableFocus;

  /// Whether the pointer is within the tooltip's child.
  bool get pointerInside;

  /// Whether the pointer is on the tooltip's body.
  bool get pointerOnBody;

  /// Whether `enableHover` was on when the pointer last entered the body.
  bool get bodyEnteredWithHover;

  /// Whether focus inside the tooltip arrived by a key press.
  bool get keyboardFocusInside;

  /// Whether a nested tooltip holding the pointer suppresses this one.
  bool get hasPointerSuppressor;

  /// Whether a nested tooltip holding keyboard focus claims this one.
  bool get hasFocusSuppressor;

  /// Whether the tooltip has anything to draw.
  bool get hasTooltipContent;

  /// Whether the tooltip is Covered and may not show.
  bool get covered;

  /// Whether the child, as last laid out, is clipped away entirely.
  bool get childClippedAway;

  /// The registry the tooltip belongs to.
  TooltipRegistry get registry;

  /// Watches, after each frame, for a child clipped away to be visible again.
  void watchClippedChild();

  /// Cancels every timer the scheduler holds for the tooltip.
  void resetScheduler();

  /// Show intent has turned on in a reconcile.
  void onShowIntentSet();

  /// Show intent has turned off in a reconcile.
  void onShowIntentDropped();
}

/// A tooltip's Show Intent: its derivation from the trigger facts, the
/// reconcile that hands its transitions to the tooltip, and the flags of its
/// lifecycle — show intent, the pending mark, a revival's phases, a
/// Dismissal's holds and the trigger acts.
@internal
class TooltipShowIntent {
  TooltipShowIntent(this._tooltip);

  final ShowIntentTooltip _tooltip;

  bool _isSet = false;

  /// Whether the pointer holds the dismissal: it was inside the child when the
  /// tooltip was dismissed, or came in while it was. Released by the pointer
  /// moving out of the child or into it, and by a show by show intent.
  bool _pointerHold = false;

  /// Whether keyboard focus holds the dismissal: it was inside the tooltip
  /// when the tooltip was dismissed, or came in while it was. Released by
  /// focus leaving the tooltip, and by a show by show intent.
  bool _focusHold = false;

  /// Whether a pointer act has come since the last reconcile: the pointer
  /// moving into the child, or off a nested tooltip that was suppressing this
  /// one. It counts only while the pointer is still inside.
  bool _pointerAct = false;

  /// Whether a focus act has come since the last reconcile: keyboard focus
  /// arriving in the child by a key, or moving off a nested tooltip that was
  /// suppressing this one. It counts only while key-arrived focus is still
  /// inside.
  bool _focusAct = false;

  bool _reconcileQueued = false;

  /// Whether the registry has revived this tooltip and neither its reconcile
  /// nor its return to waiting has run yet.
  bool _revivalPending = false;

  /// Whether the show waiting out `waitDuration` is one a revival began.
  /// Holds only while the tooltip is pending.
  bool _revivalWaiting = false;

  /// The last show intent handed to the tooltip — [triggerInside], gated by
  /// nesting suppression, content, [dismissed], Covered, a child clipped
  /// away entirely and eviction. Only its *transitions* are reported.
  bool get isSet => _isSet;

  /// The pointer facts as the tooltip last recorded them.
  PointerFacts get pointer => PointerFacts(
    inside: _tooltip.pointerInside,
    onBody: _tooltip.pointerOnBody,
    hold: _pointerHold,
  );

  // ---------------------------------------------------------------------------
  // The derivation
  // ---------------------------------------------------------------------------

  /// Whether a trigger this tooltip listens to is inside its child.
  bool get triggerInside => triggerInsideFor(pointer);

  /// [triggerInside] with the pointer facts [p].
  bool triggerInsideFor(PointerFacts p) =>
      (_tooltip.enableHover && p.inside) ||
      (_tooltip.enableFocus && _tooltip.keyboardFocusInside);

  /// Whether a nested tooltip suppresses this one.
  bool get suppressed => suppressedFor(pointer);

  /// [suppressed] with the pointer facts [p]: a pointer suppressor always
  /// suppresses; a focus suppressor only while the pointer is neither inside
  /// the child with `enableHover` on nor on the body it entered with
  /// `enableHover` on.
  bool suppressedFor(PointerFacts p) =>
      _tooltip.hasPointerSuppressor ||
      (_tooltip.hasFocusSuppressor &&
          !(_tooltip.enableHover && p.inside) &&
          !(p.onBody && _tooltip.bodyEnteredWithHover));

  /// Whether a close other than the trigger leaving — Escape, a tap, the
  /// auto-hide, a controller — ended this tooltip while a trigger was inside,
  /// and a hold it left is still in force with its trigger reported inside.
  bool get dismissed => dismissedFor(pointer);

  /// [dismissed] with the pointer facts [p].
  bool dismissedFor(PointerFacts p) =>
      (p.hold && p.inside) || (_focusHold && _tooltip.keyboardFocusInside);

  /// Whether a trigger is inside and no gate but eviction holds the tooltip
  /// back: nesting suppression, content, [dismissed], Covered and a child
  /// clipped away entirely.
  bool get openToShow => openToShowIfVisible && !_tooltip.childClippedAway;

  /// [openToShow] without the child clipped away.
  bool get openToShowIfVisible => openToShowIfVisibleFor(pointer);

  /// [openToShowIfVisible] with the pointer facts [p].
  bool openToShowIfVisibleFor(PointerFacts p) =>
      triggerInsideFor(p) &&
      !suppressedFor(p) &&
      _tooltip.hasTooltipContent &&
      !dismissedFor(p) &&
      !_tooltip.covered;

  /// Whether keyboard focus holds this tooltip open with the pointer counted
  /// away: focus arrived by a key is inside, a nested tooltip holding focus
  /// does not suppress it, and no other gate of [openToShowIfVisible] holds
  /// it back.
  bool get heldOpenByFocus => openToShowIfVisibleFor(PointerFacts.away);

  /// Whether the pointer entering the body of a tooltip fading out turns the
  /// fade back: what the pointer entering the child would do in the same
  /// state: never with `enableHover` off. [moved] says the pointer moved onto
  /// the body, rather than the body moving under a still pointer.
  bool turnsBackFromBody({required bool moved}) =>
      _tooltip.enableHover &&
      _tooltip.isTooltipFadingOut &&
      !_isSet &&
      openToShowIfVisibleFor(pointer.enteringBody(moved: moved)) &&
      !_tooltip.childClippedAway &&
      (moved || !_tooltip.registry.isEvicted(_tooltip));

  // ---------------------------------------------------------------------------
  // The reconcile
  // ---------------------------------------------------------------------------

  /// Queues one reconcile for the end of the current microtask batch.
  void scheduleReconcile() {
    if (_reconcileQueued) return;
    _reconcileQueued = true;
    scheduleMicrotask(_reconcile);
  }

  /// Runs a queued reconcile now.
  void flushReconcile() {
    if (_reconcileQueued) _reconcile();
  }

  void _reconcile() {
    _reconcileQueued = false;
    final revival = _revivalPending;
    _revivalPending = false;
    final pointerAct = _pointerAct;
    final focusAct = _focusAct;
    _pointerAct = false;
    _focusAct = false;
    final tooltip = _tooltip;
    if (!tooltip.mounted) return;

    if (dismissed) {
      // A trigger that comes in while the tooltip is dismissed holds it too.
      if (tooltip.enableHover && tooltip.pointerInside) _pointerHold = true;
      if (tooltip.enableFocus && tooltip.keyboardFocusInside) {
        _focusHold = true;
      }
    }
    // An evicted tooltip gains show intent before its revival only on a new
    // trigger act.
    final act =
        (pointerAct && tooltip.enableHover && tooltip.pointerInside) ||
        (focusAct && tooltip.enableFocus && tooltip.keyboardFocusInside);
    if (act) _revivalWaiting = false;
    final waiting = !_isSet && !act && tooltip.registry.isEvicted(tooltip);
    final open = openToShowIfVisible;
    final clipped = open && tooltip.childClippedAway;
    if (clipped) tooltip.watchClippedChild();
    final wants = open && !clipped && !waiting;
    pending = wants && !tooltip.isTooltipShowing;
    if (wants && !tooltip.isTooltipShowing) tooltip.watchClippedChild();
    if (wants == _isSet) return;

    if (wants) {
      // A hold of a trigger turned off ends once the tooltip shows again.
      _pointerHold = false;
      _focusHold = false;
      _isSet = true;
      _revivalWaiting = revival && !act && !tooltip.isTooltipShowing;
      tooltip.onShowIntentSet();
      return;
    }
    drop();
    tooltip.onShowIntentDropped();
  }

  // ---------------------------------------------------------------------------
  // The lifecycle
  // ---------------------------------------------------------------------------

  /// Whether the tooltip's show is scheduled but not yet on screen, as
  /// recorded for Escape.
  bool get pending => TooltipKeyDismissal.isPending(_tooltip);

  /// Records whether the tooltip's show is scheduled but not yet on screen;
  /// a show no longer pending is no longer a revival's.
  set pending(bool pending) {
    if (!pending) _revivalWaiting = false;
    TooltipKeyDismissal.pending(_tooltip, pending);
  }

  /// Drops show intent, first settling the close that began a fade-out.
  void drop() {
    settleFadingClose();
    _isSet = false;
  }

  /// Cancels a show not yet on screen: [drop]s show intent, clears the
  /// pending mark and has the tooltip reset its scheduler.
  void cancelPendingShow() {
    drop();
    pending = false;
    _tooltip.resetScheduler();
  }

  /// Takes a close the user made — Escape, or a close that cancels a
  /// waiting show: [cancelPendingShow], then [markDismissed].
  void dismiss() {
    cancelPendingShow();
    markDismissed();
  }

  /// A close with show intent still set was not caused by the trigger leaving
  /// — a tap, the auto-hide, a controller. Drops show intent and marks the
  /// tooltip dismissed while a trigger is inside, so it stays closed until the
  /// trigger leaves and returns.
  void settleClose() {
    if (!_isSet) return;
    _isSet = false;
    markDismissed();
  }

  /// Settles the close that began a fade-out, if one is fading: called before
  /// show intent or a trigger fact goes.
  void settleFadingClose() {
    if (_tooltip.isTooltipFadingOut) settleClose();
  }

  /// Dismisses the tooltip for each trigger inside it, keeping the holds it
  /// already has.
  void markDismissed() {
    if (_tooltip.pointerInside) _pointerHold = true;
    if (_tooltip.keyboardFocusInside) _focusHold = true;
  }

  /// Takes a close the trigger leaving did not cause. During a revival's
  /// wait it [dismiss]es the tooltip. An evicted tooltip, or one whose
  /// revival has not reconciled yet, that is [openToShow] takes it as a
  /// dismissal: fading out, it takes show intent back, so the settle at the
  /// fade's end marks it; already hidden, with no show intent, it is marked
  /// dismissed at once.
  void closeRequested() {
    if (_revivalWaiting) {
      dismiss();
      return;
    }
    if ((_tooltip.registry.isEvicted(_tooltip) || _revivalPending) &&
        openToShow) {
      if (_tooltip.isTooltipFadingOut) {
        _isSet = true;
      } else if (!_isSet) {
        markDismissed();
      }
    }
  }

  /// Re-derives show intent in a microtask, unless by then a tooltip holds
  /// the place in the tooltip's registry; then the tooltip waits again and
  /// the revival is over.
  void revive() {
    _revivalPending = true;
    scheduleMicrotask(() {
      if (!_tooltip.mounted) return;
      if (_tooltip.registry.keepsWaiting(_tooltip)) {
        _revivalPending = false;
        return;
      }
      scheduleReconcile();
    });
  }

  /// The pointer moved into the child, or off a nested tooltip that was
  /// suppressing this one.
  void notePointerAct() => _pointerAct = true;

  /// Keyboard focus arrived in the child by a key, or moved off a nested
  /// tooltip that was suppressing this one.
  void noteFocusAct() => _focusAct = true;

  /// The pointer moved out of the child or into it.
  void releasePointerHold() => _pointerHold = false;

  /// Keyboard focus is not inside the tooltip.
  void releaseFocusHold() => _focusHold = false;
}
