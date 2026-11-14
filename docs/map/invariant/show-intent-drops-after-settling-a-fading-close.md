# Show intent drops after settling a fading close

## The fact

Whether a close was a [Dismissal](../../../GLOSSARY.md#dismissal) — a tap, the auto-hide, a
controller, anything but the trigger leaving — is read once, when the fade reaches `dismissed`:
show intent still set there means a close made while the tooltip wanted to show
(`_onAnimationStatus` → `_settleClose`). So every site that drops show intent while the tooltip may
be fading out goes through `_dropShowIntent`, which settles that close first: the reconcile's
transition to `false`, the content-loss hide in `didUpdateWidget`, `_syncCovered` and
`dismissTooltip`. Checkable: `_showIntent = false` appears in `lib/src/just_tooltip.dart` only
inside `_dropShowIntent`, `_settleClose`, `_dismissByUser` (which sets `_dismissed` itself) and
`_hideImmediate` (teardown, which clears `_dismissed` too), besides the field's declaration. The one site that sets show intent
outside the reconcile, `_closeOnRequest` (the scheduler's `onClose` and `hideTooltip`) on an evicted
tooltip fading out, puts back the evidence the eviction took, so that same settle reads it; once
that fade has ended it sets `_dismissed` itself on one with no show intent, since no settle is left
to come.

## Why it is cross-cutting

The drops come from four territories, each with its own reason to drop show intent, and none of
them is the close: [nesting-suppression](../territory/nesting-suppression.md) through the
reconcile, [content](../territory/content.md) in `didUpdateWidget`,
[Covered](../../../GLOSSARY.md#covered) in `_syncCovered`, and the
[tooltip-registry](../territory/tooltip-registry.md) in `dismissTooltip`. The close they can land
on was begun elsewhere — the [tap trigger](../territory/tap-trigger.md), the scheduler's auto-hide
([visibility-scheduling](../territory/visibility-scheduling.md)), the
[controller](../territory/programmatic-control.md) — and its evidence lives only in `_showIntent`
until the fade ends.

## Territories it holds in

- [show-intent](../territory/show-intent.md) — `_dropShowIntent`, `_settleClose`, `_reconcileShowIntent`, `_syncCovered`, `_onAnimationStatus`.
- [content](../territory/content.md) — the content-loss hide in `didUpdateWidget`.
- [tooltip-registry](../territory/tooltip-registry.md) — `dismissTooltip`.
- [programmatic-control](../territory/programmatic-control.md) — `hideTooltip`, `_closeOnRequest`.
- [visibility-scheduling](../territory/visibility-scheduling.md) — the scheduler's `onClose` is `_closeOnRequest`.

## What a violation looks like

A tooltip a close ended comes back with its trigger never leaving, but only when the drop lands
during the fade; the same drop after the fade leaves it closed. #126 measured it for a nested
tooltip under the pointer, content going and returning, and a covering route with focus inside,
each 60 ms into a 200 ms fade (`test/just_tooltip_dismissal_test.dart`), and #117 for an
eviction (`test/just_tooltip_eviction_test.dart`).

## Discovery history

- #117 — `dismissTooltip` dropped show intent without settling, so a tooltip evicted during a
  tap's fade came back on its revival. Fixed at that one site.
- #126 — the same erasure at the other drop sites; all four now go through `_dropShowIntent`. The
  eviction's own drop erased the evidence for a close that came after it, so `hideTooltip` puts it
  back for an evicted tooltip that would otherwise want to show.
- #129 — a tap or the auto-hide during the eviction's fade, and any of these closes after it, still
  found no evidence; the scheduler's `onClose` (tap, auto-hide) now goes through the same
  `_closeOnRequest`, which marks a hidden evicted tooltip dismissed directly. Its `onHide` (the
  trigger leaving, the bridge) stays `_hide`.

## Where it will recur

Any new gate in show intent whose transition to `false` is handled outside the reconcile, any
new close that does not go through `_hide()` while show intent is set, and any new close that can
reach an evicted tooltip without going through `_closeOnRequest`.
