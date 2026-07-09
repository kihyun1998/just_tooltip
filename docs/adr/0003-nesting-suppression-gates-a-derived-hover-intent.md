# 0003 — Nesting suppression gates a derived hover intent

- **Status:** Accepted
- **Date:** 2026-07-09
- **Context issue:** [#22](https://github.com/kihyun1998/just_tooltip/issues/22) (a nested tooltip should suppress its ancestors)

## Context

Nest one `JustTooltip` inside another. Flutter's `MouseTracker` delivers `onEnter` to **every** `MouseRegion` on the hit-test path, so both tooltips see the pointer and each schedules independently.

The issue assumed both tooltips would then show. They do not: `TooltipRegistry` already enforces "one tooltip visible at a time", and `_show()` dismisses every other registered tooltip. Probing the real behaviour showed the innermost tooltip does win — but only by coincidence:

- `MouseTracker` dispatches `onEnter` **outermost-first** and `onExit` **innermost-first**. Neither order is a documented API contract.
- The registry's policy is "the last tooltip to *show* wins".
- Outermost-first enter + last-show-wins happens to equal innermost-wins.

Three probes showed the coincidence failing:

1. **An ancestor `waitDuration` hijacks the tooltip.** A timer decouples *show* from *enter*, so "last to show" stops meaning "innermost". With `waitDuration: 500ms` on the outer tooltip, the pointer resting on the inner child sees the inner tooltip replaced by the outer one after half a second.
2. **Releasing an ancestor is impossible.** Moving from the inner child back onto the outer one shows *nothing*: the registry dismissed the outer tooltip, and the outer's `MouseRegion` was never exited, so no second `onEnter` ever arrives.
3. **Independent registries genuinely show both.** The coincidence relies entirely on a shared registry.

The registry is **reactive** — "someone else showed, so I hide". Nesting needs a **preventive** rule — "you may not schedule a show at all". A reactive rule cannot express (1) or (2), because by the time it acts, the wrong tooltip has already claimed the timeline.

## Decision

Introduce a layer upstream of the [Visibility Scheduler](../../CONTEXT.md#visibility-scheduler): retained **pointer facts** (`_pointerInside`, and the pointer's last global position), from which a **hover intent** boolean is derived and handed to the scheduler *on transition only*.

```
pointer facts → hover intent → intent (_isShowing) → render state
```

`hoverIntent = enableHover && pointerInside && !suppressed`

Four commitments:

1. **Suppression is preventive and gates hover intent**, not the show that follows it. A suppressed tooltip never starts a `waitDuration` timer, so an ancestor timer cannot fire behind a nested tooltip's back.

2. **A tooltip suppresses every ancestor, not just the nearest.** Each `JustTooltip` exposes its State to descendants through a private `_TooltipScope` `InheritedWidget`; on enter, a tooltip walks the whole ancestor chain and registers itself as a suppressor on each. Forwarding through the nearest ancestor instead would break at any intermediate tooltip with `enableHover: false`, which has no `MouseRegion` to forward with.

3. **Recomputation is coalesced into a microtask.** Flutter dispatches one pointer move as every `onExit` followed by every `onEnter`, synchronously. Reading the *net* state afterwards makes hover intent independent of that dispatch order. Without it, leaving a nested child and its ancestor at once makes the ancestor flash: the inner `onExit` releases the ancestor while the ancestor still believes it holds the pointer.

4. **Suppression is not a hover exit.** A suppressed-while-visible tooltip hides immediately, bypassing the scheduler's hide policy. Routing it through `onChildExit` would leave a `showDuration` ancestor on screen, since that path deliberately refuses to hide (`showDuration` owns hiding).

Suppression gates **hover only**. A programmatic `controller.show()` is an explicit command and is not suppressed by a descendant's hover.

`TooltipVisibilityScheduler` and `TooltipRegistry` are unchanged. Suppression is tree-local and preventive; the registry stays app-global and reactive. They are orthogonal.

## Consequences

- **Positive:** "Innermost wins" no longer depends on Flutter's undocumented pointer dispatch order, on timer coincidence, or on tooltips sharing a registry.
- **Positive:** The pointer facts that suppression needs (`_pointerInside`) are the same ones pointer anchoring needs ([#21](https://github.com/kihyun1998/just_tooltip/issues/21), where the anchor is the pointer's last position). One retained fact, two features.
- **Positive:** Edge callbacks become fact recorders. Bugs of the class "correctness depends on event ordering" are removed structurally rather than patched case by case.
- **Negative / accepted:** Behaviour change for existing consumers who nest tooltips *and* scope them to separate registries — they used to get two tooltips, now they get the innermost. No flag is offered: the old behaviour is not something anyone chose, and a flag would have to live on the ancestor to be reachable when the nested tooltip is in a subtree the consumer does not control.
- **Negative / accepted:** The suppressor set holds `State` references. Released in `dispose()`; a tooltip removed from the tree while suppressing an ancestor lets that ancestor show again.
- **Negative / accepted:** Hover intent is recomputed one microtask after the pointer event, not synchronously. No frame is missed (microtasks drain before the next frame), but a test that inspects state between `onEnter` and the microtask sees the stale value.

## Not re-litigating

Future reviews should **not** propose "let `TooltipRegistry` handle nesting" as a simplification. The registry has no notion of ancestry and acts only after a tooltip has shown; that is exactly why probes (1) and (2) above fail today. Extending it with ancestry would move tree structure into an app-global object and still leave it reactive.

Nor should "suppress the ancestor by forwarding through the nearest one" be re-proposed: it is a smaller mechanism that fails the `enableHover: false` intermediate case, which is covered by a test.
