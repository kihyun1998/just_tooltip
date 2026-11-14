# A muted ticker holds a fade

## The fact

A `reverse()` on the tooltip's `AnimationController` makes no progress while the tooltip's tickers
are muted, so `_onAnimationStatus` does not reach `dismissed` and `onHide` is not called until they
run again. An opaque route mutes the route below it: in a widget test (Flutter 3.47.1) a pushed
`MaterialPageRoute` took about 500 ms to come in, and from then on `TickerMode` was off for the
tooltip; a 2 s fade started at the push stopped there and `onHide` came only after the pop
(#100's build). Any `TickerMode(enabled: false)` a consumer places above the tooltip does the
same. Checkable: every path that hides a tooltip which may be offstage either finishes the
animation itself or accepts that `onHide` waits.

## Why it is cross-cutting

Every hide goes through `_hide` (`reverse()`), and its callers do not call each other:

- `_syncCovered` — a covered hide. Handled: `_finishCoveredHideAfterFrame` sets the value to `0.0`
  after the frame once the tickers have stopped (ADR-0011).
- `hideTooltip` — `controller.hide()`, which can reach a tooltip under an opaque route when
  `hideWhenCovered` is `false`.
- the scheduler's auto-hide (`startAutoHide`, `onClose: _closeOnRequest`, which hides through
  `_hide`) — a `Timer`, which fires while the route is offstage.
- the content-loss hide in `didUpdateWidget`, `dismissTooltip` (the registry) and `_dismissByUser`
  (Escape).

Only the first is measured; the others share the mechanism and were read, not run.

## Territories it holds in

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_hide`, `_onAnimationStatus`, `_finishCoveredHideAfterFrame`.
- [programmatic-control](../territory/programmatic-control.md) — `hideTooltip`.
- [visibility-scheduling](../territory/visibility-scheduling.md) — the auto-hide timer.

## What a violation looks like

A consumer that waits for `onHide` before acting — removing data, starting another tooltip —
waits until the user comes back to the route. Nothing is drawn wrongly: the tooltip is offstage
with its route.

## Discovery history

- #100 — measured on the covered hide, which is now finished at once; the other hides were left
  as they are. Tracked: #104.

## Where it will recur

Any new path that hides, or any new animation the tooltip drives to an end the code waits for.
