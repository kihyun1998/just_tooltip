# 0006 — A tap goes to the innermost tooltip

- **Status:** Accepted
- **Date:** 2026-10-24
- **Context issue:** [#68](https://github.com/kihyun1998/just_tooltip/issues/68) (a tap on a nested observe tooltip shows the outer one, the reverse of claim and hover)

## Context

[Nesting Suppression](../../GLOSSARY.md#nesting-suppression) makes the innermost tooltip win for hover (ADR-0003), but a tap bypasses hover intent. Before this record, every tooltip that saw a tap toggled, and whichever opened last dismissed the others through the [Tooltip Registry](../../GLOSSARY.md#tooltip-registry). With `TooltipTap.observe` (#66) the inner tooltip never wins the gesture arena, so the outer one toggled after it and won. Measured on Flutter 3.47.1, tapping the inner child of two nested tooltips inside a tappable row:

| outer | inner | shown |
|---|---|---|
| claim | claim | inner |
| claim | observe | **outer** |
| observe | claim | inner — the outer opened and was dismissed in the same tap (`onShow` 1, `onHide` 1) |
| observe | observe | **outer** |

With the inner on its own `TooltipRegistry` both stayed shown. A second tap on the inner child opened the inner and closed the outer.

## Decision

Taps are resolved per pointer event, innermost first. `_toggleFromTap` adds the tooltip to a static batch and schedules one microtask, `_resolveTapBatch`, for the batch. In that microtask a tooltip does not toggle when another tooltip in the batch with [Content](../../GLOSSARY.md#content) is its descendant, walking the whole `_ancestor` chain. Maintainer's call (2026-10-24), chosen over two options it was shown, with the measurements above and a prototype:

- **Documenting today's behaviour.** "A tap toggles every tooltip that sees it; the registry decides which remains." This would make the flash, the two-tap reversal and the independent-registry case part of the contract.
- **Skipping by geometry.** An `observe` ancestor ignores a tap whose down position lies inside a descendant tooltip's child. This fixes only `observe` ancestors and needs hit geometry. It was not prototyped.

Two rules are inherited, not new:

- **Coalescing:** ADR-0003's way of reading the net state after one batch of pointer events, independent of the order of dispatch. The tooltips' tap reports arrive in that order: an `observe` member reports during the up event's routing, and a `claim` member reports after the arena sweep.
- **The content gate:** ADR-0004's rule that only a tooltip that can draw may suppress. An inner tooltip with nothing to show leaves the tap to its ancestor.

An ancestor's own gesture handlers are untouched. A tappable row receives the tap exactly as before, and an outer `claim` still takes the tap from the row while not toggling.

## Consequences

- **Positive:** the inner tooltip shows in all four combinations, across independent registries and through an intermediate tooltip that has no tap trigger. A second tap closes it, and the outer tooltip no longer flashes.
- **Accepted:** a tap toggles one microtask later than before, after the pointer event that carried it. A widget test that taps and then pumps sees no difference.
- **Scope:** only `observe` changes the outcome, and `observe` is unreleased (0.5.0). A released `claim`/`claim` pair already showed the inner tooltip.
- **Not covered:** a tooltip inside another tooltip's content has no ancestors (ADR-0005), so a tap there never reaches its host's batch rule.
