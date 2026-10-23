# Overlay rebuilds are deferred to a post-frame callback

## The fact

Nothing marks the tooltip's `OverlayEntry` dirty synchronously from inside a build or a layout.
Every request that originates there goes through `WidgetsBinding.instance.addPostFrameCallback`.
Checkable: no `markNeedsBuild` on `_overlayEntry` is reachable from `build`, `didUpdateWidget`, or a
`SingleChildLayoutDelegate` callback without a post-frame hop.

## Why it is cross-cutting

Four mechanisms need the same hop for the same framework reason — the enclosing `Overlay` has
already built its entries — and none calls another:

- `_markOverlayDirty`, called from `didUpdateWidget` (config changed);
- `_trackTarget`, which re-arms itself post-frame (the target moved);
- the `onDirectionResolved` closure in `_buildOverlayEntry`, reporting a flip out of layout;
- the `onArrowCenterResolved` closure in `_buildOverlayEntry`, reporting the arrow centre out of layout.

`_applyQueuedShowAfterLayout` defers for a related but different reason (the child has no
`RenderBox` yet in `initState`). The shared assumption is build ordering, not shared code: moving
any one site inline trips the assertion without touching the others.

## Territories it holds in

- [live-configuration](../territory/live-configuration.md) — `_markOverlayDirty`.
- [target-tracking](../territory/target-tracking.md) — `_trackTarget`.
- [placement](../territory/placement.md) — `onDirectionResolved`, `onArrowCenterResolved` in `_buildOverlayEntry`.
- [painting](../territory/painting.md) — the arrow-centre override reaches `TooltipShapePainter` only through that deferred rebuild.

## What a violation looks like

`markNeedsBuild() called during build` in debug. In release the assertion is gone and the entry
renders a frame late or with stale config — a tooltip that seems to ignore a setting.

## Discovery history

- #47 — a shown tooltip ignored config changes; the fix asks for a rebuild from `didUpdateWidget`, deferred for this reason (`GLOSSARY.md` → Target Tracking, last paragraphs; ADR-0004 context issues).
- #35 — per-frame re-aim, written as a self-re-arming post-frame callback (`GLOSSARY.md` → Target Tracking).
- Reading, 2026-10-23: the two layout callbacks guard on `_overlayEntry?` only, the other two on `mounted`. `_hideImmediate` nulls `_overlayEntry` in `dispose`, which is what makes the `?.` sufficient today.

## Where it will recur

Any new live-resolved field, tracker, or callback out of layout or paint that wants the overlay to
change. If the code runs inside build or layout and touches the entry, it must defer — and should
decide whether `?.` on the entry or `mounted` is its guard.
