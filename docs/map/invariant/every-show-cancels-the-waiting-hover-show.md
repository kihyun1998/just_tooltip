# Every show cancels the waiting hover show

## The fact

The scheduler's `waitDuration` timer stands for a hover or focus show that has not happened yet.
It is armed only by `onChildEnter`, and only while the tooltip is hidden (ADR-0012). Every way the
tooltip comes to be shown cancels it, so when it fires the tooltip is still hidden and show intent
still holds:

- `onChildEnter` with `isShown` true, or with no `waitDuration` — shows at once and arms no timer.
- `onTap` — cancels it before toggling.
- `onProgrammaticShow`, which `showTooltip` (a `controller.show()`, a queued show applied after
  layout) calls after `_show`.
- the timer's own fire.

Checkable: `_show` is reached only through the scheduler's `onShow` (from `_emitShow`, whose
callers are `onChildEnter` — at once or from the timer — and `onTap`) and from `showTooltip`;
`showTooltip` calls `onProgrammaticShow`. A drop of show intent while the tooltip is hidden
cancels the timer too: `onChildExit`, or `reset` (`_reconcileShowIntent`, `_syncCovered`,
`_dismissByUser`, `_hideImmediate`). The two other drops, `dismissTooltip` and `_onAnimationStatus`
at `dismissed` (both through `_settleClose`, `dismissTooltip` also directly), end a show, and no timer can be armed while a tooltip is shown or fading out.

## Why it is cross-cutting

The timer belongs to the [scheduler](../territory/visibility-scheduling.md), which holds no
visibility state (ADR-0001), while the shows come from three places that do not call each other:
the pointer and focus edges through [show intent](../territory/show-intent.md), the tap, and the
[controller](../territory/programmatic-control.md). The timer's fire calls `_show` without asking
show intent, so a timer outliving the show it stood for acts on whatever happened since — a hide,
an eviction — and opens a tooltip that nothing will hide: the trigger leaving re-derives nothing
(`wants == _showIntent`, both false, once the hide's `dismissed` dropped show intent).

## Territories it holds in

- [visibility-scheduling](../territory/visibility-scheduling.md) — `onChildEnter`, `onTap`,
  `onProgrammaticShow`, `_emitShow`.
- [programmatic-control](../territory/programmatic-control.md) — `showTooltip`.
- [show-intent](../territory/show-intent.md) — `_reconcileShowIntent`, the only caller of
  `onChildEnter`.
- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_show`, the one place a show
  happens, reached by the two paths above.

## What a violation looks like

#106: `onChildEnter` armed the timer while the tooltip was shown or fading out, and `showTooltip`
only restarted the auto-hide. A hover returning during a fade-out waited past the fade's end and
then opened the tooltip, which stayed when the pointer left; a `controller.show()` during the wait
followed by a hide or an eviction did the same; a controller hide whose fade outlasted the wait was
turned back, and `showDuration` counted from the end of the wait. Each half is pinned in
`test/just_tooltip_wait_test.dart` and `test/tooltip_visibility_scheduler_test.dart`; taking out
either reddens its own tests (measured by mutation).

## Discovery history

- #106 — the issue's path (a hover returning during a fade) and its comment's (a registry revival
  mid-fade) went through the timer armed while shown; a lens pass added the paths with no
  fade-return. The first cut cancelled the timer where show intent dropped at `dismissed`, which
  comes only when the hide's fade ends; a second lens pass measured the hide turned back when the
  fade outlasted the wait, and the cancel moved to the show. Flutter's `RawTooltipState` holds
  the same rule: `_scheduleShowTooltip` delays only when dismissed, and `ensureTooltipVisible`
  cancels the pending timer.

## Where it will recur

Any new way to show a tooltip that does not go through the scheduler's `onShow` or `showTooltip`,
and any new timer the scheduler arms on behalf of a show that has not happened yet.
