# Target tracking

## What it is

The re-aim that keeps a visible child-anchored tooltip pointing at its child after a
scroll, resize, layout animation or insertion, and hides it when the child it was pointing at is
clipped away. Vocabulary: [Target Tracking](../../../GLOSSARY.md#target-tracking).

## Governing decisions

- [ADR-0008](../../adr/0008-the-tooltip-is-positioned-during-layout.md) — the target is resolved during layout, inside `OverlayPortal.overlayChildLayoutBuilder`; floor 3.32 (maintainer, 2026-10-24).

The behaviour itself was decided on #35; recorded in `GLOSSARY.md` and `CHANGELOG.md` 0.4.2.

## Design model

From the glossary, confirmed in source:

- `_buildOverlayChild` runs as the `overlayChildLayoutBuilder` builder, during the Overlay's layout, and calls `_resolveTarget` there; the builder re-runs whenever the child may have moved (a scroll and a sibling growing above were both measured), so the tooltip is on target in the same frame. The registry's one-visible rule bounds the work to one rect per layout.
- Until ADR-0008 `_trackTarget` re-resolved after every frame from a self-re-arming post-frame callback and `setState` when the rect differed from `_builtTargetRect`, so the tooltip trailed a moving child by one frame (measured: 40 px off on every frame of a 40 px/frame scroll). Re-aiming by post-frame callback was chosen on #35 over a `ScrollNotification` subscription, which catches only scrolls.
- `_noteTarget` records each resolution. Hiding is a transition: `_sawVisibleTarget` must have been true. The hide is a post-frame callback that re-resolves and hides only if the child is still clipped away — `OverlayPortalController.hide()` and the animation's listeners cannot run during layout. A show against an already-clipped child keeps the clamped edge anchor and keeps watching. The surviving reason is the transition rule — *a target never had cannot be lost*; the 0.4.1 CHANGELOG's reason, "a tooltip already shown stays when the child leaves", went false when #36 made tracking hide it (`docs/agents/lessons.md`, Step 8).
- A pointer-anchored tooltip is still resolved per layout, but its frozen anchor makes the answer constant.
- When the child moves out from under a still cursor, Flutter's post-layout hit test fires `onExit` first; tracking matters for content scrolling under the cursor and for pointer-less shows.

## Code

- `lib/src/just_tooltip.dart` — `_buildOverlayChild`, `_noteTarget`, `_sawVisibleTarget`, `_resolveTarget`, `build` (`OverlayPortal.overlayChildLayoutBuilder`)
- Tests: `test/just_tooltip_tracking_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — builds the overlay child through `OverlayPortal.overlayChildLayoutBuilder`, the mechanism this package now uses too (ADR-0008); `RawTooltip` aims at the child's centre from `OverlayChildLayoutInfo` and does no clip walk, so it was no precedent for running the walk in layout — a spike measured that instead.

## Cross-cutting invariants

- [overlay-coordinate-space](../invariant/overlay-coordinate-space.md)
- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md)

## Blast radius

- [target-resolution](target-resolution.md) — tracking is that resolution re-run; its hide rule is `clippedAway`.
- [visibility-lifecycle](visibility-lifecycle.md) — tracking calls `_hide` without the scheduler.
- [tooltip-registry](tooltip-registry.md) — the per-frame cost assumes at most one visible tooltip; a scoped registry allows one per registry.
- [demonstration](demonstration.md) — a header promising visible re-aim must use a child small enough to move inside its clip (#37).

## Known holes / open

- With several injected registries, several tooltips can track at once; the cost bound in the glossary assumes the shared one.
