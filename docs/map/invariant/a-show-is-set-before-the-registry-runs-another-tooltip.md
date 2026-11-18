# A show is set before the registry runs another tooltip

## The fact

A registry call that can run another tooltip's code synchronously is made only once the calling
tooltip's own state is complete. Only `TooltipRegistry.show` does: it calls the previous holder's
`dismissTooltip` at once, and a zero `animationDuration` — or the holder's tickers being stopped,
since #104 — ends that holder's show and calls its
`onHide` inside the call, where a consumer can show or hide any tooltip. Every other call out of
the registry is deferred: `reviveTooltip` (from `remove`, `leave`, `wait`) reconciles in a
microtask, and the dismissal after `take` runs in a microtask through `dismissEvicted`
(`_syncRegistry`). Checkable: `_registry.show(this)` is the last statement of `_show` in
`lib/src/just_tooltip.dart`, and `git grep -n "dismissTooltip()\|reviveTooltip()" -- lib/src/tooltip_registry.dart`
lists every call out of the registry: `show`'s is the only one not reached from a microtask
(`dismissEvicted` runs from `_syncRegistry`'s microtask; `reviveTooltip` defers its own work).

The fact covers `_show`'s own state only. Its callers run after it returns, so after that foreign
code: `showTooltip` and the scheduler's `_emitShow` call `startAutoHide` once `_show` returns, and
a tooltip evicted or closed during its own show gets an auto-hide timer that way. On a closed one
it hides nothing; on an evicted one whose trigger is still inside it is the auto-hide left over
from before an eviction, which cancels the revival (ADR-0010 as amended by #143). Read in source
by #118's lens; a controller-shown case with `showDuration` was probed, a hover-shown one was not.

## Why it is cross-cutting

The registry ([tooltip-registry](../territory/tooltip-registry.md)) runs code of a tooltip other
than the caller, and that code reaches the consumer's `onHide`
([visibility-lifecycle](../territory/visibility-lifecycle.md)), which can call into
[programmatic-control](../territory/programmatic-control.md) on any tooltip, the caller included.
Whatever the caller had not set yet when it called the registry is what that code sees.

## Territories it holds in

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_show`, `_hide`, `_onAnimationStatus`, `_callOnHide`.
- [tooltip-registry](../territory/tooltip-registry.md) — `show`, `take`, `dismissEvicted`, `remove`, `keepsWaiting`.

## What a violation looks like

Two tooltips shown in one registry, the registry tracking one of them. #118: `_show` registered
before `_overlayController.show()` and `forward()`; an evicted zero-fade tooltip's `onHide`
showed a third tooltip, whose show evicted the caller while its animation still sat at
`dismissed`, so `_hide`'s `reverse()` changed no status, nothing ended the show, and the
caller went on to `forward()`. A later show dismissed only the third tooltip
The same order lost a `c.hide()` from that `onHide`, and a `c.show()` turning back C's
fade (`test/just_tooltip_eviction_test.dart`, group *the onHide of a tooltip whose fade ends at
once as it is evicted acts on the evicting tooltip as on any shown one*).

## Discovery history

- #118 — registering moved to the end of `_show`. Deferring `show`'s dismissal to a microtask
  instead was measured and rejected: it reorders an eviction and a close made in the same
  synchronous block, and an existing eviction test went red
  ([visibility-lifecycle](../territory/visibility-lifecycle.md)).

## Where it will recur

Any new step added to `_show` after the registry call, any new registry method that calls a
tooltip synchronously, and any new consumer callback that can run during a dismissal.
