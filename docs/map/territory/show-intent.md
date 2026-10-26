# Show intent

## What it is

Turns the trigger edges on the child — `MouseRegion` enter/exit, focus moving — into one derived
boolean, and hands only its transitions to the scheduler; and dismisses a shown tooltip on
Escape. It is the first link of the [visibility chain](visibility-chain.md). Called hover intent
until ADR-0010. Vocabulary: [Show Intent](../../../GLOSSARY.md#show-intent),
[Dismissal](../../../GLOSSARY.md#dismissal).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — introduces the pointer-facts layer and the microtask coalescing.
- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — adds `hasContent` as the fourth term.
- [ADR-0010](../../adr/0010-a-keyboard-user-can-show-and-dismiss-a-tooltip.md) — adds the keyboard-focus fact (`enableFocus`, opt-in; key-arrived focus only; the pointer wins; an evicted tooltip comes back) and dismissal on Escape; WCAG 2.1 SC 1.4.13 is the yardstick (maintainer, 2026-10-26).

## Design model

From the records, confirmed in source:

- `wants = _triggerInside && !_suppressed && _hasContent && !_dismissed` (`_reconcileShowIntent`), where `_triggerInside = (enableHover && _pointerInside) || (enableFocus && _keyboardFocusInside)`; `if (wants == _showIntent) return` — only transitions reach the scheduler.
- **The focus fact.** `_holdsFocus` walks `FocusManager.primaryFocus.context`'s ancestors up to this State's element, so focus in the child *or* in the tooltip's content counts (the overlay child sits in the tooltip's element subtree, ADR-0005). No widget is put around the child: a first cut wrapped it in a `Focus`, and #92's review measured that `Focus.of(context)` inside every consumer's child then returned the tooltip's node instead of theirs, `enableFocus` or not. `_onFocusChanged` (a `FocusManager` listener, only while `enableFocus`) sets `_keyboardFocusInside` when focus arrives inside while `HardwareKeyboard.logicalKeysPressed` is non-empty — a Tab is still down when the traversal it triggered lands, a focus change is applied in a microtask before the key-up — and keeps it while focus moves about inside. `highlightMode` was the first choice and was dropped: a desktop mouse click leaves it `traditional` (measured).
- **Suppression has two kinds.** `_syncSuppression` claims ancestors in `_suppressors` for the pointer and in `_focusSuppressors` for keyboard focus; `_suppressed` counts a focus suppressor only while the pointer is not inside this tooltip's child, so a pointer hovering an outer child elsewhere wins (ADR-0010). A dismissed tooltip keeps suppressing: its outer one does not pop up in its place.
- **Eviction.** The registry's `dismissTooltip` drops `_showIntent` and records the tooltip in `_evicted`; when the tooltip that took its place reaches `dismissed`, `_reviveEvicted` reconciles the others, so a trigger still inside shows them again. The evicted one's own hide does not clear its entry.
- **Dismissal.** `_shown` (static) lists shown tooltips in show order — a reverse-catch re-tracks — and `_dismissTarget` is the last one not already reversing. `_dismissByUser` sets `_dismissed = _triggerInside`, drops `_showIntent`, resets the scheduler and hides; the reconcile clears `_dismissed` once no trigger is inside. A move inside the child sends no edge and never re-derives, so the flag matters only where something else reconciles, such as a nested tooltip releasing it (pinned). `_pending` holds tooltips with show intent not yet on screen; Escape with nothing shown dismisses them. The `HardwareKeyboard` handler is added while `_shown` or `_pending` is non-empty (`_syncKeyHandler`).
- **Two Escape paths, because only one can consume** (measured on Flutter 3.41.9, #92). `KeyEventManager` hands a key to every `HardwareKeyboard` handler *and* to the focus system's `Shortcuts`, whatever the handlers return, so a handler cannot keep a dialog's `DismissIntent` from closing it. `_handleKey` therefore closes a target that does not hold focus itself — the hover case, where the dialog closes too — and leaves one that does in `_deferred`, with a microtask to close it after the press. `_DismissTooltipAction`, the `DismissIntent` action in an `Actions` around the whole tooltip (child and content), is on the focus path and nearer than the route's: it closes `_deferred` and consumes. A nearer enabled action inside the tooltip (a `DropdownMenu`'s) takes the key instead; the microtask then closes the tooltip. Either way one press closes one tooltip: the handler runs first and does one or the other.
- **Forwarding.** With nothing deferred the action hands the intent to the nearest `DismissIntent` action above the tooltip, found by walking `Actions` widgets (no dependency is registered, unlike `Actions.maybeFind`) and called with the focused context when it is a `ContextAction`. A nearer `Actions` for an intent shadows the ancestor's even while disabled (measured), so returning disabled would have kept every dialog around a tooltip from closing on Escape.
- `activate` re-runs `_syncSuppression` and the reconcile after `_readScope`: a reparented tooltip still holding focus shows again and claims its new ancestors.
- Edge handlers only record facts (`_pointerInside`, `_anchorCandidate`) and call `_syncSuppression` synchronously, then `_scheduleReconcile`. The reconcile is coalesced into one microtask because Flutter dispatches every `onExit` then every `onEnter` synchronously for one move.
- One escape hatch: the tooltip body's `onEnter` calls `_flushReconcile` before `onTooltipEnter`, so the child's deferred exit has armed the bridge before the body cancels it.
- A transition to `false` caused by suppression or lost content is not a hover exit: `_scheduler.reset()` + `_hide()`, bypassing `onChildExit`'s `showDuration` policy.
- `onExit` clears `_anchorCandidate` so a later programmatic show cannot anchor at a cursor that has gone.
- A non-interactive body sits in `IgnorePointer(ignoring: !interactive)`, so it never takes the pointer from its child. Placement can lay the body over the child — one too large for either side is clamped onto it — and an opaque body there made the child report `onExit`, the tooltip hide at once, the child uncover and the tooltip show again: shown on every other 50 ms sample in a 390-wide view with a 300-wide `left` body (#65). An interactive body keeps taking the pointer, because the bridge it cancels on `onEnter` is what keeps it shown. Flutter's `Tooltip` makes the same split (`ignorePointer ?? message != null`, Flutter 3.47.1 `material/tooltip.dart`). Cost: a tap on a non-interactive body reaches the widget beneath it.

Input: pointer, focus and key events; four retained bools and one offset per tooltip, and static sets as large as the tooltips shown, pending or evicted at once.

## Code

- `lib/src/just_tooltip.dart` — `_JustTooltipState.build` (the `MouseRegion` around the child, the `Actions` around the `OverlayPortal`), `JustTooltip.enableFocus`, `_pointerInside`, `_holdsFocus`, `_keyboardFocusInside`, `_triggerInside`, `_dismissed`, `_focusSuppressors`, `_onFocusChanged`, `_shown`, `_pending`, `_evicted`, `_deferred`, `_syncKeyHandler`, `_trackShown`, `_untrackShown`, `_setPending`, `_reviveEvicted`, `_dismissTarget`, `_handleKey`, `_closeDeferred`, `_dismissByUser`, `dismissTooltip`, `activate`, `_DismissTooltipAction`, `_anchorCandidate`, `_showIntent`, `_reconcileQueued`, `_scheduleReconcile`, `_flushReconcile`, `_reconcileShowIntent`, `_scheduleConfig`, `_buildOverlayChild` (the body's `IgnorePointer` and `MouseRegion.onEnter`)
- Tests: `test/just_tooltip_hover_test.dart`, `test/just_tooltip_nested_test.dart`, `test/just_tooltip_keyboard_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltipState._handleMouseEnter` / `_handleMouseExit` keep a set of hovering devices (`_activeHoveringPointerDevices`) rather than a single edge, and rely on the documented "all `onExit` before any `onEnter`" order in a comment. This package does not rely on that order; it coalesces instead (ADR-0003 calls the order undocumented).
- Flutter 3.41.9 `widgets/raw_tooltip.dart`, `material/tooltip.dart` — no focus trigger and no Escape handling; this territory goes past them on purpose (ADR-0010). `services/hardware_keyboard.dart` `KeyEventManager.handleKeyData` — both the `HardwareKeyboard` handlers and `keyMessageHandler` run for every key; `widgets/actions.dart` `Actions.maybeInvoke` — a suitable action found disabled stops the search; `widgets/focus_manager.dart` — `FocusManager` notifies its listeners when `primaryFocus` changes, and `_HighlightModeManager` switches to touch only for touch and stylus pointers.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md)

## Blast radius

- [visibility-scheduling](visibility-scheduling.md) — it assumes it is fed transitions in "child, then tooltip" order; the flush is what keeps that true.
- [nesting-suppression](nesting-suppression.md) — `_suppressed` is a term of the formula, and the claim must stay synchronous while the reconcile is deferred.
- [content](content.md) — `_hasContent` is a term; content loss takes the immediate-hide branch.
- [target-resolution](target-resolution.md) — `_anchorCandidate` recorded here is what a pointer anchor freezes.
- [tap-trigger](tap-trigger.md) — the tap path writes `_anchorCandidate` too and bypasses show intent entirely; a tap still opens a dismissed tooltip.
- [visibility-lifecycle](visibility-lifecycle.md) — `_show` tracks the tooltip in `_shown`; the dismissed animation status and `_hideImmediate` untrack it, and the dismissed status revives evicted tooltips.
- [tooltip-registry](tooltip-registry.md) — `dismissTooltip` is where an evicted tooltip is recorded; `_shown` keeps a second, app-wide record of what is shown.
- [semantic-tooltip](semantic-tooltip.md) — nothing may be put around the child that adds a semantics node, or the child's node splits.

## Known holes / open

- Multi-pointer: one `_pointerInside` bool per tooltip, where `RawTooltip` tracks a device set. Two mice are not modelled; nothing records whether that is deliberate.
- Tests that inspect state between `onEnter` and the microtask see the stale value (ADR-0003, consequences) — any new test here must pump.
- Whether the key goes on to the platform (`_DismissTooltipAction.consumesKey`, and its `isEnabled` claiming the deferred press when no action encloses the tooltip) is invisible to a widget test; both mutations stay green.
- Several views share `_shown` and one keyboard handler, so an Escape typed in one view closes a hovered tooltip in another (ADR-0010, accepted; read, not run).
