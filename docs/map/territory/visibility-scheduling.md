# Visibility scheduling

## What it is

Decides *when* a show or hide is requested, in wall-clock time: `waitDuration` before showing,
`showDuration` auto-hide, and the [Hover Bridge](../../../GLOSSARY.md#hover-bridge) grace window.
It emits requests; it never shows anything. Vocabulary: [Visibility Scheduler](../../../GLOSSARY.md#visibility-scheduler).

## Governing decisions

- [ADR-0001](../../adr/0001-scheduler-separates-intent-from-render-state.md) — timing and intent only; no render state, no visibility state, config passed per call.
- [ADR-0012](../../adr/0012-wait-duration-delays-only-a-hidden-tooltip.md) — `waitDuration` delays only a hidden tooltip; a trigger returning while it is shown or fading out turns it back at once (maintainer, 2026-11-12); a controller show cancels a hover show still waiting.

## Design model

From ADR-0001, confirmed in source:

- Holds three timers and nothing else; `isShown` and `TooltipScheduleConfig` arrive with every call. `dispose`/`reset` → `_cancelAll` is the one leak-safety point.
- `onChildEnter` arms the `waitDuration` timer only when `isShown` is false; a shown tooltip — fading out counts, since `_isShowing` stays true until the fade reaches `dismissed` — is asked to show at once, which turns the fade back (ADR-0012). This matches Flutter's `RawTooltipState._scheduleShowTooltip`, which delays only when its controller is dismissed. The timer therefore never outlives a fade it could have caught: before, a hover returning mid-fade waited past the fade's end, and the timer opened a tooltip with no show intent that the pointer leaving did not hide (#106).
- `onProgrammaticShow` (a controller show) cancels a hover show still waiting out `waitDuration` and an armed bridge, and restarts the auto-hide. Left armed, the timer fired after the controller's show: a tooltip the controller or the registry had hidden meanwhile opened with no show intent, a controller hide whose fade outlasted the wait was turned back, and `showDuration` counted from the end of the wait (measured, #106's lens). A bridge left armed hid the shown tooltip when it fired: a `show()` 40 ms after the pointer left a hover-shown interactive tooltip was gone 800 ms later, with `onShow` then `onHide`, and the same after keyboard focus left (measured on 5b0b463, #131).
- `onChildExit` with `showDuration` set does nothing — the countdown owns hiding. Without it: `interactive` arms the bridge, otherwise hides at once.
- The bridge (`_hoverBridgeDelay`, 100 ms) is armed on leaving the child or the body and cancelled by `onTooltipEnter` **and** `onChildEnter`, and by every show: `onTap` and `onProgrammaticShow` as well.
- `onTooltipEnter` pauses auto-hide; `onTooltipExit` restarts it, or arms the bridge.
- `onTap` toggles immediately, cancelling hover timers.

The 100 ms value was taken from Flutter's tooltip exit duration (maintainer, 2026-10-23).

## Code

- `lib/src/tooltip_visibility_scheduler.dart` — `TooltipVisibilityScheduler`, `TooltipScheduleConfig`, `onChildEnter`, `onChildExit`, `onTooltipEnter`, `onTooltipExit`, `onTap`, `onProgrammaticShow`, `startAutoHide`, `_emitShow`, `_startHoverBridge`, `_hoverBridgeDelay`, `reset`, `dispose`
- `lib/src/just_tooltip.dart` — `_JustTooltipState.initState` (constructs it with `_show` / `_hide`), `_scheduleConfig`
- Tests: `test/tooltip_visibility_scheduler_test.dart` (FakeAsync, no widget pump), `test/just_tooltip_wait_test.dart` (`waitDuration` against a fade and a controller show, at the widget seam), `test/just_tooltip_hover_test.dart`, `test/just_tooltip_keyboard_test.dart` and `test/just_tooltip_eviction_test.dart` (a controller show during the bridge)

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltip` defaults `dismissDelay` to 100 ms and `material/tooltip.dart` `_defaultExitDuration` is 100 ms: the source of `_hoverBridgeDelay`. `RawTooltipState._scheduleShowTooltip` / `_scheduleDismissTooltip` are the equivalent timing layer. Flutter 3.47.1: one `_timer` carries both the show delay and the dismiss delay (`Timer(withDelay, _controller.reverse)`), and `ensureTooltipVisible`, its programmatic show, cancels it first — the same rule `onProgrammaticShow` follows for the two timers here.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — `onChildEnter` cancels the bridge.
- [a-muted-ticker-holds-a-fade](../invariant/a-muted-ticker-holds-a-fade.md)
- [every-show-cancels-the-waiting-hover-show](../invariant/every-show-cancels-the-waiting-hover-show.md)

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — it acts on the requests; a request emitted while fading out relies on the reverse-catch in `_show`.
- [show-intent](show-intent.md) — unit tests here feed events in synchronous order; a change in what order is assumed breaks `interactive` only at the widget seam (ADR-0003, last consequence).
- [programmatic-control](programmatic-control.md) — `showTooltip` calls `onProgrammaticShow`; a programmatic show has no other path into these timers.
- [public-surface](public-surface.md) — `waitDuration`, `showDuration`, `interactive` are documented promises.

## Known holes / open

- `isShown` is passed to `onChildExit` / `onTooltipExit` but neither reads it; `onChildEnter` and `onTap` do.
