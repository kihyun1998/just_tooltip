# Semantic tooltip

## What it is

What a screen reader hears for a tooltip: its text on the child's own semantics node, and an
announcement when it shows. A screen reader is given no way to open a tooltip. Vocabulary:
[Semantic Tooltip](../../../GLOSSARY.md#semantic-tooltip).

## Governing decisions

- [ADR-0009](../../adr/0009-a-screen-reader-hears-the-tooltip-it-does-not-open-it.md) — the goal is hearing, not opening; the core attaches it, gated by content; nested, the innermost is heard, always; the tap modes keep their screen-reader taps (maintainer, 2026-10-26, on #69's triage).
- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — content gates it, as a fourth consumer of `_hasContent`; it is not part of content.

## Design model

From the records, confirmed by `test/just_tooltip_semantics_test.dart`:

- `_semanticText`: `null` when `excludeFromSemantics` or `!_hasContent`; else `semanticsTooltip ?? (tooltipBuilder == null ? message : null)`, `null` when empty. The builder check exists because a builder takes precedence over `message` when drawing, so a message that is never drawn is never heard.
- **Why a render object, not a `Semantics` widget.** Yielding is decided by a descendant, which registers during its own `didChangeDependencies` / `didUpdateWidget` — inside the build phase, after the ancestor has built. Rebuilding the ancestor from there is a `setState` during build. `_RenderSemanticTooltip` instead listens to the state's `_heardText` `ValueNotifier` and calls `markNeedsSemanticsUpdate`, which is legal at any phase, and reads the text in `describeSemanticsConfiguration`. Semantics are flushed after layout and paint, so a registration in this frame's build reaches this frame's tree.
- It sets `config.tooltip` and `config.textDirection` (from `Directionality.maybeOf`, as `Semantics` does — a non-empty tooltip asserts a text direction) and nothing else, never `isSemanticBoundary`: the child stays in whatever node surrounds it, so under `observe` a tappable row's screen-reader tap still reaches it. Splitting a node was rejected in ADR-0009 for that reason.
- **Yielding is structural.** `_syncHeard` registers this tooltip in every ancestor's `_heardDescendants` (whole `_ancestor` chain, like `_claimAncestors`) while `_semanticText != null`; an ancestor's `_heardText` is its own text only while that set is empty. It runs from `_readScope` (called by `didChangeDependencies` and `activate`) and `didUpdateWidget`; `deactivate` and `dispose` release.
- **The release is in `deactivate`, not only `dispose`.** `WidgetsBinding.drawFrame` runs `buildScope`, then layout/paint/semantics, then `finalizeTree` — where removed states are disposed. Released only in `dispose`, an outer tooltip stays silent for the frame its inner one is removed in (red under the mutation, "the outer one is heard again once the inner one stops").
- Measured on Flutter 3.41.9 (#69's triage): on one node, `Semantics(tooltip: 'OUTER')` around `Semantics(tooltip: 'INNER')` keeps `OUTER` (`SemanticsConfiguration.absorb` takes a child's tooltip only when its own is empty); inner and outer tap actions do not combine, the inner one alone fires.
- **A reparent re-reads the chain in `activate`.** `_ancestor` is read with `getInheritedWidgetOfExactType`, which registers no dependency, so a `GlobalKey` move fires `didChangeDependencies` only when the state happens to depend on something else (it does while shown, through `Overlay.of`). Without the re-read, `activate` re-registered the moved tooltip on its old ancestors and silenced them for good (found by #69's review; pinned by "follows a reparented inner tooltip to its new outer one"). The heard registration needs no release in `_readScope`: `deactivate` already released it (a mutation removing such a release stayed green).
- `_show` announces `_semanticText` — the tooltip's own text, even while it yields — with `SemanticsService.tooltip`, once per fresh show; the reverse-catch in `_handleShowRequest` does not pass through `_show` and does not announce, as `RawTooltip` announces only on leaving `dismissed`.

## Code

- `lib/src/just_tooltip.dart` — `JustTooltip.semanticsTooltip`, `excludeFromSemantics`; `_heardDescendants`, `_heardText`, `_semanticText`, `_syncHeard`, `_releaseHeard`, `_addHeardDescendant`, `_removeHeardDescendant`, `_updateHeardText`, `activate`, `deactivate`, `_show`; `_SemanticTooltip`, `_RenderSemanticTooltip`
- Tests: `test/just_tooltip_semantics_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `build` wraps the child in `Semantics(tooltip: semanticsTooltip)` and returns the child unwrapped for an empty one; `_handleStatusChanged` calls `SemanticsService.tooltip` on leaving `dismissed`. `material/tooltip.dart` passes `message` (or `richMessage.toPlainText()`) unless `excludeFromSemantics`. Neither yields when nested: this package's divergence.
- Flutter 3.41.9 `semantics/semantics_service.dart` — `SemanticsService.tooltip` is "currently only honored on Android"; it exists since 1.17, below the 3.32 floor. `WidgetTester.takeAnnouncements` captures only `announce` events, so the tests mock `SystemChannels.accessibility`, as `raw_tooltip_test.dart` does.

## Cross-cutting invariants

- [a-still-pointer-sends-no-edge](../invariant/a-still-pointer-sends-no-edge.md) — the text is data and is re-derived on `didUpdateWidget`, not at pointer edges.

## Blast radius

- [content](content.md) — `_semanticText` reads `_hasContent`; a change to the content rule changes what is heard.
- [nesting-suppression](nesting-suppression.md) — the yield walks the same `_ancestors` chain and re-reads it at the same points (`_readScope`).
- [tap-trigger](tap-trigger.md) — the wrapper must not split the child's node, or `observe`'s yielded screen-reader tap moves.
- [visibility-lifecycle](visibility-lifecycle.md) — `_show` announces.
- [public-surface](public-surface.md) — two new parameters and their dartdoc.

## Known holes / open

- An outer tooltip whose child holds a heard tooltip beside other content (a `Row` of an icon tooltip and a label) is not heard at all — accepted in ADR-0009.
- The tooltip overlay's own semantics are untouched; whether a shown `message` bubble is read a second time from the overlay has not been measured.
- A tooltip in another tooltip's content has no ancestors (ADR-0005), so it never makes its host yield.
- A descendant registers as heard whether or not a screen reader can reach it: under `ExcludeSemantics`, `Offstage`, `Visibility(maintainState: true)` or on a hidden `IndexedStack` child it still silences its ancestor, and nothing is heard (measured, #69's completeness read and #94's triage; a plain `Visibility` drops the subtree and is fine). Accepted in ADR-0009 (#94): `describeSemanticsConfiguration` runs for a hidden child too, so a render object cannot learn from it whether it was reached; the consumer's way out is `excludeFromSemantics` on the hidden one.
- Only `JustTooltip`s join the yield: a Flutter `Tooltip` or `Semantics(tooltip:)` inside one, on the same node, is overridden by the outer text (measured, same read). Accepted in ADR-0009.
