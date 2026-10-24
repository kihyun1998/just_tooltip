# 0008 — The tooltip is positioned during layout

- **Status:** Accepted
- **Date:** 2026-10-24
- **Context issue:** [#83](https://github.com/kihyun1998/just_tooltip/issues/83) (position the tooltip during layout with `overlayChildLayoutBuilder`)
- **Amends:** [ADR-0005](0005-the-tooltip-draws-through-an-overlay-portal.md), its "plain `OverlayPortal`" bullet and the 3.13 floor it kept

## Context

ADR-0005 drew the tooltip through the plain `OverlayPortal` constructor to keep the Flutter 3.13 floor. The target was resolved during **build**, and [Target Tracking](../../GLOSSARY.md#target-tracking) re-aimed it from a self-re-arming post-frame callback, `_trackTarget`. That callback compared the resolved rect with the one it last built against and called `setState`.

So a moving child was followed one frame late. Measured on Flutter 3.47.1 with a tooltip shown by its controller in a `ListView`, `jumpTo(+40)` per frame: the gap between child and tooltip went from 16 to 56 on every scrolling frame, and returned to 16 one frame after the scroll stopped. Hover tooltips do not show it, since they hide on `onExit` when the child leaves a still cursor, and neither do pointer anchors, which are frozen. Tooltips shown by a controller or a tap do.

`OverlayPortal.overlayChildLayoutBuilder` (first in Flutter 3.32.0, by `git tag --contains`) runs its builder during layout. The open question was whether the ancestor clip walk behind the [Visible Rect](../../GLOSSARY.md#visible-rect) is correct when run there. `RawTooltip` uses the builder but does no clip walk, so it settles nothing. A spike on Flutter 3.47.1 in debug answered it:

- A copy of `_ancestorClip` inside the builder covered vertical and horizontal `ListView`s, each with and without `Transform.scale(0.5)`, for three scrolled frames each. Its result equalled the same walk after the frame in all 12 frames, raised no exceptions and put the tooltip on its target in the same frame.
- A move that is not a scroll, a sibling above growing from 50 to 120, re-ran the builder and was correct in the same frame.
- `OverlayPortalController.hide()` from inside the builder asserts (`schedulerPhase != persistentCallbacks`).

## Decision

The tooltip is the overlay child of `OverlayPortal.overlayChildLayoutBuilder`, and its target is resolved inside that builder, during the Overlay's layout. `_trackTarget` and `_builtTargetRect` are removed. The floor rises to Flutter 3.32.0 (Dart 3.8.0) in 0.5.0.

This is the maintainer's call (2026-10-24), made on the measurements above and chosen over two other options it was shown: deferring to 0.6.0, and keeping the lag with the 3.13 floor. Consumers already move from `^0.4.4` to `^0.5.0`, so the floor rises in that same breaking release rather than in a second one.

- **Hiding a clipped-away child still waits a frame.** The builder records whether the child shows (`_noteTarget`). Once a child it pointed at is clipped away, a post-frame callback re-resolves the target and hides only if the child is still clipped away and the tooltip is still showing. It derives from the assert above.
- **The flip and the arrow centre still leave layout through a post-frame rebuild.** They depend on the tooltip's own size, which only the position delegate knows. This was derived from the code, not measured.
- **`OverlayChildLayoutInfo` is not read.** The target goes through the same `_resolveTarget` used before, which needs the clip walk, and the spike measured that path.

## Consequences

- **Positive:** a shown tooltip follows its child in the same frame, after a scroll, a resize, a layout animation or an insertion above it. No callback re-arms itself every frame while a tooltip is up.
- **Breaking:** apps and packages on Flutter below 3.32 cannot take 0.5.0. flutter_folderview and flutter_table_plus already declare `>=3.32.0`. flutter_password_input declares only `sdk: ">=3.4.0"` and has to add the floor.
- **Kept:** ADR-0005's content cut, `SelectionContainer.disabled` and deferred hide. The per-frame cost is still one rect per visible tooltip, now spent in layout.
