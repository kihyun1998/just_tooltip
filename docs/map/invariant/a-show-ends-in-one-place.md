# A show ends in one place

## The fact

Every way a show ends goes through `_endShow`: the fade reaching `dismissed`
(`_onAnimationStatus`, which the covered hide's `_finishCoveredHideAfterFrame` also reaches) and
the teardown without animation (`_hideImmediate`, from `deactivate` and `dispose`). What a show
leaves behind — `_isShowing`, `_sawVisibleTarget`, `_frozenAnchor`, `_resolvedDirection`,
`_arrowCenterOffset`, the registry's holder — whose removal revives the tooltips the registry
evicted — the `_shown` and `_pending` entries, and the overlay — is undone there, once. `_announcedShow` and
`_showIntent` end differently on each path (one calls `onHide`, the other does not), so the
callers clear them. Checkable:
`_isShowing = false` appears in `lib/src/just_tooltip.dart` only inside `_endShow` (and at the
field's declaration).

## Why it is cross-cutting

The two paths start in different places and run at different times: the fade ends from a ticker,
or inside `reverse()` when it had nothing left to animate (once measured inside `didUpdateWidget`,
#103); the teardown runs inside a build (`deactivate`), with no animation status after it since
`deactivate` stops the controller (#109). Each end touches state owned
elsewhere:

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_isShowing`, the anchor and
  arrow fields, the overlay.
- [tooltip-registry](../territory/tooltip-registry.md) — the holder, and reviving the evicted tooltips.
- [show-intent](../territory/show-intent.md) — `_shown`, `_pending`, and the reconcile a revival runs.

## Territories it holds in

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_endShow`, `_onAnimationStatus`, `_hideImmediate`.
- [show-intent](../territory/show-intent.md) — `reviveTooltip`, `_untrackShown`, `_setPending`.
- [tooltip-registry](../territory/tooltip-registry.md) — `TooltipRegistry.remove`, which revives only when the entry held the place.

## What a violation looks like

A step added to one path only works for the hides that take that path. #111: reviving evicted
tooltips sat in the fade path alone, so when the tooltip that took another's place left the tree
while shown, the evicted one stayed hidden with its trigger still inside — breaking ADR-0010's
"a tooltip hidden by the registry comes back". The same shape would leave a field set for the next
show, or a tooltip registered or listed for Escape after it is gone.

## Discovery history

- #109 — `deactivate` began stopping the animation, so a tooltip leaving the tree mid-fade no
  longer reached `dismissed`; the fade path's revival stopped covering it.
- #111 — the map had listed the hand-duplicated field lists as a known hole; the revival was the
  step missing from one of them. Both paths were folded into `_endShow`, which revives only when
  the tooltip was shown or fading out.
- #113 — the revival moved into the registry: `_endShow` still reaches it on both paths, through
  `TooltipRegistry.remove`, which now revives only when the tooltip ending its show held the
  place in that registry.

## Where it will recur

Any new per-show field or per-show side effect, and any new path that ends a show (a new hide
without animation, a new status the controller can end on).
