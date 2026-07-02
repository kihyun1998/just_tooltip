# just_tooltip — Domain Glossary

Shared vocabulary for `just_tooltip`. Use these terms exactly in issues, code, tests, and design notes. When a new concept gets a name during design, add it here.

## Terms

### Visibility Scheduler

The module that decides *when* a tooltip should show or hide, based on pointer events and timing. It owns the hover-intent delay (`waitDuration`), the auto-hide countdown (`showDuration`), and the [Hover Bridge](#hover-bridge). It works purely in wall-clock time (timers) and knows nothing about animation frames or the overlay — it emits show/hide **requests** as callbacks; the widget State reconciles them against the actual render state.

See ADR-0001 for why the scheduler is kept separate from render/animation state (intent vs render frame).

Implemented as `TooltipVisibilityScheduler` (`lib/src/tooltip_visibility_scheduler.dart`, internal — not exported).

### Hover Bridge

The short grace window (100 ms) after the cursor leaves the target, during which the tooltip does *not* hide yet — giving the cursor time to cross the `offset` gap between the target and the tooltip body onto interactive tooltip content. If the cursor reaches the tooltip within the window, hiding is cancelled. Also called the *close delay*. Only active when `interactive` is true.

### Transition Spec

The immutable value object (`TooltipTransitionSpec`: animation type + `fadeBegin` / `scaleBegin` / `slideOffset` / `rotationBegin` / `direction`) that describes *how* a tooltip animates in and out. The State builds it from widget fields and passes it, with an already-curved `Animation<double>`, to `TooltipTransitions.build` — a pure transform (`lib/src/tooltip_transitions.dart`, internal) that owns no animation lifecycle. Slide direction uses the *preferred* `direction`, not the auto-flipped one (behaviour preserved from the pre-extraction code).

### Controller Target

The `@internal` contract (`JustTooltipControllerTarget`: `showTooltip` / `hideTooltip` / `toggleTooltip` / `isTooltipShowing`) that the widget State implements and a `JustTooltipController` attaches to. The controller forwards commands to its attached target and reads visibility from it; it never holds visibility state of its own. Before a target attaches, the controller records a **show-on-attach intent** applied when the State attaches. Data flows one way: controller → State. See ADR-0002.

### Intent vs Render State

Two distinct facts about tooltip visibility, deliberately kept separate (ADR-0001):

- **Intent** — whether we *want* the tooltip shown (`_isShowing`). Owned by the widget State, driven by the [Visibility Scheduler](#visibility-scheduler).
- **Render state** — which frame the show/hide animation is on (`AnimationController.status`). Owned by the animation controller.

The "reverse-catch" (re-showing a tooltip that is mid-fade-out when the cursor returns) reconciles the two.
