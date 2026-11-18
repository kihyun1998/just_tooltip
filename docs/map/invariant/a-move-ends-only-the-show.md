# A move ends only the show

## The fact

A `GlobalKey` move deactivates a tooltip's State and activates it again in the same frame
(`Element._activateRecursively`, Flutter 3.41.9 `widgets/framework.dart`). `deactivate` takes
from the tooltip only its show, if one is running. Everything else survives the move, or is
re-read in `activate` from the new place. In `lib/src/just_tooltip.dart`:

- **Ended:** a running show, through `_hideImmediate` → `_endShow`. That covers the overlay, the
  registry's holder, `_shown`, the scheduler's timers and `_announcedShow`, and the show intent
  behind it. `activate`'s reconcile derives show intent again, so a trigger still inside shows the
  tooltip after its `waitDuration` (#122).
- **Kept:** the trigger facts (`_pointerInside`, `_keyboardFocusInside`), the dismissal and its
  holds (`_dismissed`, `_pointerHold`, `_focusHold`) (#122); a hidden tooltip's
  `_anchorCandidate`, since `_endShow` resets it only when a show was running (#141); the
  registry's evicted record, which `dispose` forgets and `_syncRegistry` carries to a new registry; and, on a hidden tooltip, show intent, the pending mark and every scheduler timer:
  `deactivate` calls `_hideImmediate` only while `_isShowing`, so a show waiting out
  `waitDuration` and a left-over auto-hide run on (#139).
- **Re-read in `activate`:** the controller (`_attachController`, #102), the enclosing scope and
  registry (`_readScope`, #69, #119), suppression (`_syncSuppression`), the screen-reader yield
  (`_syncHeard`, released in `deactivate`).

A State that is not activated again reaches `dispose` at the end of the frame, which ends all of
it. Checkable: `deactivate` and `activate` in `lib/src/just_tooltip.dart`; nothing between them
can run a timer or a microtask, since both happen inside one build.

## Why it is cross-cutting

`deactivate` cannot tell a move from a removal, and the state it would clear belongs to several
territories: trigger facts and show intent to [show-intent](../territory/show-intent.md), the
tap position to [target-resolution](../territory/target-resolution.md), the wait to
[visibility-scheduling](../territory/visibility-scheduling.md), the record to
[tooltip-registry](../territory/tooltip-registry.md). Each one cleared at the teardown and not
restored by `activate` makes the move act as a trigger change. A move is not a trigger change
(maintainer, 2026-11-17, #139).

## Territories it holds in

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `deactivate`, `_hideImmediate`, `_endShow`.
- [show-intent](../territory/show-intent.md) — the trigger facts, holds and show intent; `activate`'s reconcile.
- [target-resolution](../territory/target-resolution.md) — `_anchorCandidate` across a move of a hidden tooltip.
- [tooltip-registry](../territory/tooltip-registry.md) — the evicted record, `forget` only in `dispose`.

## What a violation looks like

The tooltip after a move behaves as if its trigger had left and come back, or as if the act that
set show intent had never happened. #122: the teardown cleared `_pointerInside`, so a tooltip
moved under a resting pointer never came back. #141's lens: `_endShow` dropped a hidden tooltip's
tap position on a move. #139: the teardown dropped the show intent a new act had given an evicted
tooltip during `waitDuration` and cancelled the wait, so it waited for its revival; and it
cancelled an evicted tooltip's left-over auto-hide, so the tooltip came back when the holder hid
(`test/just_tooltip_eviction_test.dart`, `test/just_tooltip_wait_test.dart`,
`test/just_tooltip_registry_change_test.dart`, each red on dfb29f5).

## Discovery history

- #122 — trigger facts and holds kept across the teardown.
- #141 — the tap position of a hidden tooltip kept (`_isShowing` guard in `_endShow`).
- #139 — a hidden tooltip's show intent and scheduler timers kept (lens F1 widened the first cut, which kept only a waiting show); promoted to this note, since the three fixes share the assumption.

## Where it will recur

Any new field cleared in `deactivate` or `_hideImmediate`, and any new state that stands for
something the user did rather than for the show on screen.
