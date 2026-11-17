# Live configuration

## What it is

Makes a tooltip already on screen follow its widget's current configuration — `message`,
`tooltipBuilder`, `theme`, `direction`, `alignment`, animation fields — instead of the values it
was opened with.

## Governing decisions

- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — lists #47 as a context issue and rejects comparing fields before marking dirty ("Alternatives rejected").
- [ADR-0005](../../adr/0005-the-tooltip-draws-through-an-overlay-portal.md) — the overlay is built in the State's `build`, so no dirty-marking is needed.

## Design model

From ADR-0004 and the glossary, confirmed in source:

- The overlay builder reads `widget` live; a shown tooltip only has to be rebuilt.
- The overlay is the `OverlayPortal`'s overlay child, built by `_buildOverlayChild` in the State's `build`, so any rebuild of the widget rebuilds it. No field is compared or named.
- Until ADR-0005 the overlay was an `OverlayEntry`, and `didUpdateWidget` marked it dirty, unconditionally and after the frame (`_markOverlayDirty`).
- `animationDuration` and `animationCurve` changes are applied to the controller / `CurvedAnimation` directly.
- A `hideWhenCovered` change runs `_updateCovered` first in `didUpdateWidget`: turned on under a covering route it hides the tooltip, and under an opaque one it also ends the fade (ADR-0011).
- Turning `enableHover` off, or changing the tap mode, takes the child's `MouseRegion` away or re-creates it without an edge, so `didUpdateWidget` clears the pointer fact and the pointer's last position with it (#124, #122, #138); a pointer still on the child is reported again by the new region's post-frame `onEnter`. See [show-intent](show-intent.md) and [target-resolution](target-resolution.md). The body's `MouseRegion` stays when `enableHover` turns off, so a pointer resting on the body sends no edge then; its later exit is a hover exit when the body was entered with hover on, and hides at once (#150, [visibility-scheduling](visibility-scheduling.md)).
- A `showDuration` change on a shown tooltip that is not fading out applies at once (maintainer, 2026-11-17, #151): `didUpdateWidget` calls `TooltipVisibilityScheduler.onShowDurationChange`, which restarts the countdown from the change or, cleared, cancels it and asks for the hide a trigger exit left to the countdown (`_exitLeftToCountdown`). The cases and how each was derived are in ADR-0012 and [visibility-scheduling](visibility-scheduling.md). A hidden tooltip, or one fading out, is left alone: nothing is counted down then. A show reads `showDuration` when it starts, except a hover show still waiting out `waitDuration`, which reads the value of when the wait began (Known holes).
- Accepted: a tooltip losing content fades out rendering an empty bubble (ADR-0004 consequences).

## Code

- `lib/src/just_tooltip.dart` — `build` (the `OverlayPortal`), `_buildOverlayChild`, `didUpdateWidget` (the `showDuration` change), `_updateCurvedAnimation`
- Tests: `test/just_tooltip_live_config_test.dart`

## Reference behaviour

- Flutter 3.41.9 (checkout 00b0c91f062) `widgets/raw_tooltip.dart` has no `didUpdateWidget`: `touchDelay` (Material `Tooltip.showDuration`) and `dismissDelay` are read only when a timer is armed (`_scheduleShowTooltip`, `_handlePressUp`, `_handleMouseExit`), so a change on a shown tooltip applies from the next trigger. The `showDuration` change here applying at once diverges from it (maintainer, 2026-11-17, #151, ADR-0012; kept once the divergence was shown). Every other field is read live by the overlay, as Flutter's overlay reads `widget`.

## Cross-cutting invariants

- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md)

## Blast radius

- [visibility-scheduling](visibility-scheduling.md) — a `showDuration` change reaches the scheduler's timers from here.
- [content](content.md) — the same `didUpdateWidget` is where content loss hides; order there matters.
- [programmatic-control](programmatic-control.md) — the controller swap is handled in the same method.
- [painting](painting.md) and [placement](placement.md) — every rebuild re-runs the overlay box and the delegate.

## Known holes / open

- A `showDuration` change while a hover show waits out `waitDuration` is not seen by that show: the wait timer holds the config of when the wait began (`onChildEnter`'s closure), so a value set during the wait starts no countdown, and once the pointer leaves, `onChildExit` reads the new value and leaves the hide to that countdown — the tooltip stays shown for good (found by #151's review; measured: `waitDuration` 200 ms, the pointer on the child, `showDuration` 300 ms set 100 ms in, the pointer away after the show — still shown 3 s later, `[show]`, on 8e9a797 and with #151 alike). Cleared during the wait, the old value counts down (read, not run). The same closure holds `pointerOnBody`.
- A `showDuration` that changes on every rebuild restarts the countdown each time, so a parent rebuilding faster than the value keeps the tooltip shown: the direct consequence of "counted from the change" (maintainer, 2026-11-17), not shown with the call (found by #151's lens, read).
- The unconditional rebuild's cost has never been measured against a conditional one (accepted by ADR-0004, not measured).
