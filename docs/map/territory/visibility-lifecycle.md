# Visibility lifecycle

## What it is

Owns intent (`_isShowing`) and reconciles it with render state (`AnimationController.status`):
showing and hiding the `OverlayPortal`, starting and reversing the animation, the reverse-catch,
and teardown on deactivate/dispose. Vocabulary: [Intent vs Render State](../../../GLOSSARY.md#intent-vs-render-state).

## Governing decisions

- [ADR-0001](../../adr/0001-scheduler-separates-intent-from-render-state.md) — intent and render state stay two facts; the reverse-catch stays in the State. Not to be re-litigated.
- [ADR-0005](../../adr/0005-the-tooltip-draws-through-an-overlay-portal.md) — the tooltip is an `OverlayPortal`'s overlay child, built in the State's context.

## Design model

From ADR-0001, confirmed in source:

- `_show` is the only path that opens: refuses without content, sets `_isShowing`, freezes the anchor, registers with the registry (dismissing others), shows the `OverlayPortalController`, starts tracking, `forward()`, `onShow`.
- `_hide` only `reverse()`s. The overlay is hidden when the animation reaches `dismissed` (`_onAnimationStatus`), which also clears per-show state and calls `onHide`.
- `_handleShowRequest`: a show request while `_isShowing` and reversing re-`forward()`s (reverse-catch) instead of opening again.
- `_hideImmediate` (deactivate, dispose) tears down without animation.
- `_hideOverlay` hides the portal. `OverlayPortalController.hide()` asserts during build and layout (`SchedulerPhase.persistentCallbacks`) — where `deactivate` runs, and where `didUpdateWidget` can reverse an animation already at `0.0` — so there it waits for a post-frame callback and skips the hide if `_isShowing` is true again. It also skips a controller that is not showing: a detached, hidden controller asserts on `hide()` (Flutter 3.13 `widgets/overlay.dart`). Measured: before the deferral, 82 of 200 tests failed on the `deactivate` assertion.
- A `forward()` can cover a `reverse()` that has not left `0.0`, so "the tooltip is visible" proves nothing about whether a hide happened; #39's tracking bug passed `findsOneWidget` this way and surfaced only when the test asserted `onHide` was *not* called (`docs/agents/lessons.md`, Step 5).

From reading only: `_onAnimationStatus` and `_hideImmediate` clear the same per-show fields (`_isShowing`, `_sawVisibleTarget`, `_frozenAnchor`, `_resolvedDirection`, `_arrowCenterOffset`, registry, overlay) by hand; a new per-show field must be added to both.

## Code

- `lib/src/just_tooltip.dart` — `_isShowing`, `_overlayController`, `_show`, `_hide`, `_hideImmediate`, `_hideOverlay`, `_onAnimationStatus`, `_handleShowRequest`, `_animationController`, `_updateCurvedAnimation`, `deactivate`, `dispose`
- Tests: `test/just_tooltip_test.dart`, `test/just_tooltip_overlay_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `OverlayPortal.overlayChildLayoutBuilder` (3.32+) with an `OverlayPortalController`, shown when the animation leaves `dismissed` and hidden when it reaches it. This package uses it too since ADR-0008 (floor 3.32); ADR-0005 had kept the plain `OverlayPortal` for the 3.13 floor.

## Cross-cutting invariants

**None.**

## Blast radius

- [tooltip-registry](tooltip-registry.md) — `_show` registers and both teardown paths unregister; a missed `remove` leaves a dismissed tooltip registered.
- [target-tracking](target-tracking.md) — the target is resolved while the `OverlayPortalController` shows the overlay child; a clipped-away child is hidden through `_hide` after the frame.
- [transitions](transitions.md) — the animation this territory drives is what transitions read.
- [content](content.md) — `_show`'s content guard is one of content's three gates.
- [semantic-tooltip](semantic-tooltip.md) — `_show` announces the tooltip's text.
- [show-intent](show-intent.md) — `_show` lists the tooltip for Escape; both teardown paths unlist it.
- [public-surface](public-surface.md) — `onShow` / `onHide` are the only way consumers observe visibility (ADR-0002).

## Known holes / open

- The two teardown paths duplicate their field list (above); nothing checks they agree.
