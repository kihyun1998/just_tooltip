# Programmatic control

## What it is

`JustTooltipController`: show, hide, toggle and query a tooltip from outside, with commands queued
before the widget attaches. Vocabulary: [Controller Target](../../../GLOSSARY.md#controller-target).

## Governing decisions

- [ADR-0002](../../adr/0002-controller-is-attach-based-not-changenotifier.md) — attach-based command source, not a `ChangeNotifier`; queue-before-attach, consume-and-clear on attach, `false` when detached.
- [ADR-0011](../../adr/0011-a-covered-tooltip-hides.md) — a show while covered is ignored, a queued one included; a covered tooltip a controller opened is hidden directly, having no show intent (maintainer, 2026-11-08).

## Design model

From ADR-0002, confirmed in source:

- The controller holds only `_target` and `_pendingShow`. `attach` asserts single attachment, returns and clears the pending show; `detach` clears only if `identical`.
- The State applies a queued show post-frame (`_applyQueuedShowAfterLayout`, guarded by `mounted`) because the overlay needs the child's `RenderBox`.
- `showTooltip` calls `_show` then `_scheduler.startAutoHide` — the only timer a programmatic show arms.
- A tooltip fading out is still `_isShowing`: `show()` turns the fade back through `_show` (#101), and `isShowing` reads `true` throughout. `toggle()` takes a fading tooltip as closed and opens it again (maintainer, 2026-11-08, #101's confirm stop); a tap on a fading tooltip still hides it, since the scheduler's `onTap` reads only `isShown`.
- A programmatic show is not suppressed by a descendant's hover (ADR-0003) and has no show intent, so content loss must close it directly (ADR-0004).
- A listenable `isShowing` is deferred, not forbidden (ADR-0002).
- `_show` reads whether the route is current at the call, not from the last notice, so `Navigator.pop(); controller.show();` in one handler shows and a show right after a push does not flash (ADR-0011, mechanism).

## Code

- `lib/src/just_tooltip_controller.dart` — `JustTooltipController`, `show`, `hide`, `toggle`, `isShowing`, `attach`, `detach`, `JustTooltipControllerTarget`
- `lib/src/just_tooltip.dart` — `showTooltip`, `hideTooltip`, `toggleTooltip`, `isTooltipShowing`, `_applyQueuedShowAfterLayout`, the controller swap in `didUpdateWidget`
- Tests: `test/just_tooltip_controller_test.dart`, `test/just_tooltip_fading_test.dart`

## Reference behaviour

- Flutter 3.41.9 — `RawTooltip` has no controller type: `RawTooltipState.ensureTooltipVisible()` via a key, and the static `dismissAllToolTips()`. ADR-0002 compares against `OverlayPortalController` instead.

## Cross-cutting invariants

- [a-muted-ticker-holds-a-fade](../invariant/a-muted-ticker-holds-a-fade.md)

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — commands land on `_show` / `_hide`.
- [content](content.md) — a controller-shown tooltip is the case that forced content loss to hide directly.
- [target-resolution](target-resolution.md) — with no pointer, the anchor is the child's Visible Rect, and a fully clipped child anchors at the clip edge.
- [public-surface](public-surface.md) — the controller is exported; `flutter_password_input` owns and recreates controllers (`docs/downstream-consumers.md`).

## Known holes / open

- `attach` asserts one target, in debug only; in release a second attach silently replaces the first.
