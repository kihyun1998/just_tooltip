# A callback never runs in a build

## The fact

Neither `onShow` nor `onHide` is called while a build is under way
(`SchedulerPhase.persistentCallbacks`). A consumer that calls `setState` on a widget above the
tooltip from either one would otherwise hit "setState() called during build" in debug. Checkable:
every `widget.onShow` and `widget.onHide` call sits in a post-frame callback or behind a check of
the scheduler phase.

## Why it is cross-cutting

The two callers do not call each other, and the hides that reach the second start in different
places:

- `_show` — `onShow` always runs in a post-frame callback (#103).
- `_callOnHide`, from `_onAnimationStatus` — `onHide` waits for the frame when the fade reaches
  `dismissed` inside a build. A fade with nothing left to animate ends inside `reverse()`, so any
  hide started in a build can reach it: the content-loss hide in `didUpdateWidget` did (measured,
  #103). The covered hide starts after the frame on its own (ADR-0011).

## Territories it holds in

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_show`, `_onAnimationStatus`, `_callOnHide`.
- [content](../territory/content.md) — the content-loss hide in `didUpdateWidget`.

## What a violation looks like

The "setState() called during build" assertion from inside a consumer's `onShow` or `onHide`, in
debug. In release the rebuild is dropped or lands a frame late.

## Discovery history

- #100 — the covered hide ran `onHide` inside a build on #100's own path (lens read); it was made to
  start after the frame.
- #103 — `onShow` moved after the frame, and `onHide` from the content-loss hide was measured inside
  a build; `_callOnHide` defers it.

## Where it will recur

Any new consumer callback, or any new path that hides from `build`, `didUpdateWidget`,
`didChangeDependencies` or `deactivate`.
