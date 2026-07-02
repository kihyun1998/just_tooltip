# 0002 — JustTooltipController is an attach-based command source, not a ChangeNotifier

- **Status:** Accepted
- **Date:** 2026-07-02
- **Context issue:** [#4](https://github.com/kihyun1998/just_tooltip/issues/4) (close the controller↔State back-channel)

## Context

`JustTooltipController` was a `ChangeNotifier` holding a `_shouldShow` bool. The widget State listened to it and mirrored it into its own `_isShowing`. Because a tooltip can also be opened by hover, tap, and the auto-hide timer — not just the controller — the State had to silently sync the controller back via a public `resetShouldShow()` (a mutation with no `notifyListeners`). This produced three problems: a bidirectional back-channel, an internal-only method leaking into the public interface, and two sources of truth for visibility that had to be kept in sync by hand.

Visibility has four inputs (controller, hover, tap, auto-hide) that all converge in `_JustTooltipState`. Truth belongs where the inputs converge.

## Decision

`_JustTooltipState` is the single source of truth for visibility. `JustTooltipController` holds **no** `_shouldShow` state and is **not** a `ChangeNotifier`. It is a command source that attaches to one State:

- `show()` / `hide()` / `toggle()` forward to the attached State; when not yet attached they record a show-on-attach intent that the State applies when it attaches.
- `isShowing` reads the State's truth when attached, or the pending intent when not.
- The State reaches the controller through a small `@internal` contract, `JustTooltipControllerTarget` (`showTooltip` / `hideTooltip` / `toggleTooltip` / `isTooltipShowing`), which `_JustTooltipState` implements. The controller depends on this contract, not on the widget/State type, and does not import the widget layer.

Data flow is one-directional: controller → State (commands + query). The State never writes to the controller, so `resetShouldShow()` is deleted.

This mirrors Flutter's own `OverlayPortalController`.

## Consequences

- **Positive:** The back-channel is gone, not merely hidden — there is nothing to sync back. One source of truth. Also fixes a latent bug: calling `show()` before the widget mounts is now honoured (previously ignored, because the State only reacted to listener callbacks and never read the initial value).
- **Positive:** The controller is decoupled from the widget layer via `JustTooltipControllerTarget`, and is unit-testable with a fake target — no widget pump.
- **Breaking (0.2.5 → 0.3.0):** `JustTooltipController` is no longer a `ChangeNotifier`; `addListener` and the `shouldShow` getter are gone (`shouldShow` → `isShowing`). Consumers observe visibility through the widget's `onShow` / `onHide` callbacks instead. Real-world impact is minimal — usage in the wild is command-only.

## Not re-litigating

Do **not** re-propose "make `JustTooltipController` a `ChangeNotifier` / `ValueNotifier<bool>` so visibility is listenable." It was evaluated and rejected: listenability requires the controller to mirror the State's visibility, which reintroduces the dual-truth back-channel this ADR removes. Observation is the job of `onShow` / `onHide`, not the controller — the same split Flutter's `OverlayPortalController` makes.
