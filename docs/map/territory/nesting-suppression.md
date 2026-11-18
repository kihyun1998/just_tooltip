# Nesting suppression

## What it is

When tooltips nest, only the innermost one under the pointer that has content shows; it silences
every ancestor while the pointer is inside it. Part of [arbitration](arbitration.md). Vocabulary:
[Nesting Suppression](../../../GLOSSARY.md#nesting-suppression).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — preventive, gates show intent, walks every ancestor; do not move it into the registry.
- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — only a tooltip with content may suppress; the claim stays synchronous.
- [ADR-0005](../../adr/0005-the-tooltip-draws-through-an-overlay-portal.md) — a tooltip's own content is cut off from nesting (maintainer's call).
- [ADR-0006](../../adr/0006-a-tap-goes-to-the-innermost-tooltip.md) — taps reach the same outcome by a per-event batch (maintainer's call).
- [ADR-0010](../../adr/0010-a-keyboard-user-can-show-and-dismiss-a-tooltip.md) — keyboard focus suppresses too; the pointer wins over it.
- [ADR-0012](../../adr/0012-wait-duration-delays-only-a-hidden-tooltip.md) — the pointer on an interactive body holds the tooltip; a focus suppressor does not hide a tooltip whose body the pointer rests on (maintainer's call, #156).

## Design model

From the records, confirmed in source:

- Each tooltip exposes its State through the private `_TooltipScope` `InheritedWidget`; `didChangeDependencies` reads (does not depend on) the nearest one into `_ancestor`. A scope's `state` is the tooltip that built it, fixed for its place, so the old scope widget a tooltip reads while moved together with its ancestor still names the right `_ancestor` ([a-scope-carries-only-what-its-place-fixes](../invariant/a-scope-carries-only-what-its-place-fixes.md)). The claims it holds are released in `deactivate` and claimed again in `activate` (below), so none is left on a tooltip it is no longer under.
- The overlay child sits in the tooltip's element subtree (ADR-0005) and is wrapped in a content scope (`_TooltipScope.content`), which has no state and carries the host's `contentRegistry` (ADR-0007), so a tooltip inside the content has no ancestors — as when the content was an `OverlayEntry`. Seeing its host as an ancestor would let it suppress the tooltip it lives in, which hides and takes it along. The cut is not observable with one pointer: a pointer over the content is over the Overlay, so no ancestor's `MouseRegion` holds it and a suppressed ancestor was not showing anyway; nothing tests it.
- `_ancestor` is read with `getInheritedWidgetOfExactType`, which registers no dependency, so `_readScope` re-reads it in `activate` as well as `didChangeDependencies`: a `GlobalKey` reparent otherwise kept the old chain. `deactivate` releases the whole chain it was under (`_releaseAncestors`), as it releases the heard chain, and `activate`'s `_syncSuppression` claims the new one in the same build, so an ancestor that stays above the moved tooltip is suppressed again before any reconcile runs (no flash; pinned by "within the tooltip above, keeps it suppressed", red without `activate`'s `_syncSuppression`). An ancestor the suppressor moved out of shows again under the pointer it kept, unless it is evicted and waits (#116) — whether `_ancestor` changed (the suppressor moved alone, "moving a suppressing descendant elsewhere releases the ancestor", #69) or not (moved together with its nearest ancestor, so `_ancestor` stays and only the chain above it changed; group *a tooltip moved with its nearest enclosing tooltip*, #162, pointer and focus, each red on 7c140e1). After the first read, every change of `_ancestor` goes through `deactivate` (a reparent is the only way the nearest `_TooltipScope` changes; removing the release from `_readScope` left the whole suite green), so `_readScope` does not release; `dispose` still releases, which finds nothing after `deactivate`. The moved tooltip keeps its own `_pointerInside` through the teardown (#122), so `activate` claims its new ancestors when the pointer is still on it; moved from under the pointer, its region's `onExit` after the frame releases them.
- `_syncSuppression`: `_claimAncestors(pointer: _pointerInside && _hasContent, focus: enableFocus && _keyboardFocusInside && _hasContent)`, walking the whole `_ancestor` chain (an `enableHover: false` intermediate has no `MouseRegion` to forward with) and setting this tooltip in each ancestor's `_suppressors` and `_focusSuppressors`. A focus suppressor counts only while the pointer is outside the ancestor's child — the pointer wins (ADR-0010, [show-intent](show-intent.md)). The pointer resting on an interactive tooltip's body, entered with `enableHover` on, counts as the pointer too: `suppressedFor` reads `_pointerOnBody && _bodyEnteredWithHover` beside the child's pointer, so a focus suppressor does not hide that tooltip in any order, and the body's `onExit` reconciles while a focus suppressor is present, leaving the hide to that reconcile while a trigger inside holds show intent (#156; ADR-0012 holds the call, the superseded no-runtime-change premise and the derivations). Pinned in the nested tests (group *a tooltip the body holds, and a nested tooltip focused*). In one registry D's show evicts A instead ([tooltip-registry](tooltip-registry.md)). `_pointerInside` is `false` while `enableHover` is off, so a tooltip with hover off claims by focus only, and turning it off under a resting pointer releases its ancestors through `didUpdateWidget`'s `_syncSuppression` — not a moved release, so an evicted ancestor waits (#124; pinned in the nested and eviction tests).
- Called synchronously from the edges and from `didUpdateWidget`; deferring it lets an ancestor with no `waitDuration` flash.
- A release carries whether the pointer or focus moved (`moved`, from `onExit` when the pointer moved and from `_onFocusChanged`). `_claimAncestors` reads each ancestor's suppression before the release, without the body pointer (`suppressedFor(pointer.offBody)`, #156), and, when it was suppressed, marks a moved release as an act of the released kind (`_pointerAct` for `_suppressors`, `_focusAct` for `_focusSuppressors`); `_setSuppressor` returns whether it released. An evicted ancestor needs such an act, with that trigger still inside it, to show again before its revival ([show-intent](show-intent.md), #116). A release from `_releaseAncestors` (`deactivate`, `dispose`) or from `didUpdateWidget` is not an act, so an evicted ancestor released that way waits (pinned for a move by "releases an evicted tooltip without an act", red under `moved: true` in `deactivate`).
- A suppressed visible tooltip hides immediately, bypassing the `showDuration` policy.
- Hover only: a `controller.show()` is not suppressed. Taps follow `innermost wins` through their own batch, not through `_suppressors` ([tap-trigger](tap-trigger.md), ADR-0006).
- `innermost wins` is a contract (#22), not a defect (`CLAUDE.md`). When table_plus reported "the cell tooltip kills the row card" (`table_plus#88`), the broken invariant was the consumer's: it built a cell tooltip with nothing to draw, and the fix landed there (`docs/agents/lessons.md`, the two higher laws).

## Code

- `lib/src/just_tooltip.dart` — `_TooltipScope` (`.tooltip`, `.content`), `_ancestor`, `_ancestors`, `_readScope`, `activate`, `deactivate` (releases), `_suppressors`, `_focusSuppressors`, `hasPointerSuppressor`, `hasFocusSuppressor`, `_syncSuppression`, `_claimAncestors`, `_releaseAncestors`, `_setSuppressor`, `didChangeDependencies`, `dispose` (releases)
- `lib/src/tooltip_show_intent.dart` — `TooltipShowIntent.suppressed`, `suppressedFor`, `PointerFacts.offBody`, `notePointerAct`, `noteFocusAct`
- Tests: `test/just_tooltip_nested_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `_ExclusiveMouseRegion`: when nested, only the first in hit-test order (the innermost) receives enter/exit; there is no content condition on it. Whether the two differ in behaviour beyond the content gate has not been compared.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — releasing an ancestor depends on its retained `_pointerInside`.
- [a-pending-mark-clears-at-every-exit](../invariant/a-pending-mark-clears-at-every-exit.md) — `_claimAncestors` sets an ancestor's act only alongside a reconcile.
- [a-scope-carries-only-what-its-place-fixes](../invariant/a-scope-carries-only-what-its-place-fixes.md) — `_ancestor` is read from the scope's `state`, fixed for its place.

## Blast radius

- [content](content.md) — the right to suppress is content-gated; they cannot change apart.
- [semantic-tooltip](semantic-tooltip.md) — the screen-reader yield walks the same `_ancestor` chain, structurally rather than under the pointer.
- [tap-trigger](tap-trigger.md) — its tap batch walks the same `_ancestor` chain with the same content gate.
- [show-intent](show-intent.md) — `_suppressors` changes schedule a reconcile; suppression is a term of show intent.
- [tooltip-registry](tooltip-registry.md) — orthogonal by ADR-0003; a change that merges them re-opens a rejected design.
- [demonstration](demonstration.md) — #63's `nesting_recipe` and #64's scenario show this contract.

## Known holes / open

- None recorded.
