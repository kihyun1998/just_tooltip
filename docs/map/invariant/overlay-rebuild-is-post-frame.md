# Overlay rebuilds are deferred to a post-frame callback

## The fact

Nothing rebuilds the tooltip's overlay, or shows or hides it, synchronously from inside a layout
or (for showing and hiding) a build. Every request that originates there goes through
`WidgetsBinding.instance.addPostFrameCallback`. Checkable: no `setState` is reachable from a
`SingleChildLayoutDelegate` callback, and no `OverlayPortalController.show`/`hide` from `build`,
`didUpdateWidget` or `deactivate`, without a post-frame hop.

## Why it is cross-cutting

Four mechanisms need the hop, for the framework's build-phase rules, and none calls another:

- `_trackTarget`, which re-arms itself post-frame (the target moved);
- `_rebuildAfterLayout`, called by the `onDirectionResolved` closure in `_buildOverlayChild`, reporting a flip out of layout;
- the same, called by the `onArrowCenterResolved` closure, reporting the arrow centre out of layout;
- `_hideOverlay`, which defers a hide asked for during build or layout (`OverlayPortalController.hide()` asserts in `SchedulerPhase.persistentCallbacks`).

Configuration changes no longer need it: the overlay is built in the State's own `build`
(ADR-0005), where `_markOverlayDirty` used to mark an `OverlayEntry` dirty after the frame.

`_applyQueuedShowAfterLayout` defers for a related but different reason (the child has no
`RenderBox` yet in `initState`). The shared assumption is build ordering, not shared code: moving
any one site inline trips the assertion without touching the others.

## Territories it holds in

- [target-tracking](../territory/target-tracking.md) — `_trackTarget`.
- [placement](../territory/placement.md) — `onDirectionResolved`, `onArrowCenterResolved` in `_buildOverlayChild`.
- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_hideOverlay`.
- [painting](../territory/painting.md) — the arrow-centre override reaches `TooltipShapePainter` only through that deferred rebuild.

## What a violation looks like

`setState() or markNeedsBuild() called during build` from a layout callback, or the
`SchedulerPhase.persistentCallbacks` assertion in `_OverlayPortalState.hide`/`show`, in debug. In
release the assertion is gone and the overlay renders a frame late or with stale config — a tooltip
that seems to ignore a setting.

## Discovery history

- #47 — a shown tooltip ignored config changes; the fix asks for a rebuild from `didUpdateWidget`, deferred for this reason (`GLOSSARY.md` → Target Tracking, last paragraphs; ADR-0004 context issues).
- #35 — per-frame re-aim, written as a self-re-arming post-frame callback (`GLOSSARY.md` → Target Tracking).
- Reading, 2026-10-23: the two layout callbacks guarded on `_overlayEntry?` only, the other two on `mounted`. Since ADR-0005 all of them guard on `mounted` (`_hideOverlay` on `_isShowing`).
- #72 / ADR-0005 — moving to `OverlayPortal` removed the config-change hop and added the hide hop: without it, 82 of 200 tests failed on `hide()` from `deactivate`.

## Where it will recur

Any new live-resolved field, tracker, or callback out of layout or paint that wants the overlay to
change, or that shows or hides it. If the code runs inside build or layout, it must defer — and
guard on `mounted`.
