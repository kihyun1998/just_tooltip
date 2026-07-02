# 0001 — The visibility scheduler separates intent from render state

- **Status:** Accepted
- **Date:** 2026-07-02
- **Context issue:** [#1](https://github.com/kihyun1998/just_tooltip/issues/1) (extract the visibility scheduler)

## Context

`_JustTooltipState` tracks tooltip visibility with two facts that look redundant:

- `_isShowing` (a `bool`) — whether we *want* the tooltip shown (intent).
- `AnimationController.status` — which frame the show/hide animation is on (render state).

The `_handleMouseEnter` "reverse-catch" path (re-`forward()` a tooltip that is mid-fade-out when the cursor returns) exists precisely to reconcile these two facts.

While extracting the timer/hover-intent logic into a `TooltipVisibilityScheduler` module, we considered collapsing the two facts into a single visibility state machine (`hidden / pendingShow / shown / fadingOut`) owned in one place — the "Model B" option. That would make the scheduler the single source of truth for visibility.

## Decision

The scheduler owns **timing and intent only**. It never references `AnimationController` or `Overlay`, and it does not model render state. Intent (`_isShowing`) stays in `_JustTooltipState`; render state stays with the animation controller; the reverse-catch reconciliation stays in the State.

The scheduler holds **no visibility state at all** — the current `isShown` truth is passed into each event method by the State at call time, and configuration is passed as an immutable `TooltipScheduleConfig` value per call. The scheduler's only retained state is its three timer handles.

## Consequences

- **Positive:** The seam follows the natural fault line — timers run on wall-clock time, animation runs on frame time. Keeping animation status out of the scheduler *removes* coupling rather than relocating it. The scheduler is a near-pure function of `(event, isShown, config)` and is testable with `FakeAsync` — no `TickerProvider`, no widget pump.
- **Positive:** The leak-safety invariant (cancel all timers) collapses into one `dispose()` in one module.
- **Negative / accepted:** Intent and render state remain two facts in two places, and the reverse-catch reconciliation remains in the State. This is deliberate: they are genuinely different facts ("do we want it shown?" vs "what frame is the animation on?"), the same split React UIs make between an `isOpen` flag and CSS-transition state. Collapsing them is not a deeper design for this seam — it is a different design optimizing a different axis, and it would drag animation-status awareness across the seam and defeat the purpose of #1.

## Not re-litigating

Future architecture reviews should **not** re-propose "merge `_isShowing` into a single visibility state machine that also owns animation status" as a coupling improvement. It has been evaluated and rejected on merits for this seam. If a single state machine is ever wanted, it is a separate, larger change (touching the animation coupling and the `_visibleInstances` registry, [#5](https://github.com/kihyun1998/just_tooltip/issues/5)), not a cleanup of this one.
