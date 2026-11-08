# Visibility lifecycle

## What it is

Owns intent (`_isShowing`) and reconciles it with render state (`AnimationController.status`):
showing and hiding the `OverlayPortal`, starting and reversing the animation, the reverse-catch,
and teardown on deactivate/dispose. Vocabulary: [Intent vs Render State](../../../GLOSSARY.md#intent-vs-render-state).

## Governing decisions

- [ADR-0001](../../adr/0001-scheduler-separates-intent-from-render-state.md) — intent and render state stay two facts; the reverse-catch stays in the State. Not to be re-litigated.
- [ADR-0005](../../adr/0005-the-tooltip-draws-through-an-overlay-portal.md) — the tooltip is an `OverlayPortal`'s overlay child, built in the State's context.
- [ADR-0011](../../adr/0011-a-covered-tooltip-hides.md) — a covered tooltip hides and does not show; a covered fade its stopped tickers hold is ended at once (maintainer, 2026-11-08).

## Design model

From ADR-0001, confirmed in source:

- `_show` is the only path that opens: refuses without content or while [Covered](../../../GLOSSARY.md#covered), sets `_isShowing`, freezes the anchor, registers with the registry (dismissing others), shows the `OverlayPortalController`, starts tracking, `forward()`, `onShow`.
- `_hide` only `reverse()`s. The overlay is hidden when the animation reaches `dismissed` (`_onAnimationStatus`), which also clears per-show state and calls `onHide`.
- **The reverse-catch is in `_show`**, for the scheduler's requests and the controller's alike (#101): a tooltip `_fadingOut` (shown, animation reversing) passes the same content and Covered gates, takes the registry back, re-tracks for Escape, leaves `_evicted`, resets `_sawVisibleTarget` and `forward()`s — without showing the portal again, re-freezing the anchor, announcing or calling `onShow` (no `onHide` was called). Before #101 the catch sat in the scheduler's handler, and `showTooltip` returned on `_isShowing`, which stays true through the reverse. Resetting `_sawVisibleTarget` matters for a child scrolled out of sight: a caught tooltip that kept it `true` was hidden again by the next layout, while a show after the fade waits at the clip edge (#101's review, pinned in `test/just_tooltip_fading_test.dart`). Keeping the anchor keeps a tooltip that never left the screen where it is.
- `_hideImmediate` (deactivate, dispose) tears down without animation.
- A covered hide (`_syncCovered`) calls `_hide` from a post-frame callback: the route's notice arrives during a build, and a fade with nothing left to animate reaches `dismissed` inside `reverse()`, which ran `onHide` inside the build (measured by #100's lens read). Under an opaque route the tooltip's tickers stop once the route below goes offstage, about 500 ms after the push in a widget test; a fade still running then holds `onHide` until the pop. `_finishCoveredHideAfterFrame` sets the value to `0.0` after the frame when the tickers have stopped mid-fade — only for a covered hide; see [a-muted-ticker-holds-a-fade](../invariant/a-muted-ticker-holds-a-fade.md) for the hides it does not reach.
- A tooltip whose own route is popped gets no notice from a plain pop (`ModalRoute.didPop` calls `changedInternalState` only for a local-history entry), so `deactivate` takes it as before; a replacement does notify (ADR-0011).
- `_hideOverlay` hides the portal. `OverlayPortalController.hide()` asserts during build and layout (`SchedulerPhase.persistentCallbacks`) — where `deactivate` runs, and where `didUpdateWidget` can reverse an animation already at `0.0` — so there it waits for a post-frame callback and skips the hide if `_isShowing` is true again. It also skips a controller that is not showing: a detached, hidden controller asserts on `hide()` (Flutter 3.13 `widgets/overlay.dart`). Measured: before the deferral, 82 of 200 tests failed on the `deactivate` assertion.
- A `forward()` can cover a `reverse()` that has not left `0.0`, so "the tooltip is visible" proves nothing about whether a hide happened; #39's tracking bug passed `findsOneWidget` this way and surfaced only when the test asserted `onHide` was *not* called (`docs/agents/lessons.md`, Step 5).

From reading only: `_onAnimationStatus` and `_hideImmediate` clear the same per-show fields (`_isShowing`, `_sawVisibleTarget`, `_frozenAnchor`, `_resolvedDirection`, `_arrowCenterOffset`, registry, overlay) by hand; a new per-show field must be added to both.

## Code

- `lib/src/just_tooltip.dart` — `_isShowing`, `_overlayController`, `_show`, `_hide`, `_hideImmediate`, `_hideOverlay`, `_onAnimationStatus`, `_fadingOut`, `_animationController`, `_updateCurvedAnimation`, `deactivate`, `dispose`, `_syncCovered`, `_finishCoveredHideAfterFrame`, `_tickerEnabled`
- Tests: `test/just_tooltip_test.dart`, `test/just_tooltip_overlay_test.dart`, `test/just_tooltip_covered_test.dart`, `test/just_tooltip_fading_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `OverlayPortal.overlayChildLayoutBuilder` (3.32+) with an `OverlayPortalController`, shown when the animation leaves `dismissed` and hidden when it reaches it. This package uses it too since ADR-0008 (floor 3.32); ADR-0005 had kept the plain `OverlayPortal` for the 3.13 floor.

## Cross-cutting invariants

- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md)
- [a-muted-ticker-holds-a-fade](../invariant/a-muted-ticker-holds-a-fade.md)

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
