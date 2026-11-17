# A timer acts on the present

## The fact

None of the scheduler's three timers carries a value from the moment it was armed into the moment
it fires. Each fires a callback, and what the fire acts on is read then:

- The `waitDuration` timer fires `onWaitElapsed`; the State answers with `showAfterWait`, passing
  `_scheduleConfig` and `_pointerOnBody` as they are at that moment (`_onWaitElapsed`), and the
  show and the `showDuration` countdown start from those (#155).
- The auto-hide timer fires `onClose` (`_closeOnRequest`), which reads the State.
- The Hover Bridge fires `onHide` (`_hide`), which reads the State.

What a timer does keep from its arming is its length: `waitDuration`, `showDuration` and the
bridge's 100 ms are read when it is armed, so a change to one applies from the next timer
([live-configuration](../territory/live-configuration.md)). A `showDuration` change on a shown
tooltip re-arms the countdown on purpose (#151, ADR-0012).

Checkable: every `Timer(` in `lib/src/tooltip_visibility_scheduler.dart` passes a callback field
(`onWaitElapsed`, `onClose`, `onHide`), not a closure over a parameter.

## Why it is cross-cutting

The scheduler holds no configuration (ADR-0001): config and facts arrive with each call. A closure
over a call's arguments is configuration held after all, out of reach of every later call. The
State follows its widget's current configuration ([live-configuration](../territory/live-configuration.md)),
and the other calls read it per event, so a fire acting on an armed-time value disagrees with them:
`onChildExit` reads the current `showDuration` and leaves the hide to a countdown the fire armed
from the old one, or never armed.

## Territories it holds in

- [visibility-scheduling](../territory/visibility-scheduling.md) — `onChildEnter`,
  `showAfterWait`, `startAutoHide`, `_startHoverBridge`.
- [live-configuration](../territory/live-configuration.md) — `_scheduleConfig`, `_onWaitElapsed`.

## What a violation looks like

#155: the wait timer was `Timer(wait, () => _emitShow(config, pointerOnBody: …))`. A
`showDuration` set during the wait started no countdown, and once the trigger left the tooltip
stayed shown for good; cleared during the wait, the old value closed the tooltip under a resting
pointer. Pinned in `test/just_tooltip_live_config_test.dart` (group *changed while a show waits out
waitDuration*, hover and keyboard focus); putting the closure back reddens all three tests, and the
scheduler test that counts `onWaitElapsed` (measured by #155's run).

## Where it will recur

Any new timer the scheduler arms, and any new argument a timer's fire would want: pass it from the
State when the fire is answered, not from the call that armed the timer.
