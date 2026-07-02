# 0002 — JustTooltipController is an attach-based command source, not a ChangeNotifier

- **Status:** Accepted
- **Date:** 2026-07-02 (revised same day after an adversarial audit — see "Audit corrections")
- **Context issue:** [#4](https://github.com/kihyun1998/just_tooltip/issues/4) (close the controller↔State back-channel)

## Context

`JustTooltipController` was a `ChangeNotifier` holding a `_shouldShow` bool. The widget State listened to it and mirrored it into its own `_isShowing`. Because a tooltip can also be opened by hover, tap, and the auto-hide timer — not just the controller — the State had to silently sync the controller back via a public `resetShouldShow()` (a mutation with no `notifyListeners`). This produced three problems: a bidirectional back-channel, an internal-only method leaking into the public interface, and two sources of truth for visibility that had to be kept in sync by hand.

Visibility has four inputs (controller, hover, tap, auto-hide) that all converge in `_JustTooltipState`. Truth belongs where the inputs converge.

## Decision

`_JustTooltipState` is the single source of truth for visibility. `JustTooltipController` holds **no** `_shouldShow` state and is **not** a `ChangeNotifier`. It is a command source that attaches to one State:

- `show()` / `hide()` / `toggle()` forward to the attached State. When not yet attached they **queue a command** (a pending intent) — the controller does not model ongoing visibility state, it records "what to do on attach."
- On attach, the State **consumes and clears** the queued command (applies it, then owns visibility outright). This mirrors how `OverlayPortalController` consumes and nulls its `_zOrderIndex` on attach.
- `isShowing` reads the State's truth when attached. When **not** attached it reflects the queued command; when **detached** (attached then removed) it returns `false` — a controller with no live target is not showing anything.
- The State reaches the controller through a small `@internal` contract, `JustTooltipControllerTarget` (`showTooltip` / `hideTooltip` / `toggleTooltip` / `isTooltipShowing`), which `_JustTooltipState` implements. The controller depends on this contract, not on the widget/State type, and does not import the widget layer.

Data flow is one-directional: controller → State (commands + query). The State never writes to the controller, so `resetShouldShow()` is deleted.

### Applying a queued command on attach

Because the overlay is built imperatively and reads the target `RenderBox` (`findRenderObject()` inside the `OverlayEntry` builder), a queued show cannot be applied synchronously in `initState` (layout hasn't happened). It is applied in a post-frame callback. That callback **must** guard `if (!mounted) return;` and re-read the current intent, because between scheduling and firing the State may have been disposed (route pop in the same frame) or the intent superseded by a hover/tap.

### Relationship to OverlayPortalController

This design is **inspired by** `OverlayPortalController`'s attach-based *shape* (attach one target, forward show/hide/toggle, query `isShowing`, queue-before-attach). It deliberately **differs** in two ways, so "mirrors OverlayPortalController" would be inaccurate:

- `OverlayPortalController` holds a **concrete private** `_OverlayPortalState?` in the same library. We use an `@internal` **interface** (`JustTooltipControllerTarget`) instead, so the controller never imports the widget layer — a small, real decoupling win at the cost of one extra type.
- `OverlayPortalController` builds its overlay declaratively and needs no post-frame; we do (see above).

## Consequences

- **Positive:** The back-channel is gone, not merely hidden — there is nothing to sync back. One source of truth. Also fixes a latent bug: calling `show()` before the widget mounts is now honoured (previously ignored, because the State only reacted to listener callbacks and never read the initial value).
- **Positive:** The controller is decoupled from the widget layer via `JustTooltipControllerTarget`, and its command-forwarding is unit-testable with a fake target. Its riskier part — the queue/attach/detach lifecycle — is tested through the **real** State in widget tests (a fake target would not exercise it).
- **Breaking (0.2.5 → 0.3.0):** `JustTooltipController` is no longer a `ChangeNotifier`; `addListener` and the `shouldShow` getter are gone (`shouldShow` → `isShowing`). Consumers observe visibility through the widget's `onShow` / `onHide` callbacks instead. Real-world impact is minimal — usage in the wild is command-only.

## Deferred, not forbidden: listenable observation

We considered exposing visibility as a `ValueListenable<bool>` so consumers could drive declarative rebuilds (`ValueListenableBuilder`) rather than bridging `onShow`/`onHide` through `setState`.

An earlier draft of this ADR rejected it on the grounds that "listenability requires the controller to mirror the State's visibility, reintroducing dual truth." **That reasoning was wrong** and is retracted: a notifier written one-way by the State is a *projection* (a read model), not a second source of authority.

The **actual** reason we defer it: the notifier must be owned by the controller (the persistent object), so the State would have to write into it on every transition — a State→controller projection write. That is not the old authority-mutating back-channel, but it *is* bidirectional coupling, which trades against the strict one-directional flow this ADR establishes. `OverlayPortalController` makes the same call (imperative, no listenable).

This is a genuine tradeoff (composability vs one-directional purity), not a correctness issue. Adding `ValueListenable<bool> get isShowingListenable` later is **non-breaking**, so it is deferred rather than forbidden — revisit if a consumer needs declarative observation.

## Audit corrections (2026-07-02)

An adversarial review flagged, and this revision incorporates: consume-and-clear the queued command on attach (was: retain a bool, which left `isShowing` stale after detach); return `false` when detached; guard the post-frame apply with `if (!mounted)` and re-check intent; reframe the pending value as a *queued command* rather than held visibility state; and correct the false "mirrors OverlayPortalController" claim and the wrong dual-truth argument above.
