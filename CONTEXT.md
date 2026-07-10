# just_tooltip — Domain Glossary

Shared vocabulary for `just_tooltip`. Use these terms exactly in issues, code, tests, and design notes. When a new concept gets a name during design, add it here.

## Terms

### Visibility Scheduler

The module that decides *when* a tooltip should show or hide, based on pointer events and timing. It owns the hover-intent delay (`waitDuration`), the auto-hide countdown (`showDuration`), and the [Hover Bridge](#hover-bridge). It works purely in wall-clock time (timers) and knows nothing about animation frames or the overlay — it emits show/hide **requests** as callbacks; the widget State reconciles them against the actual render state.

See ADR-0001 for why the scheduler is kept separate from render/animation state (intent vs render frame).

Implemented as `TooltipVisibilityScheduler` (`lib/src/tooltip_visibility_scheduler.dart`, internal — not exported).

### Hover Bridge

The short grace window (100 ms) after the cursor leaves the target, during which the tooltip does *not* hide yet — giving the cursor time to cross the `offset` gap between the target and the tooltip body onto interactive tooltip content. If the cursor reaches the tooltip within the window, hiding is cancelled. Also called the *close delay*. Only active when `interactive` is true.

### Anchor

What the tooltip is positioned against, selected by `JustTooltip.anchor`. `TooltipAnchor.child` (default) uses the child's rect — the child is then both the hover region and the anchor. `TooltipAnchor.pointer` keeps the child as the hover region but anchors at the pointer, expressed as a **degenerate rect** (zero width and height) at the cursor. The position delegate needs no special case: direction flipping, `screenMargin` clamping and the arrow all work against a zero-size target.

The anchor is **frozen** when the tooltip is shown, from the pointer's last known position (`onEnter` / `onHover`, or `onTapDown` — a touch fires no `MouseRegion` callbacks). A tooltip that chased the pointer could never be entered, so [Hover Bridge](#hover-bridge) and `interactive` depend on it not moving. When no pointer position is known — a programmatic `controller.show()`, or the pointer has left — the [Visible Rect](#visible-rect) of the child is the anchor.

Against a point there are no target edges to align to, so `TooltipAlignment` changes meaning: it says which of the *tooltip's own* edges lands on the pointer (`start` → leading, `center` → centred, `end` → trailing).

Both anchors arrive in the Overlay's coordinate space; see `JustTooltipPositionDelegate.targetRect`.

### Visible Rect

The part of the child that is actually on screen: its painted rect intersected with every clip its ancestors apply. It is what `TooltipAnchor.child` aims at. The child's whole rect would point the tooltip at a spot nobody can see whenever an ancestor clips the child — a row wider than its horizontal scroll viewport, say. `screenMargin` does not save that: it confines the tooltip to the `Overlay`, usually the whole app, which an off-screen anchor satisfies.

Computed by walking the ancestors with `RenderObject.describeApproximatePaintClip`, the hook Flutter's own semantics phase uses. Each clip comes back in *its parent's* coordinate space, so it is transformed before being intersected; and a viewport narrows the parameter to `RenderSliver`, so every step passes that parent's actual child. The walk also carries the child's paint transform, which is why a `Transform.scale`d child gets a target of the right extent.

A child clipped away entirely has no visible rect. `controller.show()` then anchors at the clip edge the child lies beyond, rather than refusing — refusing would need a return value nobody asked for. [Target Tracking](#target-tracking) instead hides.

### Target Tracking

The per-frame re-aim that keeps a visible tooltip pointing at its child. The [Visible Rect](#visible-rect) is resolved once per overlay build, so without this the tooltip stays where the child used to be — after a scroll, a resize, a layout animation, or an insertion above it. Subscribing to `ScrollNotification` would catch only the first of those.

A post-frame callback re-arms itself while an overlay entry exists. It schedules no frame of its own, so it idles until something else moves the child. At most one tooltip is visible at a time (the registry), which bounds the work to a single rect per frame.

When the child moves out from under a stationary cursor, Flutter's own post-layout hit test fires `onExit` and the tooltip dismisses through [Hover Intent](#hover-intent) before tracking matters. Tracking therefore earns its keep where the pointer *stays* inside the child — content scrolling under the cursor — and for tooltips shown with no pointer at all.

Hiding is a **transition**, not a state: the tooltip hides when a child it *was* pointing at loses its visible rect. A `controller.show()` against a child that was already out of sight asked for a tooltip explicitly — it anchors at the clip edge (see [Visible Rect](#visible-rect)) and keeps tracking, so it finds the child the moment it scrolls into view, and hides only once it has lost it.

A pointer-anchored tooltip is never tracked — its anchor is frozen at the cursor, and a pointer inside the child proves the child shows.

### Hover Intent

The derived boolean the [Visibility Scheduler](#visibility-scheduler) actually reacts to: *the pointer is inside this tooltip's child, hover is enabled, and no descendant tooltip is suppressing us*. It sits between the raw pointer facts and the scheduler.

`MouseRegion` reports **edges** (`onEnter` / `onExit`); hover intent is **state**. The widget State therefore retains the pointer facts (`_pointerInside`, and the pointer's last global position) and recomputes hover intent from them, handing only its *transitions* to the scheduler. Recomputation is coalesced into a microtask, so one pointer move — which Flutter dispatches as every `onExit` followed by every `onEnter`, synchronously — is observed once, as its net result.

That coalescing is what makes hover intent independent of Flutter's dispatch order. It has one escape hatch: a collaborator that must observe a hover transition *synchronously* flushes the queued recomputation first. Today the only such collaborator is the tooltip body's own `onEnter`, which cancels the [Hover Bridge](#hover-bridge) that the child's `onExit` arms. See ADR-0003.

### Nesting Suppression

The rule that when `JustTooltip`s nest, only the innermost one under the pointer shows. A tooltip whose child contains the pointer registers itself as a *suppressor* on **every** ancestor tooltip (walking the chain, not forwarding through the nearest — an intermediate tooltip with `enableHover: false` has no `MouseRegion` to forward with). A suppressed tooltip has no [Hover Intent](#hover-intent), so it never schedules a show; if it is already visible it hides immediately, bypassing the scheduler's hide policy (a `showDuration` tooltip refuses to hide on a plain child exit — but suppression is not a hover exit).

Suppression is **preventive** and tree-local; the [Tooltip Registry](#tooltip-registry) is **reactive** and app-global. They are orthogonal and both remain. Suppression gates hover only: a programmatic `controller.show()` is an explicit command and is not suppressed by a descendant's hover.

Implemented via a private `_TooltipScope` `InheritedWidget` that exposes each tooltip's State to its descendants (`lib/src/just_tooltip.dart`, internal — not exported). See ADR-0003.

### Tooltip Registry

The object that enforces the "one tooltip visible at a time" policy. `JustTooltip` registers with it on show and unregisters on hide/dispose; `TooltipRegistry.show` dismisses all other registered tooltips before registering the new one. It drives other tooltips through an `@internal` `DismissibleTooltip` contract (`dismissTooltip()`) that the widget State implements — the same shape as the [[controller-target]] relationship. Defaults to an internal app-global shared instance; an explicit `TooltipRegistry()` can be injected (via `JustTooltip.registry`) for test isolation or a scoped group. Only `TooltipRegistry` is public; `show`/`remove`/`DismissibleTooltip` are internal.

### Transition Spec

The immutable value object (`TooltipTransitionSpec`: animation type + `fadeBegin` / `scaleBegin` / `slideOffset` / `rotationBegin` / `direction`) that describes *how* a tooltip animates in and out. The State builds it from widget fields and passes it, with an already-curved `Animation<double>`, to `TooltipTransitions.build` — a pure transform (`lib/src/tooltip_transitions.dart`, internal) that owns no animation lifecycle. Slide direction uses the *preferred* `direction`, not the auto-flipped one (behaviour preserved from the pre-extraction code).

### Controller Target

The `@internal` contract (`JustTooltipControllerTarget`: `showTooltip` / `hideTooltip` / `toggleTooltip` / `isTooltipShowing`) that the widget State implements and a `JustTooltipController` attaches to. The controller forwards commands to its attached target and reads visibility from it; it never holds visibility state of its own. Before a target attaches, the controller **queues a command** (a pending intent), which the State **consumes and clears** on attach — thereafter the State owns visibility outright, and a detached controller reports `isShowing == false`. Data flows one way: controller → State. See ADR-0002.

### Intent vs Render State

Two distinct facts about tooltip visibility, deliberately kept separate (ADR-0001):

- **Intent** — whether we *want* the tooltip shown (`_isShowing`). Owned by the widget State, driven by the [Visibility Scheduler](#visibility-scheduler).
- **Render state** — which frame the show/hide animation is on (`AnimationController.status`). Owned by the animation controller.

The "reverse-catch" (re-showing a tooltip that is mid-fade-out when the cursor returns) reconciles the two.

Upstream of both sits a third layer, added in ADR-0003 — the pointer facts (`_pointerInside`, last pointer position) and the [Hover Intent](#hover-intent) derived from them. The full chain is:

```
pointer facts → hover intent → intent (_isShowing) → render state (AnimationController)
```
