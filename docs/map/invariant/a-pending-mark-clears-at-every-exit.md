# A pending mark clears at every exit

## The fact

A State field that marks "something has happened and its effect has not run yet" is cleared on
every path that ends that wait, not only on the path the mark was written for. In
`lib/src/just_tooltip.dart`:

- `_revivalPending` stands for the gap between `TooltipRegistry.remove` emptying its evicted set
  and the revival's microtask in `reviveTooltip`. It has two exits: the reconcile
  (`_reconcileShowIntent` clears it at its top) and `keepsWaiting` turning the revival back (the
  microtask clears it, and from there `isEvicted` stands for the wait).
- `_revivalWaiting` stands for a wait the revival began. It ends when the tooltip stops being
  pending (`_setPending(false)`: every show, the show ending, `_dismissByUser`) or when an act's
  reconcile takes the wait over (`if (act)` in `_reconcileShowIntent`).
- `_pointerAct` and `_focusAct` stand for an act not yet reconciled. Every site that sets one also
  schedules a reconcile (`onEnter`, `_onFocusChanged`, and `_claimAncestors` through
  `_setSuppressor`, which reconciles on a change), and the reconcile clears both at its top.

Checkable: `git grep -n "_revivalPending =\|_revivalWaiting =\|_pointerAct =\|_focusAct =" -- lib`
lists every write; each set has the exits above.

## Why it is cross-cutting

The exits sit in different territories from the write: `_revivalPending` is written for the
[tooltip-registry](../territory/tooltip-registry.md)'s gap and read by `_closeOnRequest`
([programmatic-control](../territory/programmatic-control.md), the scheduler's `onClose` in
[visibility-scheduling](../territory/visibility-scheduling.md)); `_revivalWaiting` is cleared from
`_show` and `_endShow` ([visibility-lifecycle](../territory/visibility-lifecycle.md)) through
`_setPending`. A path that ends the wait without passing the clearing site leaves the mark
stale, and a reader in another territory then acts on a wait that is over.

## Territories it holds in

- [show-intent](../territory/show-intent.md) — `_reconcileShowIntent`, `reviveTooltip`, `_closeOnRequest`, `_setPending`.
- [tooltip-registry](../territory/tooltip-registry.md) — `remove`, `keepsWaiting`, `take`.
- [nesting-suppression](../territory/nesting-suppression.md) — `_claimAncestors` sets the acts.

## What a violation looks like

The mark survives into a state where its reader's assumption no longer holds, and behaviour
depends on which path ended the wait. #159: a revival turned back by `keepsWaiting` left
`_revivalPending` set; a later `controller.show()` or tap took the tooltip out of the evicted set
without a reconcile, and a `controller.hide()` or tap with the pointer resting was taken as a
close of a tooltip still waiting for its revival (`test/just_tooltip_eviction_test.dart`, group
*a tooltip that shows after a revival the registry turned back …*). A survived mutation on one
exit does not show the mark is harmless on the others: removing the reconcile's clear stays green,
since a reconciled, non-evicted tooltip has `_showIntent == _openToShow`.

## Discovery history

- #143 — `_revivalWaiting` was set at a transition and not revisited by a Tab during the wait;
  an act's reconcile now clears it.
- #159 — `_revivalPending` was cleared only by the reconcile; the turned-back branch now clears
  it too.

## Where it will recur

Any new mark set in one place and read in another (a pending revival, an act, a deferred close),
and any new path out of the evicted set or the pending set that skips the reconcile.
