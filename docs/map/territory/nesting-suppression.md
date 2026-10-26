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

## Design model

From the records, confirmed in source:

- Each tooltip exposes its State through the private `_TooltipScope` `InheritedWidget`; `didChangeDependencies` reads (does not depend on) the nearest one into `_ancestor`.
- The overlay child sits in the tooltip's element subtree (ADR-0005) and is wrapped in a `_TooltipScope` with a `null` state (and the host's `contentRegistry`, ADR-0007), so a tooltip inside the content has no ancestors — as when the content was an `OverlayEntry`. Seeing its host as an ancestor would let it suppress the tooltip it lives in, which hides and takes it along. The cut is not observable with one pointer: a pointer over the content is over the Overlay, so no ancestor's `MouseRegion` holds it and a suppressed ancestor was not showing anyway; nothing tests it.
- `_ancestor` is read with `getInheritedWidgetOfExactType`, which registers no dependency, so `_readScope` re-reads it in `activate` as well as `didChangeDependencies`: a `GlobalKey` reparent otherwise kept the old chain. When it changed, the old chain is released — `deactivate` does not release suppressors — so an ancestor the suppressor moved out of shows again under the pointer it kept (pinned by "moving a suppressing descendant elsewhere releases the ancestor"; #69).
- `_syncSuppression`: `_claimAncestors(pointer: _pointerInside && _hasContent, focus: enableFocus && _keyboardFocusInside && _hasContent)`, walking the whole `_ancestor` chain (an `enableHover: false` intermediate has no `MouseRegion` to forward with) and setting this tooltip in each ancestor's `_suppressors` and `_focusSuppressors`. A focus suppressor counts only while the pointer is outside the ancestor's child — the pointer wins (ADR-0010, [show-intent](show-intent.md)).
- Called synchronously from the edges and from `didUpdateWidget`; deferring it lets an ancestor with no `waitDuration` flash.
- A suppressed visible tooltip hides immediately, bypassing the `showDuration` policy.
- Hover only: a `controller.show()` is not suppressed. Taps follow `innermost wins` through their own batch, not through `_suppressors` ([tap-trigger](tap-trigger.md), ADR-0006).
- `innermost wins` is a contract (#22), not a defect (`CLAUDE.md`). When table_plus reported "the cell tooltip kills the row card" (`table_plus#88`), the broken invariant was the consumer's: it built a cell tooltip with nothing to draw, and the fix landed there (`docs/agents/lessons.md`, the two higher laws).

## Code

- `lib/src/just_tooltip.dart` — `_TooltipScope`, `_ancestor`, `_ancestors`, `_readScope`, `activate`, `_suppressors`, `_focusSuppressors`, `_suppressed`, `_syncSuppression`, `_claimAncestors`, `_releaseAncestors`, `_setSuppressor`, `didChangeDependencies`, `dispose` (releases)
- Tests: `test/just_tooltip_nested_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `_ExclusiveMouseRegion`: when nested, only the first in hit-test order (the innermost) receives enter/exit; there is no content condition on it. Whether the two differ in behaviour beyond the content gate has not been compared.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — releasing an ancestor depends on its retained `_pointerInside`.

## Blast radius

- [content](content.md) — the right to suppress is content-gated; they cannot change apart.
- [semantic-tooltip](semantic-tooltip.md) — the screen-reader yield walks the same `_ancestor` chain, structurally rather than under the pointer.
- [tap-trigger](tap-trigger.md) — its tap batch walks the same `_ancestor` chain with the same content gate.
- [show-intent](show-intent.md) — `_suppressors` changes schedule a reconcile; suppression is a term of show intent.
- [tooltip-registry](tooltip-registry.md) — orthogonal by ADR-0003; a change that merges them re-opens a rejected design.
- [demonstration](demonstration.md) — #63's `nesting_recipe` and #64's scenario show this contract.

## Known holes / open


**None.**
