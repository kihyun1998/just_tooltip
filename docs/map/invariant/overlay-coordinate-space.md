# The Overlay is the coordinate space

## The fact

Every rect the tooltip measures, flips or clamps against is in the coordinate space of the
`Overlay` the `OverlayPortal` draws into — the nearest one, `Overlay.of(context)` — not the window's.
A rect taken from any other render object is transformed into that space before it is compared or
intersected. Checkable: every rect handed to `JustTooltipPositionDelegate.targetRect` was produced
with the Overlay's render box as the transform's ancestor.

## Why it is cross-cutting

The producer and the consumer never call each other. `_resolveTarget` builds the target rect —
`getTransformTo(overlayBox)` for the child, `overlayBox.globalToLocal` for a frozen pointer — and
`_ancestorClip` transforms each ancestor clip into the same box. `JustTooltipPositionDelegate`
receives only a `Rect` and measures it against the size its `CustomSingleChildLayout` is given,
which is the Overlay's. `_buildOverlayChild` resolves it during the Overlay's layout against the same box. What holds them together is an assumption about *which box is the screen*, not
a call; a producer moved to window coordinates still type-checks and passes every test whose
Overlay fills the window.

## Territories it holds in

- [target-resolution](../territory/target-resolution.md) — `_resolveTarget`, `_ancestorClip`.
- [placement](../territory/placement.md) — `JustTooltipPositionDelegate._hasSpace` and the `screenMargin` clamp in `getPositionForChild`.
- [target-tracking](../territory/target-tracking.md) — `_buildOverlayChild` and `_noteTarget` resolve against `Overlay.of(context)`'s render box.
- [demonstration](../territory/demonstration.md) — `spike_wide_row.dart`'s `_overlayInset`, and the `PreviewStage` condition in #62.

## What a violation looks like

The tooltip is right whenever the Overlay fills the window from its origin and displaced by the
inset otherwise: it fails to flip, clamps to the wrong edge, or points beside its child. Nothing
throws. Reproduces only with an inset, scaled or nested Overlay (`test/just_tooltip_overlay_space_test.dart`
builds one).

## Discovery history

- #24 — a table inside an Overlay inset from the window; tooltips were displaced by the inset (CHANGELOG 0.4.0 "Fixed"; the spike header's item 4).
- #34 — each ancestor clip arrives in its parent's space; a minimal reproduction passed with it wrong and only a consumer tree disagreed (`docs/agents/lessons.md`, Step 3).
- #62 (open) — the example is moving into `PreviewStage`, whose own Overlay must be the nearest one or the tooltip is laid out 1:1 above a `FittedBox` (issue body, section "통과가 기대는 조건" — the conditions the pass relies on).

## Where it will recur

Any code that decides where something goes by comparing against a box it did not get from the
Overlay — a new anchor kind, a margin read from `MediaQuery`, a rect read from another render
object, a preview pane that narrows a viewport. If it does, it is subject to this.
