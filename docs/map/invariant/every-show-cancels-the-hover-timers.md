# Every show cancels the hover timers

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
at `dismissed` (`dismissTooltip` through `_dropShowIntent`, `_onAnimationStatus` through `_settleClose`), end a show, and no timer can be armed while a tooltip is shown or fading out.

The same shows cancel an armed Hover Bridge, the hide request the scheduler holds for a trigger
that left — the pointer leaving the child or the body, or keyboard focus leaving the child
(`_reconcileShowIntent` → `onChildExit`): `onChildEnter` and `onTap` cancel it before they emit,
`onProgrammaticShow` cancels it with the waiting hover show, and the timer's own fire cannot meet
a bridge. The `waitDuration` timer is armed only after `onChildEnter` cancelled the bridge, and
only while the tooltip is hidden; `onChildExit`, which arms a bridge, cancels the timer first, and
`onTooltipExit`, which does not, cannot run while it waits, since the body is not in the tree and
a `MouseRegion` removed from the tree sends no `onExit`. So a bridge that fires always stands for
the trigger's most recent leave, not for a show made after the scheduler heard that leave.

## Why it is cross-cutting

The timer belongs to the [scheduler](../territory/visibility-scheduling.md), which holds no
visibility state (ADR-0001), while the shows come from three places that do not call each other:
the pointer and focus edges through [show intent](../territory/show-intent.md), the tap, and the
[controller](../territory/programmatic-control.md). The timer's fire calls `_show` without asking
show intent, so a timer outliving the show it stood for acts on whatever happened since — a hide,
an eviction — and opens a tooltip that nothing will hide: the trigger leaving re-derives nothing
(`wants == _showIntent`, both false, once the hide's `dismissed` dropped show intent). A bridge
outliving a show is the mirror case: it calls `_hide` without asking whether anything showed the
tooltip since the pointer left.

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

#131: `onProgrammaticShow` cancelled only the waiting hover show. A `controller.show()` within
100 ms of the pointer or keyboard focus leaving an interactive tooltip — shown, or turned back from
a fade `a.hide()` or `d.show(); a.hide();` started — was hidden when the bridge fired (on 5b0b463:
`onShow`, then `onHide`). Pinned in `test/tooltip_visibility_scheduler_test.dart`,
`test/just_tooltip_hover_test.dart`, `test/just_tooltip_keyboard_test.dart` and
`test/just_tooltip_eviction_test.dart`; taking the cancel out reddens all five tests.

## Discovery history

- #106 — the issue's path (a hover returning during a fade) and its comment's (a registry revival
  mid-fade) went through the timer armed while shown; a lens pass added the paths with no
  fade-return. The first cut cancelled the timer where show intent dropped at `dismissed`, which
  comes only when the hide's fade ends; a second lens pass measured the hide turned back when the
  fade outlasted the wait, and the cancel moved to the show. Flutter's `RawTooltipState` holds
  the same rule: `_scheduleShowTooltip` delays only when dismissed, and `ensureTooltipVisible`
  cancels the pending timer.
- #131 — found by #126's second review: the bridge, the scheduler's other timer standing for a
  pointer edge, was not cancelled by a controller show. Flutter 3.47.1's `RawTooltipState` keeps
  the show delay and the dismiss delay in one `_timer`, so `ensureTooltipVisible` cancelling it
  covers both.

## Where it will recur

Any new way to show a tooltip that does not go through the scheduler's `onShow` or `showTooltip`,
any new timer the scheduler arms on behalf of a show that has not happened yet, and any new timer
it arms to hide on behalf of a pointer edge.
