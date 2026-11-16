# Visibility scheduling

## What it is

Decides *when* a show or hide is requested, in wall-clock time: `waitDuration` before showing,
`showDuration` auto-hide, and the [Hover Bridge](../../../GLOSSARY.md#hover-bridge) grace window.
It emits requests; it never shows anything. Vocabulary: [Visibility Scheduler](../../../GLOSSARY.md#visibility-scheduler).

## Governing decisions

- [ADR-0001](../../adr/0001-scheduler-separates-intent-from-render-state.md) — timing and intent only; no render state, no visibility state, config passed per call.
- [ADR-0012](../../adr/0012-wait-duration-delays-only-a-hidden-tooltip.md) — `waitDuration` delays only a hidden tooltip; a trigger returning while it is shown or fading out turns it back at once (maintainer, 2026-11-12); a controller show cancels a hover show still waiting.
- [ADR-0012, amended 2026-11-16](../../adr/0012-wait-duration-delays-only-a-hidden-tooltip.md#amendment--2026-11-16-the-body-of-an-interactive-tooltip-holds-it-as-its-child-does) — the body of an interactive tooltip holds it as its child does: its pause and resume pair up whatever `enableHover` is (#147), and no show starts `showDuration` while the pointer rests on it (#133), and the pointer entering it during a fade-out turns the fade back as entering the child would (#134) (maintainer, 2026-11-16).

## Design model

From ADR-0001, confirmed in source:

- Holds three timers and nothing else; `isShown`, whether the pointer rests on the body (`pointerOnBody`) and `TooltipScheduleConfig` arrive with the calls that read them. `dispose`/`reset` → `_cancelAll` is the one leak-safety point.
- **The body's pause is a fact, not a missing timer** (maintainer, 2026-11-16, #133). `startAutoHide` arms nothing while `pointerOnBody`; `onTooltipExit` starts it with `pointerOnBody: false`. Every caller that starts the countdown passes it — `onChildEnter`, `onTap`, `onProgrammaticShow` — so no show made while the pointer rests on the body restarts it. Before, the pause was only `onTooltipEnter` cancelling the timer, and the next show re-armed it: a second `controller.show()` with the pointer on the body hid the tooltip under it 800 ms later (measured on fd0a9be), and keyboard focus arriving by Tab on a controller-shown tooltip did the same through `onChildEnter` (measured in #133's run; the conductor's two setups did not reproduce it). `onTap`'s value is `true` only in the frame a hidden tooltip's body is still in the tree, since a tap shows only a hidden tooltip; no test drives it. The fact itself is `_JustTooltipState._pointerOnBody`, set and cleared by the body's `MouseRegion` edges, and cleared when that region leaves the tree (`_OnDispose` around it), since a region removed from the tree sends no `onExit` (`RenderMouseRegion.detach` sets `validForMouseTracker` false, Flutter 3.47.1). It follows the region, not the show: `_endShow` hides the overlay, but the body stays in the render tree until the next frame, and a hide and a show in one frame keep the same region under the pointer, which sends no new `onEnter`. A first cut cleared it in `_endShow`, and both windows broke it, each measured in #133's check with a zero-length fade: the pointer entering the body after `controller.hide()` and before the next pump set the fact with no exit to follow, and the next show never started its countdown (still shown 2 s later, `[show, hide, show]`; fd0a9be hid it); `controller.hide(); controller.show();` with the pointer resting on the body cleared the fact under the pointer, and the countdown ran (gone within 800 ms). Kept in the State rather than as a flag in the scheduler: the scheduler would learn the body's end only from `reset()`, which also runs under a resting pointer (`_dismissByUser` on Escape, the suppression and covered hides), so a fade turned back afterwards would count down under the pointer — read, not run.
- `onChildEnter` arms the `waitDuration` timer only when `isShown` is false; a shown tooltip — fading out counts, since `_isShowing` stays true until the fade reaches `dismissed` — is asked to show at once, which turns the fade back (ADR-0012). This matches Flutter's `RawTooltipState._scheduleShowTooltip`, which delays only when its controller is dismissed. The timer therefore never outlives a fade it could have caught: before, a hover returning mid-fade waited past the fade's end, and the timer opened a tooltip with no show intent that the pointer leaving did not hide (#106).
- Two hide requests (#129): `onHide` for a hide the trigger leaving asks for — a child or body exit without the bridge, the bridge running out — and `onClose` for one it did not cause — a tap on a shown tooltip, the auto-hide. `onClose` defaults to `onHide`, so a scheduler built with one callback behaves as before. The widget needs them apart because only the second is an explicit close of an evicted tooltip ([show-intent](show-intent.md)); pinned in `test/tooltip_visibility_scheduler_test.dart`.
- `onProgrammaticShow` (a controller show) cancels a hover show still waiting out `waitDuration` and an armed bridge, and restarts the auto-hide. Left armed, the timer fired after the controller's show: a tooltip the controller or the registry had hidden meanwhile opened with no show intent, a controller hide whose fade outlasted the wait was turned back, and `showDuration` counted from the end of the wait (measured, #106's lens). A bridge left armed hid the shown tooltip when it fired: a `show()` 40 ms after the pointer left a hover-shown interactive tooltip was gone 800 ms later, with `onShow` then `onHide`, and the same after keyboard focus left (measured on 5b0b463, #131).
- A controller hide while a show waits out `waitDuration` cancels the wait through `reset()` (`hideTooltip` → `_dismissByUser`, #136). It does not go through `onClose`: the auto-hide timer survives a hide that does not reset the scheduler, so a left-over one can fire during a later wait. During a new trigger act's wait on an evicted tooltip `_closeOnRequest` does not take it as a close (#129's guard); during the wait a revival begins it does not either, though that timer belongs to the show being revived — unchanged from 4f3db24, and not decided ([show-intent](show-intent.md), Known holes).
- `onChildExit` with `showDuration` set does nothing — the countdown owns hiding. Without it: `interactive` arms the bridge, otherwise hides at once.
- The bridge (`_hoverBridgeDelay`, 100 ms) is armed on leaving the child or the body and cancelled by `onTooltipEnter` **and** `onChildEnter`, and by every show: `onTap` and `onProgrammaticShow` as well.
- `onTooltipEnter` pauses auto-hide and cancels the bridge; with `turnBack`, which the State decides ([show-intent](show-intent.md), #134), it also requests a show, which turns a fade-out back. `onTooltipExit` restarts the auto-hide whatever `enableHover` and `interactive` are now. With no `showDuration` and `enableHover` on, it arms the bridge, or, with `interactive` off, requests the hide at once through `onHide`, as `onChildExit` does; with `enableHover` off it does nothing (maintainer, 2026-11-16, #148). That exit arrives with `interactive` off only when `interactive` was turned off under a resting pointer: the bridge it used to skip was the only hide left, since show intent had dropped at the child's exit, and a hover-shown tooltip stayed shown for good (measured on fd0a9be and ada5e3e: shown 3 s after the change, and 1 s after the pointer left). Hiding after the bridge was shown to the maintainer and not chosen. Keyboard focus still holds it: the body's `onExit` in `just_tooltip.dart` returns before calling `onTooltipExit` while keyboard focus holds the tooltip (`_heldOpenByFocus`, not merely focus inside; [show-intent](show-intent.md)) and there is no `showDuration`. The pause and its end pair up (maintainer, 2026-11-16, #147): the restart used to return early without `enableHover`, so a tooltip opened by a tap or `controller.show()` whose body the pointer crossed never auto-hid again (measured on fd0a9be: shown 2 s after the pointer crossed), and without `interactive`, which is read when the body's `onExit` arrives — `interactive` turned off under a resting pointer sends that exit after the next frame (measured on fd0a9be: shown 3 s later). The enter cannot arrive without `interactive`: the body sits in `IgnorePointer(ignoring: !interactive)`.
- `onTap` toggles immediately, cancelling hover timers.

The 100 ms value was taken from Flutter's tooltip exit duration (maintainer, 2026-10-23).

## Code

- `lib/src/tooltip_visibility_scheduler.dart` — `TooltipVisibilityScheduler`, `onHide`, `onClose`, `TooltipScheduleConfig`, `onChildEnter`, `onChildExit`, `onTooltipEnter`, `onTooltipExit`, `onTap`, `onProgrammaticShow`, `startAutoHide`, `_emitShow`, `_startHoverBridge`, `_hoverBridgeDelay`, `reset`, `dispose`
- `lib/src/just_tooltip.dart` — `_pointerOnBody` (set and cleared by the body's `MouseRegion` in `_buildOverlayChild`, and by `_OnDispose` when that region leaves the tree), `_JustTooltipState.initState` (constructs it with `_show` / `_hide` / `_closeOnRequest`; the last takes a close of an evicted tooltip as a dismissal — [show-intent](show-intent.md), #129), `_scheduleConfig`
- Tests: `test/tooltip_visibility_scheduler_test.dart` (FakeAsync, no widget pump), `test/just_tooltip_wait_test.dart` (`waitDuration` against a fade and a controller show, at the widget seam), `test/just_tooltip_hover_test.dart`, `test/just_tooltip_keyboard_test.dart` and `test/just_tooltip_eviction_test.dart` (a controller show during the bridge)

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltip` defaults `dismissDelay` to 100 ms and `material/tooltip.dart` `_defaultExitDuration` is 100 ms: the source of `_hoverBridgeDelay`. `RawTooltipState._scheduleShowTooltip` / `_scheduleDismissTooltip` are the equivalent timing layer. Flutter 3.47.1: one `_timer` carries both the show delay and the dismiss delay (`Timer(withDelay, _controller.reverse)`), and `ensureTooltipVisible`, its programmatic show, cancels it first — the same rule `onProgrammaticShow` follows for the two timers here.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — `onChildEnter` cancels the bridge.
- [a-muted-ticker-holds-a-fade](../invariant/a-muted-ticker-holds-a-fade.md)
- [every-show-cancels-the-hover-timers](../invariant/every-show-cancels-the-hover-timers.md)

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — it acts on the requests; a request emitted while fading out relies on the reverse-catch in `_show`.
- [show-intent](show-intent.md) — unit tests here feed events in synchronous order; a change in what order is assumed breaks `interactive` only at the widget seam (ADR-0003, last consequence).
- [programmatic-control](programmatic-control.md) — `showTooltip` calls `onProgrammaticShow`; a programmatic show has no other path into these timers.
- [public-surface](public-surface.md) — `waitDuration`, `showDuration`, `interactive` are documented promises.

## Known holes / open

- `isShown` is passed to `onChildExit` / `onTooltipExit` but neither reads it; `onChildEnter` and `onTap` do.
