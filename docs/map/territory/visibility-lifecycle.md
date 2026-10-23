# Visibility lifecycle

## What it is

Owns intent (`_isShowing`) and reconciles it with render state (`AnimationController.status`):
inserting and removing the `OverlayEntry`, starting and reversing the animation, the reverse-catch,
and teardown on deactivate/dispose. Vocabulary: [Intent vs Render State](../../../GLOSSARY.md#intent-vs-render-state).

## Governing decisions

- [ADR-0001](../../adr/0001-scheduler-separates-intent-from-render-state.md) — intent and render state stay two facts; the reverse-catch stays in the State. Not to be re-litigated.

## Design model

From ADR-0001, confirmed in source:

- `_show` is the only path that opens: refuses without content, sets `_isShowing`, freezes the anchor, registers with the registry (dismissing others), inserts the entry, starts tracking, `forward()`, `onShow`.
- `_hide` only `reverse()`s. The entry is removed when the animation reaches `dismissed` (`_onAnimationStatus`), which also clears per-show state and calls `onHide`.
- `_handleShowRequest`: a show request while `_isShowing` and reversing re-`forward()`s (reverse-catch) instead of opening again.
- `_hideImmediate` (deactivate, dispose) tears down without animation.
- A `forward()` can cover a `reverse()` that has not left `0.0`, so "the tooltip is visible" proves nothing about whether a hide happened; #39's tracking bug passed `findsOneWidget` this way and surfaced only when the test asserted `onHide` was *not* called (`docs/agents/lessons.md`, Step 5).

From reading only: `_onAnimationStatus` and `_hideImmediate` clear the same per-show fields (`_isShowing`, `_sawVisibleTarget`, `_frozenAnchor`, `_resolvedDirection`, `_arrowCenterOffset`, registry, entry) by hand; a new per-show field must be added to both.

## Code

- `lib/src/just_tooltip.dart` — `_isShowing`, `_show`, `_hide`, `_hideImmediate`, `_onAnimationStatus`, `_handleShowRequest`, `_animationController`, `_updateCurvedAnimation`, `deactivate`, `dispose`
- Tests: `test/just_tooltip_test.dart`, `test/just_tooltip_overlay_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — uses `OverlayPortal.overlayChildLayoutBuilder` and an `OverlayPortalController`, not an imperatively inserted `OverlayEntry`. ADR-0002 ("Relationship to OverlayPortalController") records the consequence here — the imperative overlay needs a post-frame apply — not a reason for choosing it.

## Cross-cutting invariants

**None.**

## Blast radius

- [tooltip-registry](tooltip-registry.md) — `_show` registers and both teardown paths unregister; a missed `remove` leaves a dismissed tooltip registered.
- [target-tracking](target-tracking.md) — `_show` starts `_trackTarget`; tracking stops when `_overlayEntry` is null, which only teardown sets.
- [transitions](transitions.md) — the animation this territory drives is what transitions read.
- [content](content.md) — `_show`'s content guard is one of content's three gates.
- [public-surface](public-surface.md) — `onShow` / `onHide` are the only way consumers observe visibility (ADR-0002).

## Known holes / open

- The two teardown paths duplicate their field list (above); nothing checks they agree.
