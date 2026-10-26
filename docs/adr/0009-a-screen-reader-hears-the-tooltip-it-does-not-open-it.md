# 0009 — A screen reader hears the tooltip; it does not open it

- **Status:** Accepted
- **Date:** 2026-10-26
- **Context issue:** [#69](https://github.com/kihyun1998/just_tooltip/issues/69) (`TooltipTap.observe` gives screen readers no tap action to open the tooltip)

## Context

The package had no deliberate accessibility support. `TooltipTap.claim` exposes `SemanticsAction.tap` only as a side effect of its `GestureDetector`; `TooltipTap.observe` exposes none. Neither mode makes its own semantics node, so the child, the tooltip and any tappable row around it share one node, and one node carries one tap action. Measured on Flutter 3.41.9 by performing `SemanticsAction.tap` on the child:

| mode | tappable row around it | child has a tap | the screen-reader tap |
|---|---|---|---|
| claim | no | yes | opens the tooltip |
| claim | yes | yes | opens the tooltip; the row does **not** fire |
| observe | no | **no** | does nothing |
| observe | yes | yes (the row's) | fires the row; the tooltip does not open |

Inner and outer tap handlers on one node do not combine: the inner one alone fires, for `Semantics(onTap:)` and `GestureDetector` alike. Giving `observe` a tap action would therefore take the row's screen-reader tap, which is what `claim` does and what `observe` exists not to do. Tooltip texts on one node do not combine either: `Semantics(tooltip: 'OUTER')` around `Semantics(tooltip: 'INNER')` leaves the node with `OUTER`.

## Decision

The goal is that a screen-reader user hears the tooltip's information, not that they can open its overlay. Maintainer's call (2026-10-26, on #69's triage), shown the measurements above:

- **The core attaches a [Semantic Tooltip](../../GLOSSARY.md#semantic-tooltip)** to the child, as Flutter's `RawTooltip` does with `Semantics(tooltip:)`. The text is a new `semanticsTooltip: String?` when given, otherwise `message`; a `tooltipBuilder` tooltip is heard only through `semanticsTooltip`. `excludeFromSemantics: bool = false` turns it off, on the widget only — `JustTooltipTheme` stays visual. It is the core's because it follows [Content](../../GLOSSARY.md#content) (ADR-0004): a consumer's own wrapper could not know that a tooltip will never show.
- **It does not change Content.** A tooltip is heard when it has Content, its text is non-empty, and it is not excluded. An empty bubble is shown and not heard.
- **Opening announces it.** Every show — hover, tap, `controller.show()` — announces the tooltip's own text once, as `RawTooltip` does with `SemanticsService.tooltip`. That call is honoured on Android only (its dartdoc, Flutter 3.41.9); found after the call was made, and confirmed by the maintainer as no reason to drop it (2026-10-26).
- **Nested, only the innermost is heard.** A tooltip yields its text whenever a descendant tooltip has Content and would be heard, always — not only when the two texts share a node, which is knowable only during the semantics phase and was not measured. Without it the outer text wins, the reverse of [Nesting Suppression](../../GLOSSARY.md#nesting-suppression) (ADR-0003, ADR-0006).
- **The tap modes keep their screen-reader taps.** `observe` gives none, and that is its contract: it yields the screen-reader tap to its surroundings as it yields the pointer tap. `claim` keeps the one it has and takes the row's, as it takes the pointer tap.

Considered and rejected: a semantic tap on `observe` (it takes the row's tap); leaving the text to consumers (it escapes the content gate); Flutter's default merge for nesting (the inner tooltip goes unheard); splitting the inner tooltip into its own node so both are heard (it pulls the child out of the row's node, changing what the row's screen-reader tap reaches).

## Consequences

- **Accepted:** with "always yield", an outer tooltip whose child holds a nested tooltip beside other content — a `Row` of an icon tooltip and a label — is not heard at all.
- **Not covered:** keyboard and focus (show on focus, dismiss on Escape) — [#92](https://github.com/kihyun1998/just_tooltip/issues/92). The overlay's own semantics are left as they are; interactive builder content stays reachable when shown.
