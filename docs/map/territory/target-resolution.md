# Target resolution

## What it is

Decides what rect the tooltip points at: the child's [Visible Rect](../../../GLOSSARY.md#visible-rect)
(the child intersected with every ancestor clip), or, for `TooltipAnchor.pointer`, a zero-size rect
at the pointer position frozen at show time. Vocabulary: [Anchor](../../../GLOSSARY.md#anchor).

## Governing decisions

**None.** No ADR decides the anchor or the clip walk; the decisions were made on #21 (pointer anchor), #33 (visible rect) and #35 (clipped-away behaviour) and are recorded in `GLOSSARY.md` and `CHANGELOG.md` 0.4.0–0.4.2.

## Design model

From the glossary and changelog, confirmed in source:

- `_frozenAnchor` is set in `_show` from `_anchorCandidate` only when `anchor == pointer`; a pointer target is `Rect.fromCenter(overlayBox.globalToLocal(anchor), 0, 0)`. With no known pointer, a pointer-anchored tooltip falls back to the visible rect.
- `_anchorCandidate` holds the position the child's current `MouseRegion` last reported, or the down position of the last tap that landed on the child — also one the tap batch did not let toggle this tooltip, because a nested tooltip took it. It is cleared where `_pointerInside` is: on `onExit`, and in `didUpdateWidget` when `enableHover` turns off or `tap` changes, since a removed region sends no `onExit` ([show-intent](show-intent.md), #138). Each tap mode writes it when the tap lands, so a tap pressed across that clear still anchors at its down position ([tap-trigger](tap-trigger.md)).
- A frozen pointer anchor reports `clippedAway` from the child (`_resolveChildTarget`) unless `_pointerInside` holds (#144; [target-tracking](target-tracking.md)). The target stays the frozen point until the hide. Where it shows again follows the rules above (implementer's derivation): once the fade has ended, `_endShow` has cleared `_frozenAnchor`, and a mouse pointer that left took `_anchorCandidate` with it, so it anchors at the visible rect (pinned); a landed tap's position, which outlives the tap (*Known holes* below), anchors it there instead (measured by #144's lens: x 100, the tap, against the child's centre 60); and a child back during the fade turns the fade back within the same show, keeping the frozen anchor (measured by #144's review).
- The child rect is `MatrixUtils.transformRect(getTransformTo(overlayBox), Offset.zero & size)`, not `localToGlobal & size`, so a `Transform.scale` yields the right extent.
- `_ancestorClip` walks parents up to the Overlay's box, calls `parent.describeApproximatePaintClip(child)` passing each parent's actual child (a viewport narrows the parameter to `RenderSliver`), transforms each clip from the parent's space, and intersects.
- A fully clipped child resolves to its centre clamped into the clip, with `clippedAway: true`: a `controller.show()` anchors at the clip edge, which at least points the right way, and tracking hides. Refusing the controller's show was rejected on #36 as inconsistent (a tooltip already on screen stays put for a frame when its child scrolls out) and as needing a return value nobody asked for; these reasons stood in `_resolveTarget`'s dartdoc until #130. Since #130 a trigger does not show the tooltip on a fully clipped child (`_childClippedAway`, a gate of show intent; ADR-0010 as amended by #130, maintainer), so the clamped anchor serves the controller's show and a race where a trigger's show meets a child clipped by its first layout, which `_noteTarget` then hides.
- A child with no area — a `Focus` around a `SizedBox.shrink`, say — always has an empty intersection, so it counts as shown while it lies within the clip (the intersection's extent is not negative) and as clipped away once outside. Before #130 an empty intersection was clipped away; a shown tooltip's tracking never hid it then (it had never seen a visible target), but #130's gate would have kept a trigger from ever showing it (measured by #130's re-review: focus on a zero-size child in a scroll view showed on b235b85 and not on the first redesign; pinned).
- A child whose transform to the Overlay is degenerate — one a lazy list keeps alive off screen gets a zero paint transform (`RenderSliverMultiBoxAdaptor`, Flutter 3.47.1) — maps to a non-finite rect, whose intersection is not empty either; it resolves as clipped away, anchored at the clip's centre. Before #130 nothing read the rect of a hidden tooltip's child; #130's lens measured the new watch reading it as visible and reopening a focus tooltip on a `TextField` kept alive in a `ListView`, with three framework assertions in the frame (pinned).
- A viewport reports a clip whenever `clipBehavior != Clip.none`, so most scrolled children are clipped.

## Code

- `lib/src/just_tooltip.dart` — `_resolveTarget`, `_resolveChildTarget`, `_resolveTargetRect`, `_ancestorClip`, `_frozenAnchor`, `_anchorCandidate`
- `lib/src/enums.dart` — `TooltipAnchor`
- Tests: `test/just_tooltip_anchor_test.dart`, `test/just_tooltip_clipped_target_test.dart`, `test/just_tooltip_overlay_space_test.dart`

## Reference behaviour

- Flutter 3.41.9 `rendering/object.dart` — `RenderObject.describeApproximatePaintClip`, returning the clip in the parent's coordinate space; `rendering/viewport.dart` narrows the child parameter to `RenderSliver` (read on #34, `docs/agents/lessons.md` Step 3).
- Flutter 3.41.9 `widgets/raw_tooltip.dart` — targets the whole child (`_TooltipPositionDelegate` gets `target` + `targetSize`); no clip walk (`describeApproximatePaintClip` does not occur in it). The visible-rect anchor is a deliberate divergence from that example (#33).

## Cross-cutting invariants

- [overlay-coordinate-space](../invariant/overlay-coordinate-space.md)
- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — a pointer position the region recorded must go when the region does, since a removed region sends no `onExit` (#138).
- [sdk-floor-covers-api-use](../invariant/sdk-floor-covers-api-use.md) — `_ancestorClip` reads `RenderObject.parent` as `RenderObject?` (Flutter ≥ 3.13); since ADR-0008 it runs during layout, inside `overlayChildLayoutBuilder` (floor 3.32).

## Blast radius

- [placement](placement.md) — the rect is the delegate's only input about the target; a zero-size rect changes what `TooltipAlignment` means.
- [target-tracking](target-tracking.md) — it re-runs this resolution every frame and hides on `clippedAway`; `_childClippedAway` reads it to gate show intent (#130).
- [demonstration](demonstration.md) — the spike header describes anchor behaviour as a specification (#37).
- [public-surface](public-surface.md) — `TooltipAnchor`'s dartdoc promises re-aim and hide.

## Known holes / open

- A landed tap's position outlives the tap: on touch, and with `enableHover` off, a later `controller.show()` or keyboard-focus show anchors where the last tap went down, however long ago, unless `enableHover` turns off or `tap` changes in between. Turning `enableHover` back on does not clear it when the pointer is off the child, since the new region never gets `onEnter` and so never `onExit` (a mouse tap at x=80 with hover off, the pointer moved away, hover on, `show()`: x=80, against the child's centre 350, on 9f7e720 and after #138; measured by #138's completeness read). Since #138 the same tap's position is cleared if `enableHover` turns off or `tap` changes after it. Pre-existing; how long a tap's position should live is undecided (#138 left it as it was).
- No governing record for anchor semantics, re-decided across #21, #33, #35.
- "Approximate" is the SDK's own word for the clip; what that costs at tooltip precision has never been measured.
