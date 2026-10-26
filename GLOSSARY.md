# just_tooltip — Domain Glossary

Shared vocabulary for `just_tooltip`. Use these terms exactly in issues, code, tests, and design notes. When a new concept gets a name during design, add it here.

## Terms

### Visibility Scheduler

The module that decides *when* a tooltip should show or hide, based on pointer events and timing. It owns the show delay (`waitDuration`), the auto-hide countdown (`showDuration`), and the [Hover Bridge](#hover-bridge). It works purely in wall-clock time (timers) and knows nothing about animation frames or the overlay — it emits show/hide **requests** as callbacks; the widget State reconciles them against the actual render state.

See ADR-0001 for why the scheduler is kept separate from render/animation state (intent vs render frame).

Implemented as `TooltipVisibilityScheduler` (`lib/src/tooltip_visibility_scheduler.dart`, internal — not exported).

### Hover Bridge

The short grace window (100 ms) after the cursor leaves the target, during which the tooltip does *not* hide yet — giving the cursor time to cross the `offset` gap between the target and the tooltip body onto interactive tooltip content. Also called the *close delay*. Only active when `interactive` is true.

The bridge is cancelled by arriving anywhere the tooltip should stay: the tooltip body (`onTooltipEnter`) **or the child itself** (`onChildEnter`). A bridge is armed on leaving either one, so the pointer crossing back and forth arms and cancels it repeatedly. Forgetting the child side is fatal rather than merely late: the bridge fires while the cursor rests on the child, and the fade-out it starts can never be revived, because a pointer that never left sends no further `onEnter`.

### Anchor

What the tooltip is positioned against, selected by `JustTooltip.anchor`. `TooltipAnchor.child` (default) uses the child's rect — the child is then both the hover region and the anchor. `TooltipAnchor.pointer` keeps the child as the hover region but anchors at the pointer, expressed as a **degenerate rect** (zero width and height) at the cursor. The position delegate needs no special case: direction flipping, `screenMargin` clamping and the arrow all work against a zero-size target.

The anchor is **frozen** when the tooltip is shown, from the pointer's last known position (`onEnter` / `onHover`, or the tap's down position — a touch fires no `MouseRegion` callbacks). A tooltip that chased the pointer could never be entered, so [Hover Bridge](#hover-bridge) and `interactive` depend on it not moving. When no pointer position is known — a programmatic `controller.show()`, or the pointer has left — the [Visible Rect](#visible-rect) of the child is the anchor.

Against a point there are no target edges to align to, so `TooltipAlignment` changes meaning: it says which of the *tooltip's own* edges lands on the pointer (`start` → leading, `center` → centred, `end` → trailing).

Both anchors arrive in the Overlay's coordinate space; see `JustTooltipPositionDelegate.targetRect`.

### Visible Rect

The part of the child that is actually on screen: its painted rect intersected with every clip its ancestors apply. It is what `TooltipAnchor.child` aims at. The child's whole rect would point the tooltip at a spot nobody can see whenever an ancestor clips the child — a row wider than its horizontal scroll viewport, say. `screenMargin` does not save that: it confines the tooltip to the `Overlay`, usually the whole app, which an off-screen anchor satisfies.

Computed by walking the ancestors with `RenderObject.describeApproximatePaintClip`, the hook Flutter's own semantics phase uses. Each clip comes back in *its parent's* coordinate space, so it is transformed before being intersected; and a viewport narrows the parameter to `RenderSliver`, so every step passes that parent's actual child. The walk also carries the child's paint transform, which is why a `Transform.scale`d child gets a target of the right extent.

A child clipped away entirely has no visible rect. `controller.show()` then anchors at the clip edge the child lies beyond, rather than refusing — refusing would need a return value nobody asked for. [Target Tracking](#target-tracking) instead hides.

### Target Tracking

The re-aim that keeps a visible tooltip pointing at its child — after a scroll, a resize, a layout animation, or an insertion above it. Subscribing to `ScrollNotification` would catch only the first of those.

The [Visible Rect](#visible-rect) is resolved inside `OverlayPortal.overlayChildLayoutBuilder`, which runs during layout whenever the child may have moved, so the tooltip follows in the same frame (ADR-0008). Until ADR-0008 a post-frame callback re-resolved it after every frame and the tooltip trailed by one. At most one tooltip is visible at a time (the registry), which bounds the work to a single rect per layout.

When the child moves out from under a stationary cursor, Flutter's own post-layout hit test fires `onExit` and the tooltip dismisses through [Show Intent](#show-intent) before tracking matters. Tracking therefore earns its keep where the pointer *stays* inside the child — content scrolling under the cursor — and for tooltips shown with no pointer at all.

Position is not the only thing resolved per overlay build. The overlay renders the widget's `message`, `tooltipBuilder`, `theme`, `direction` and `alignment` live, so a shown tooltip follows its own configuration only if the overlay is rebuilt when that configuration changes. It is the `OverlayPortal`'s overlay child, built in the State's own `build` (ADR-0005), so every rebuild of the widget rebuilds it — no field is named, so none added tomorrow goes stale. Until ADR-0005 it was an `OverlayEntry`, and `didUpdateWidget` had to mark it dirty after the frame.

Hiding is a **transition**, not a state: the tooltip hides when a child it *was* pointing at loses its visible rect. The hide waits for the end of the frame, since an overlay cannot be hidden during layout. A `controller.show()` against a child that was already out of sight asked for a tooltip explicitly — it anchors at the clip edge (see [Visible Rect](#visible-rect)) and keeps tracking, so it finds the child the moment it scrolls into view, and hides only once it has lost it.

A pointer-anchored tooltip is never tracked — its anchor is frozen at the cursor, and a pointer inside the child proves the child shows.

### Show Intent

The derived boolean the [Visibility Scheduler](#visibility-scheduler) actually reacts to: *the pointer is inside this tooltip's child with hover enabled, or keyboard focus is inside it with focus enabled; no descendant tooltip is suppressing us; we have [Content](#content) to draw; and the tooltip has not been [dismissed](#dismissal) since that trigger arrived*. It sits between the raw trigger facts and the scheduler. Called **Hover Intent** until ADR-0010 added focus; it is not the *intent* of [Intent vs Render State](#intent-vs-render-state), which is whether the tooltip is shown (`_isShowing`) — show intent is one of the things that drives it.

Only **keyboard** focus counts: focus that arrives inside the tooltip — its child, or its content — while a focus-moving key (Tab, an arrow key) is down. A click, a tap or a `requestFocus()` is not a trigger; Flutter's keyboard highlight mode would not do, because a mouse click on desktop leaves it on. Once arrived, the fact holds while focus moves about inside, and goes when focus leaves.

When the pointer and the focus point at different tooltips, the pointer wins: a nested tooltip holding focus suppresses its ancestors only while the pointer is not inside them. A tooltip the [Tooltip Registry](#tooltip-registry) hid for another one, while its trigger is still inside, comes back when that one hides — a pointer cannot be in two children, but focus and the pointer can.

`MouseRegion` and focus changes report **edges** (`onEnter` / `onExit`, focus moving); show intent is **state**. The widget State therefore retains the pointer facts (`_pointerInside`, and the pointer's last global position) and recomputes show intent from them, handing only its *transitions* to the scheduler. Recomputation is coalesced into a microtask, so one pointer move — which Flutter dispatches as every `onExit` followed by every `onEnter`, synchronously — is observed once, as its net result.

That coalescing is what makes show intent independent of Flutter's dispatch order. It has one escape hatch: a collaborator that must observe a hover transition *synchronously* flushes the queued recomputation first. Today the only such collaborator is the tooltip body's own `onEnter`, which cancels the [Hover Bridge](#hover-bridge) that the child's `onExit` arms. See ADR-0003.

### Content

Whether a tooltip has anything to draw: it has a `tooltipBuilder`, or a non-empty `message`, or `hideOnEmptyMessage: false` (which asks for the empty bubble). Derived from the widget, never cached, because `message` is data and can arrive or leave while the pointer sits still.

Content decides three things, not one. It gates showing — that much is obvious. It also gates *suppressing*: see [Nesting Suppression](#nesting-suppression). And because showing is gated on it, *hiding* is too: a tooltip that loses its content while on screen closes at once, whoever opened it. The overlay exists only while there is something to draw.

That last rule cannot ride on [Show Intent](#show-intent), which is where suppression's immediate hide lives. A tooltip shown by `controller.show()` never had show intent, so the reconciliation that would hide it sees no transition and returns early. Content loss is therefore acted on directly, in `didUpdateWidget`. See ADR-0004.

### Semantic Tooltip

What a screen reader hears for a tooltip: its text, attached to the child's own semantics node, so a screen-reader user gets the tooltip's information without opening it. The goal is the information, not the overlay — a screen reader is given no way to *open* a tooltip, only to hear it.

It is the core's to attach, not the consumer's, because it follows [Content](#content): a tooltip with nothing to draw is not heard either, so a screen reader never announces a tooltip the screen would never show.

The text is `semanticsTooltip` when given, otherwise `message`. Builder content has no text of its own, so a `tooltipBuilder` tooltip is heard only through `semanticsTooltip`. A tooltip is heard when it has Content, its text is non-empty, and `excludeFromSemantics` is not set. The semantic tooltip is not part of Content: it decides what is heard, never what is drawn — an empty bubble (`hideOnEmptyMessage: false`) is shown and not heard.

Opening a tooltip that is heard on its own terms, by any route, also announces its text once — on Android; other platforms ignore the announcement.

Nested, only the innermost is heard: a tooltip yields its text whenever a descendant tooltip has Content and would be heard, whether or not the two end up in one semantics node. This is [Nesting Suppression](#nesting-suppression)'s rule, but structural — it depends on the tree, not on where a pointer is. Without it the outer text would win: when two tooltip texts land on one node, Flutter keeps the outer one.

A tap mode decides only what a screen-reader tap does, never whether the tooltip is heard. `TooltipTap.observe` yields the screen-reader tap to whatever surrounds the child, as it yields the pointer tap; `TooltipTap.claim` takes it, as it takes the pointer tap. (Inner and outer tap actions on one semantics node do not combine: the inner one alone fires.)

### Dismissal

Closing a shown tooltip by the user, without moving the pointer or the focus: the Escape key. It closes the most recently shown tooltip that is still visible, however it was opened — hover, focus, tap or `controller.show()` — and consumes the key only when focus is inside that tooltip, so a dialog behind it waits for the next press; a tooltip shown with focus elsewhere is closed without consuming, and the dialog closes with it (ADR-0010). One press closes one tooltip. A widget inside the tooltip that takes Escape for itself — a menu, say — does not keep the tooltip open: it closes after that press. With nothing shown, Escape cancels a show still waiting out `waitDuration`.

A dismissed tooltip stays closed while its trigger stays: it has no [Show Intent](#show-intent) again until the pointer leaves and re-enters the child, or focus leaves and returns. Without that, the next pointer move would bring it straight back. A tap is its own trigger and still toggles it.

It is the *dismissible* requirement of WCAG 2.1 SC 1.4.13 (Content on Hover or Focus), which this package takes as its yardstick (ADR-0010). The same criterion asks for *hoverable* and *persistent* content; `interactive: true` and the [Hover Bridge](#hover-bridge) give the first, and the absence of `showDuration` the second, so both opt-outs leave the criterion.

### Nesting Suppression

The rule that when `JustTooltip`s nest, only the innermost one under the pointer **that has [Content](#content)** shows — or, with `enableFocus`, the innermost one holding keyboard focus, unless the pointer is inside an ancestor elsewhere ([Show Intent](#show-intent)). A tooltip whose child contains the pointer, and which has content, registers itself as a *suppressor* on **every** ancestor tooltip (walking the chain, not forwarding through the nearest — an intermediate tooltip with `enableHover: false` has no `MouseRegion` to forward with). A suppressed tooltip has no [Show Intent](#show-intent), so it never schedules a show; if it is already visible it hides immediately, bypassing the scheduler's hide policy (a `showDuration` tooltip refuses to hide on a plain child exit — but suppression is not a hover exit).

**Only a tooltip that can draw may suppress.** Otherwise it takes the ancestor's place and puts nothing there, and the pointer sits over a region where no tooltip appears at all — the ancestor silenced by a descendant that never speaks. Because content is data, this is re-derived whenever the widget updates, not only at the pointer's edges: a still cursor sends no `onEnter` to recompute from.

Suppression is **preventive** and tree-local; the [Tooltip Registry](#tooltip-registry) is **reactive** and app-global. They are orthogonal and both remain. Suppression gates hover only: a programmatic `controller.show()` is an explicit command and is not suppressed by a descendant's hover.

A tap follows the same rule by its own mechanism: the tooltips that report a tap during one pointer event are resolved together, and an ancestor of one that has content does not toggle (ADR-0006).

Implemented via a private `_TooltipScope` `InheritedWidget` that exposes each tooltip's State to its descendants (`lib/src/just_tooltip.dart`, internal — not exported). See ADR-0003, amended by ADR-0004; for taps, ADR-0006.

### Tooltip Registry

The object that enforces the "one tooltip visible at a time" policy. `JustTooltip` registers with it on show and unregisters on hide/dispose; `TooltipRegistry.show` dismisses all other registered tooltips before registering the new one. It drives other tooltips through an `@internal` `DismissibleTooltip` contract (`dismissTooltip()`) that the widget State implements — the same shape as the [[controller-target]] relationship. Defaults to an internal app-global shared instance; an explicit `TooltipRegistry()` can be injected (via `JustTooltip.registry`) for test isolation or a scoped group. Inside another tooltip's content the default is that host's own registry for its content, so a content tooltip dismisses its siblings there, not the host it is drawn in (ADR-0007). Only `TooltipRegistry` is public; `show`/`remove`/`DismissibleTooltip` are internal.

### Transition Spec

The immutable value object (`TooltipTransitionSpec`: animation type + `fadeBegin` / `scaleBegin` / `slideOffset` / `rotationBegin` / `direction`) that describes *how* a tooltip animates in and out. The State builds it from widget fields and passes it, with an already-curved `Animation<double>`, to `TooltipTransitions.build` — a pure transform (`lib/src/tooltip_transitions.dart`, internal) that owns no animation lifecycle. Slide direction uses the *preferred* `direction`, not the auto-flipped one (behaviour preserved from the pre-extraction code).

### Controller Target

The `@internal` contract (`JustTooltipControllerTarget`: `showTooltip` / `hideTooltip` / `toggleTooltip` / `isTooltipShowing`) that the widget State implements and a `JustTooltipController` attaches to. The controller forwards commands to its attached target and reads visibility from it; it never holds visibility state of its own. Before a target attaches, the controller **queues a command** (a pending intent), which the State **consumes and clears** on attach — thereafter the State owns visibility outright, and a detached controller reports `isShowing == false`. Data flows one way: controller → State. See ADR-0002.

### Intent vs Render State

Two distinct facts about tooltip visibility, deliberately kept separate (ADR-0001):

- **Intent** — whether we *want* the tooltip shown (`_isShowing`). Owned by the widget State, driven by the [Visibility Scheduler](#visibility-scheduler).
- **Render state** — which frame the show/hide animation is on (`AnimationController.status`). Owned by the animation controller.

The "reverse-catch" (re-showing a tooltip that is mid-fade-out when the cursor returns) reconciles the two.

Upstream of both sits a third layer, added in ADR-0003 — the pointer facts (`_pointerInside`, last pointer position) and the [Show Intent](#show-intent) derived from them. The full chain is:

```
trigger facts → show intent → intent (_isShowing) → render state (AnimationController)
```
