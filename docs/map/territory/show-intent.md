# Show intent

## What it is

Turns the trigger edges on the child — `MouseRegion` enter/exit, focus gained/lost, the highlight
mode changing — into one derived boolean, and hands only its transitions to the scheduler; and
dismisses a shown tooltip on Escape. It is the first link of the [visibility chain](visibility-chain.md).
Called hover intent until ADR-0010. Vocabulary: [Show Intent](../../../GLOSSARY.md#show-intent),
[Dismissal](../../../GLOSSARY.md#dismissal).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — introduces the pointer-facts layer and the microtask coalescing.
- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — adds `hasContent` as the fourth term.
- [ADR-0010](../../adr/0010-a-keyboard-user-can-show-and-dismiss-a-tooltip.md) — adds the keyboard-focus fact (`enableFocus`, opt-in) and dismissal on Escape; WCAG 2.1 SC 1.4.13 is the yardstick (maintainer, 2026-10-26).

## Design model

From the records, confirmed in source:

- `wants = _triggerInside && !_suppressed && _hasContent && !_dismissed` (`_reconcileShowIntent`), where `_triggerInside = (enableHover && _pointerInside) || (enableFocus && _keyboardFocusInside)`; `if (wants == _showIntent) return` — only transitions reach the scheduler.
- **The focus fact.** A `Focus(canRequestFocus: false, skipTraversal: true, includeSemantics: false)` around the child reports `_focusInside` through `onFocusChange`; it takes no focus itself, joins no traversal and adds no semantics node (which would move ADR-0009's merging). `_keyboardFocusInside` also needs `FocusManager.highlightMode == traditional`, read live; `_onHighlightModeChanged` reconciles a tooltip that holds focus when the mode flips. The wrapper is there whatever `enableFocus` says, because Escape's focus path needs `_focusInside` too.
- `_syncSuppression` claims ancestors on the pointer **or** keyboard focus (with `enableFocus`), so a focused inner tooltip silences its outer ones as a hovered one does. A dismissed tooltip keeps suppressing: its outer one does not pop up in its place.
- **Dismissal.** `_shown` (static) lists shown tooltips in show order; `_dismissTarget` is the last one not already reversing. `_dismiss` sets `_dismissed = _triggerInside`, drops `_showIntent`, resets the scheduler and hides; the reconcile clears `_dismissed` once no trigger is inside, so the tooltip needs its trigger to leave and return. A move inside the child sends no edge and never re-derives, so the flag matters only where something else reconciles, such as a nested tooltip releasing it (pinned).
- **Two Escape paths, because only one can consume** (measured on Flutter 3.41.9, #92). `KeyEventManager` hands a key to every `HardwareKeyboard` handler *and* to the focus system's `Shortcuts`, whatever the handlers return, so a handler cannot keep a dialog's `DismissIntent` from closing it. `_handleKey` (a `HardwareKeyboard` handler, added while `_shown` is non-empty) therefore closes only a target whose child does not hold focus: the hover case, where the dialog closes too. A target whose child holds focus is left to `_DismissTooltipAction`, the `DismissIntent` action in an `Actions` around the child, which is on the focus path and nearer than the route's, so it consumes. With nothing to close it forwards to the enclosing action: a nearer `Actions` for an intent shadows the ancestor's even while disabled (measured), so returning disabled would have kept every dialog around a tooltip from closing on Escape.
- Edge handlers only record facts (`_pointerInside`, `_anchorCandidate`) and call `_syncSuppression` synchronously, then `_scheduleReconcile`. The reconcile is coalesced into one microtask because Flutter dispatches every `onExit` then every `onEnter` synchronously for one move.
- One escape hatch: the tooltip body's `onEnter` calls `_flushReconcile` before `onTooltipEnter`, so the child's deferred exit has armed the bridge before the body cancels it.
- A transition to `false` caused by suppression or lost content is not a hover exit: `_scheduler.reset()` + `_hide()`, bypassing `onChildExit`'s `showDuration` policy.
- `onExit` clears `_anchorCandidate` so a later programmatic show cannot anchor at a cursor that has gone.
- A non-interactive body sits in `IgnorePointer(ignoring: !interactive)`, so it never takes the pointer from its child. Placement can lay the body over the child — one too large for either side is clamped onto it — and an opaque body there made the child report `onExit`, the tooltip hide at once, the child uncover and the tooltip show again: shown on every other 50 ms sample in a 390-wide view with a 300-wide `left` body (#65). An interactive body keeps taking the pointer, because the bridge it cancels on `onEnter` is what keeps it shown. Flutter's `Tooltip` makes the same split (`ignorePointer ?? message != null`, Flutter 3.47.1 `material/tooltip.dart`). Cost: a tap on a non-interactive body reaches the widget beneath it.

Input: pointer, focus and key events; three retained bools and one offset per tooltip, and one static list as long as the tooltips shown at once.

## Code

- `lib/src/just_tooltip.dart` — `_JustTooltipState.build` (the `MouseRegion`, `Focus` and `Actions` around the child), `JustTooltip.enableFocus`, `_pointerInside`, `_focusInside`, `_keyboardFocusInside`, `_triggerInside`, `_dismissed`, `_onFocusChange`, `_onHighlightModeChanged`, `_shown`, `_listShown`, `_unlistShown`, `_dismissTarget`, `_handleKey`, `_dismiss`, `_DismissTooltipAction`, `_anchorCandidate`, `_showIntent`, `_reconcileQueued`, `_scheduleReconcile`, `_flushReconcile`, `_reconcileShowIntent`, `_scheduleConfig`, `_buildOverlayChild` (the body's `IgnorePointer` and `MouseRegion.onEnter`)
- Tests: `test/just_tooltip_hover_test.dart`, `test/just_tooltip_nested_test.dart`, `test/just_tooltip_keyboard_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltipState._handleMouseEnter` / `_handleMouseExit` keep a set of hovering devices (`_activeHoveringPointerDevices`) rather than a single edge, and rely on the documented "all `onExit` before any `onEnter`" order in a comment. This package does not rely on that order; it coalesces instead (ADR-0003 calls the order undocumented).

- Flutter 3.41.9 `widgets/raw_tooltip.dart`, `material/tooltip.dart` — no focus trigger and no Escape handling; this territory goes past them on purpose (ADR-0010). `services/hardware_keyboard.dart` `KeyEventManager.handleKeyData` — both the `HardwareKeyboard` handlers and `keyMessageHandler` run for every key; `widgets/actions.dart` `Actions.maybeInvoke` — a suitable action found disabled stops the search.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md)

## Blast radius

- [visibility-scheduling](visibility-scheduling.md) — it assumes it is fed transitions in "child, then tooltip" order; the flush is what keeps that true.
- [nesting-suppression](nesting-suppression.md) — `_suppressed` is a term of the formula, and the claim must stay synchronous while the reconcile is deferred.
- [content](content.md) — `_hasContent` is a term; content loss takes the immediate-hide branch.
- [target-resolution](target-resolution.md) — `_anchorCandidate` recorded here is what a pointer anchor freezes.
- [tap-trigger](tap-trigger.md) — the tap path writes `_anchorCandidate` too and bypasses show intent entirely; a tap still opens a dismissed tooltip.
- [visibility-lifecycle](visibility-lifecycle.md) — `_show` lists the tooltip in `_shown`; the dismissed animation status and `_hideImmediate` unlist it.
- [semantic-tooltip](semantic-tooltip.md) — the `Focus` wrapper must add no semantics node (`includeSemantics: false`), or the child's node splits.

## Known holes / open

- Multi-pointer: one `_pointerInside` bool per tooltip, where `RawTooltip` tracks a device set. Two mice are not modelled; nothing records whether that is deliberate.
- Tests that inspect state between `onEnter` and the microtask see the stale value (ADR-0003, consequences) — any new test here must pump.
- `_DismissTooltipAction.consumesKey` decides whether the key goes on to the platform; no widget test can see it (its mutation stays green).
- The focus path relies on `WidgetsApp`'s default `Escape → DismissIntent` shortcut. In an app without it, a tooltip whose child holds focus is not dismissed: `_handleKey` defers to a path that never fires. From reading only.
