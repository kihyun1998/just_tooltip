# Target tracking

## What it is

The per-frame re-aim that keeps a visible child-anchored tooltip pointing at its child after a
scroll, resize, layout animation or insertion, and hides it when the child it was pointing at is
clipped away. Vocabulary: [Target Tracking](../../../GLOSSARY.md#target-tracking).

## Governing decisions

**None.** Decided on #35; recorded in `GLOSSARY.md` and `CHANGELOG.md` 0.4.2.

## Design model

From the glossary, confirmed in source:

- `_trackTarget` re-arms itself with a post-frame callback while the `OverlayPortalController` is showing; it schedules no frame, so it idles until something else moves the child. The registry's one-visible rule bounds the work to one rect per frame.
- It rebuilds (`setState`) only when the resolved rect differs from `_builtTargetRect`.
- Hiding is a transition: `_sawVisibleTarget` must have been true. A show against an already-clipped child keeps the clamped edge anchor and keeps watching. The surviving reason is the transition rule — *a target never had cannot be lost*; the 0.4.1 CHANGELOG's reason, "a tooltip already shown stays when the child leaves", went false when #36 made tracking hide it (`docs/agents/lessons.md`, Step 8).
- A pointer-anchored tooltip still runs the loop but its frozen anchor makes the answer constant.
- When the child moves out from under a still cursor, Flutter's post-layout hit test fires `onExit` first; tracking matters for content scrolling under the cursor and for pointer-less shows.

## Code

- `lib/src/just_tooltip.dart` — `_trackTarget`, `_builtTargetRect`, `_sawVisibleTarget`, `_resolveTarget`
- Tests: `test/just_tooltip_tracking_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — builds the overlay child through `OverlayPortal.overlayChildLayoutBuilder`, whose child `overlay.dart` documents as "marked dirty for relayout every frame" — it follows a moving target by a different mechanism.

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
