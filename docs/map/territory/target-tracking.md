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
- `_noteTarget` records each resolution. Hiding is a transition: `_sawVisibleTarget` must have been true, unless show intent holds the tooltip (#130: a trigger never shows it on a child clipped away entirely, so one found clipped at its first layout raced a scroll or the end of `waitDuration`, and hides). Every show resets it, a reverse-catch included (#101). The hide is a post-frame callback that re-resolves and hides only if the child is still clipped away — `OverlayPortalController.hide()` and the animation's listeners cannot run during layout. A `controller.show()` against an already-clipped child keeps the clamped edge anchor and keeps watching. The hide is `_hideClippedAway`, which is not a [Dismissal](../../../GLOSSARY.md#dismissal): it drops show intent first. A trigger does not show the tooltip while `_childClippedAway` holds; `_watchClippedChild` resolves the target after every frame while a trigger is inside, then re-derives once the child is visible (ADR-0010 as amended by #130; maintainer, 2026-11-15; details in [show-intent](show-intent.md)). The watch is the post-frame re-resolve ADR-0008 retired for a shown tooltip, kept for a hidden one: the overlay builder does not run while nothing is shown. The surviving reason is the transition rule — *a target never had cannot be lost*, now for the controller's show only; the 0.4.1 CHANGELOG's reason, "a tooltip already shown stays when the child leaves", went false when #36 made tracking hide it (`docs/agents/lessons.md`, Step 8).
- A pointer-anchored tooltip is still resolved per layout, but its frozen anchor makes the answer constant.
- When the child moves out from under a still cursor, Flutter's post-layout hit test fires `onExit` first; tracking matters for content scrolling under the cursor and for pointer-less shows.

## Code

- `lib/src/just_tooltip.dart` — `_buildOverlayChild`, `_noteTarget`, `_sawVisibleTarget`, `_resolveTarget`, `_hideClippedAway`, `_childClippedAway`, `_watchClippedChild`, `build` (`OverlayPortal.overlayChildLayoutBuilder`)
- Tests: `test/just_tooltip_tracking_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — builds the overlay child through `OverlayPortal.overlayChildLayoutBuilder`, the mechanism this package now uses too (ADR-0008); `RawTooltip` aims at the child's centre from `OverlayChildLayoutInfo` and does no clip walk, so it was no precedent for running the walk in layout — a spike measured that instead.

## Cross-cutting invariants

- [overlay-coordinate-space](../invariant/overlay-coordinate-space.md)
- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md)

## Blast radius

- [target-resolution](target-resolution.md) — tracking is that resolution re-run; its hide rule is `clippedAway`.
- [visibility-lifecycle](visibility-lifecycle.md) — tracking hides through `_hideClippedAway` → `_hide`, without the scheduler.
- [show-intent](show-intent.md) — the clip-away hide drops show intent, and `_childClippedAway` gates show intent (#130).
- [tooltip-registry](tooltip-registry.md) — the per-frame cost assumes at most one visible tooltip; a scoped registry allows one per registry.
- [demonstration](demonstration.md) — a header promising visible re-aim must use a child small enough to move inside its clip (#37).

## Known holes / open

- With several injected registries, several tooltips can track at once; the cost bound in the glossary assumes the shared one.
- `_watchClippedChild` resolves the target once per frame for each tooltip that is not shown, has a trigger inside, and either waits out `waitDuration` or was held back by its clipped child (it does not ask the other gates); `_watchingClippedChild` keeps it to one callback per tooltip (the first build started one per layout during the fade: 71 after a 600 ms `animateTo`, measured by #130's review), and the trigger bounds the count (one focus, and a pointer cannot rest on a clipped child), but frames a scroll elsewhere produces pay it too. Measured in a debug widget test (#130's run, one watch): scrolling another list for 1000 frames took a median 337 µs per frame with one such tooltip watching, against 314 µs with none (7 runs each); the tooltip's child sat under two `Padding`s in a `SingleChildScrollView`, so a deeper tree walks further. Re-run later under a machine load of about 8–10, the two were within noise (1210 against 1275, 1288 against 1293 µs).
