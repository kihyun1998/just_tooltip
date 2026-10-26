# Content

## What it is

Whether a tooltip has anything to draw, and the three decisions that fact gates: showing,
suppressing ancestors, and keeping a shown tooltip open. Vocabulary: [Content](../../../GLOSSARY.md#content).

## Governing decisions

- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — content is derived state, gates all three on every path; content loss hides directly in `didUpdateWidget`.

## Design model

From ADR-0004, confirmed in source:

- `_hasContentOf(w) = w.tooltipBuilder != null || !w.hideOnEmptyMessage || (w.message?.isNotEmpty ?? false)`; never cached, because `message` is data.
- **The three gates**, one primitive (`_hasContent`), every one required:
  1. showing — `_show` returns without content; show intent includes it;
  2. suppressing — `_syncSuppression` claims only with content;
  3. hiding — `didUpdateWidget` hides a shown tooltip whose content left, directly, because a controller-shown tooltip has no show intent and `_reconcileShowIntent` would return early. No `_scheduler.reset()` there (ADR-0004 explains why it is safe).
  A new path that opens or keeps a tooltip must consult `_hasContent` too.
- Content also gates what a screen reader hears ([semantic-tooltip](semantic-tooltip.md), ADR-0009), but the semantic text is not part of content: `semanticsTooltip` never makes `_hasContent` true.
- "A tooltip with nothing to draw does not show" is a contract (#22, `CLAUDE.md`).
- The content inherits from the tooltip's location (ADR-0005) except the `SelectionContainer`: inside a `SelectionArea` the overlay is wrapped in `SelectionContainer.disabled`, so the tooltip's text never joins the page's selection.

## Code

- `lib/src/just_tooltip.dart` — `_hasContent`, `_hasContentOf`, `_show`, `_syncSuppression`, `_reconcileShowIntent`, `didUpdateWidget`; `JustTooltip.message`, `tooltipBuilder`, `hideOnEmptyMessage`
- Tests: `test/just_tooltip_nested_test.dart`, `test/just_tooltip_live_config_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — an empty `semanticsTooltip` returns the child unwrapped: content gates showing only. Suppressing and live hiding are this package's divergence (ADR-0004).

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — content is re-derived on `didUpdateWidget`, not only at edges.

## Blast radius

- [nesting-suppression](nesting-suppression.md) — gate 2.
- [semantic-tooltip](semantic-tooltip.md) — `_semanticText` reads `_hasContent`.
- [show-intent](show-intent.md) — gate 1 and the immediate-hide branch.
- [visibility-lifecycle](visibility-lifecycle.md) — `_show`'s guard and gate 3's `_hide`.
- [programmatic-control](programmatic-control.md) — the case gate 3 exists for.
- [public-surface](public-surface.md) — `hideOnEmptyMessage`'s dartdoc states all three.
- [demonstration](demonstration.md) — #63's `content_recipe` shows the contract.

## Known holes / open

- A `tooltipBuilder` that returns an empty widget still counts as content; never decided.
