# Visibility scheduling

## What it is

Decides *when* a show or hide is requested, in wall-clock time: `waitDuration` before showing,
`showDuration` auto-hide, and the [Hover Bridge](../../../GLOSSARY.md#hover-bridge) grace window.
It emits requests; it never shows anything. Vocabulary: [Visibility Scheduler](../../../GLOSSARY.md#visibility-scheduler).

## Governing decisions

- [ADR-0001](../../adr/0001-scheduler-separates-intent-from-render-state.md) — timing and intent only; no render state, no visibility state, config passed per call.

## Design model

From ADR-0001, confirmed in source:

- Holds three timers and nothing else; `isShown` and `TooltipScheduleConfig` arrive with every call. `dispose`/`reset` → `_cancelAll` is the one leak-safety point.
- `onChildExit` with `showDuration` set does nothing — the countdown owns hiding. Without it: `interactive` arms the bridge, otherwise hides at once.
- The bridge (`_hoverBridgeDelay`, 100 ms) is armed on leaving the child or the body and cancelled by `onTooltipEnter` **and** `onChildEnter`.
- `onTooltipEnter` pauses auto-hide; `onTooltipExit` restarts it, or arms the bridge.
- `onTap` toggles immediately, cancelling hover timers.

The 100 ms value was taken from Flutter's tooltip exit duration (maintainer, 2026-10-23).

## Code

- `lib/src/tooltip_visibility_scheduler.dart` — `TooltipVisibilityScheduler`, `TooltipScheduleConfig`, `onChildEnter`, `onChildExit`, `onTooltipEnter`, `onTooltipExit`, `onTap`, `startAutoHide`, `_emitShow`, `_startHoverBridge`, `_hoverBridgeDelay`, `reset`, `dispose`
- `lib/src/just_tooltip.dart` — `_JustTooltipState.initState` (constructs it with `_handleShowRequest` / `_hide`), `_scheduleConfig`
- Tests: `test/tooltip_visibility_scheduler_test.dart` (FakeAsync, no widget pump)

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltip` defaults `dismissDelay` to 100 ms and `material/tooltip.dart` `_defaultExitDuration` is 100 ms: the source of `_hoverBridgeDelay`. `RawTooltipState._scheduleShowTooltip` / `_scheduleDismissTooltip` are the equivalent timing layer.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — `onChildEnter` cancels the bridge.

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — it acts on the requests; a request emitted while fading out relies on the reverse-catch there.
- [hover-intent](hover-intent.md) — unit tests here feed events in synchronous order; a change in what order is assumed breaks `interactive` only at the widget seam (ADR-0003, last consequence).
- [programmatic-control](programmatic-control.md) — `showTooltip` calls `startAutoHide` directly; a programmatic show has no other path into these timers.
- [public-surface](public-surface.md) — `waitDuration`, `showDuration`, `interactive` are documented promises.

## Known holes / open

- `isShown` is passed to `onChildEnter` / `onChildExit` / `onTooltipExit` but only `onTap` reads it.
