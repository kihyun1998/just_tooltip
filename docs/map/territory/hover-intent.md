# Hover intent

## What it is

Turns `MouseRegion` edges on the child into one derived boolean — the pointer is inside, hover is
enabled, no descendant suppresses, there is content — and hands only its transitions to the
scheduler. It is the first link of the [visibility chain](visibility-chain.md). Vocabulary:
[Hover Intent](../../../GLOSSARY.md#hover-intent).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — introduces the pointer-facts layer and the microtask coalescing.
- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — adds `hasContent` as the fourth term.

## Design model

From the records, confirmed in source:

- `wants = enableHover && _pointerInside && !_suppressed && _hasContent` (`_reconcileHoverIntent`); `if (wants == _hoverIntent) return` — only transitions reach the scheduler.
- Edge handlers only record facts (`_pointerInside`, `_anchorCandidate`) and call `_syncSuppression` synchronously, then `_scheduleReconcile`. The reconcile is coalesced into one microtask because Flutter dispatches every `onExit` then every `onEnter` synchronously for one move.
- One escape hatch: the tooltip body's `onEnter` calls `_flushReconcile` before `onTooltipEnter`, so the child's deferred exit has armed the bridge before the body cancels it.
- A transition to `false` caused by suppression or lost content is not a hover exit: `_scheduler.reset()` + `_hide()`, bypassing `onChildExit`'s `showDuration` policy.
- `onExit` clears `_anchorCandidate` so a later programmatic show cannot anchor at a cursor that has gone.
- A non-interactive body sits in `IgnorePointer(ignoring: !interactive)`, so it never takes the pointer from its child. Placement can lay the body over the child — one too large for either side is clamped onto it — and an opaque body there made the child report `onExit`, the tooltip hide at once, the child uncover and the tooltip show again: shown on every other 50 ms sample in a 390-wide view with a 300-wide `left` body (#65). An interactive body keeps taking the pointer, because the bridge it cancels on `onEnter` is what keeps it shown. Flutter's `Tooltip` makes the same split (`ignorePointer ?? message != null`, Flutter 3.47.1 `material/tooltip.dart`). Cost: a tap on a non-interactive body reaches the widget beneath it.

Input: pointer events only; one retained bool and one offset per tooltip, nothing unbounded.

## Code

- `lib/src/just_tooltip.dart` — `_JustTooltipState.build` (the `MouseRegion` on the child), `_pointerInside`, `_anchorCandidate`, `_hoverIntent`, `_reconcileQueued`, `_scheduleReconcile`, `_flushReconcile`, `_reconcileHoverIntent`, `_scheduleConfig`, `_buildOverlayChild` (the body's `IgnorePointer` and `MouseRegion.onEnter`)
- Tests: `test/just_tooltip_hover_test.dart`, `test/just_tooltip_nested_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltipState._handleMouseEnter` / `_handleMouseExit` keep a set of hovering devices (`_activeHoveringPointerDevices`) rather than a single edge, and rely on the documented "all `onExit` before any `onEnter`" order in a comment. This package does not rely on that order; it coalesces instead (ADR-0003 calls the order undocumented).

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md)

## Blast radius

- [visibility-scheduling](visibility-scheduling.md) — it assumes it is fed transitions in "child, then tooltip" order; the flush is what keeps that true.
- [nesting-suppression](nesting-suppression.md) — `_suppressed` is a term of the formula, and the claim must stay synchronous while the reconcile is deferred.
- [content](content.md) — `_hasContent` is a term; content loss takes the immediate-hide branch.
- [target-resolution](target-resolution.md) — `_anchorCandidate` recorded here is what a pointer anchor freezes.
- [tap-trigger](tap-trigger.md) — the tap path writes `_anchorCandidate` too and bypasses hover intent entirely.

## Known holes / open

- Multi-pointer: one `_pointerInside` bool per tooltip, where `RawTooltip` tracks a device set. Two mice are not modelled; nothing records whether that is deliberate.
- Tests that inspect state between `onEnter` and the microtask see the stale value (ADR-0003, consequences) — any new test here must pump.
