# Painting

## What it is

Draws the tooltip body: a `Material`/`DecoratedBox` box without an arrow, or one `CustomPaint`
path that joins the rounded box and the arrow, with shadow, fill and border, all from
`JustTooltipTheme`.

## Governing decisions

**None.**

## Design model

From reading, with #31 as evidence:

- `JustTooltipOverlay._buildMaterialBox` (no arrow) vs `_buildArrowBox` (`TooltipShapePainter`), switched on `theme.showArrow`.
- `TooltipShapePainter.paint`: shadows (`boxShadow`, else `elevation` via `drawShadow`), then fill, then stroke. Fill-then-stroke is what makes a transparent background plus `borderColor` an outline (#31).
- The arrow sits on the edge given by the resolved direction; its cross-axis position is `arrowCenterOverride` for `*TargetCenter` alignments, else `arrowPositionRatio`.
- `JustTooltipTheme.bare()` is a transparent, zero-padding, zero-radius surface for bringing your own card. Its transparent `Material` does not mis-clip a consumer's `InkWell` splash **only while `bare()` has no padding** — the condition #30 attached when it withdrew that concern (`docs/agents/lessons.md`, Step 1).
- Arrow-side padding is added so content does not overlap the arrow.

## Code

- `lib/src/just_tooltip_overlay.dart` — `JustTooltipOverlay`, `_buildMaterialBox`, `_buildArrowBox`
- `lib/src/tooltip_shape_painter.dart` — `TooltipShapePainter`, `paint`, `_buildPath`, `_buildTopPath`, `_buildBottomPath`, `_buildLeftPath`, `_buildRightPath`, `_tracePath`, `_arcCorner`, `_arrowCenter`, `shouldRepaint`
- `lib/src/just_tooltip_theme.dart` — `JustTooltipTheme`, `JustTooltipTheme.bare`, `copyWith`
- Tests: `test/tooltip_shape_painter_paint_test.dart`, `test/just_tooltip_theme_test.dart`

## Reference behaviour

**None.**

## Cross-cutting invariants

- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md) — `arrowCenterOverride` arrives through a deferred rebuild.
- [alignment-means-one-edge](../invariant/alignment-means-one-edge.md) — `_arrowCenter` reads the unmirrored `widget.alignment`.

## Blast radius

- [placement](placement.md) — the arrow depends on the resolved direction and the arrow centre placement reports.
- [public-surface](public-surface.md) — every theme field is a public promise, and `flutter_folderview` re-exports `JustTooltipTheme`.

## Known holes / open

- In RTL the arrow for top/bottom `start`/`end` points away from the target; `JustTooltipOverlay.textDirection` is unused (see the invariant above).
- `_buildMaterialBox` uses `elevation` only when there is neither `boxShadow` nor a border; the arrow path uses it whenever `boxShadow` is null. The asymmetry is not recorded as intended.
