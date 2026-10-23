# An alignment means one edge, for the body and the arrow

## The fact

The body and the arrow are positioned from the same resolved `TooltipAlignment`. Where the
delegate mirrors `start`↔`end` (and `startTargetCenter`↔`endTargetCenter`) for RTL on a top/bottom
direction, the arrow must use the mirrored value too. Checkable: for every `(direction, alignment,
textDirection)`, the arrow sits on the side of the body that faces the target.

## Why it is cross-cutting

`JustTooltipPositionDelegate.getPositionForChild` computes `resolvedAlignment` locally and never
exposes it — it reports only the resolved direction and, for `*TargetCenter`, the arrow centre.
`TooltipShapePainter._arrowCenter` switches on the `alignment` it is constructed with, which
`_buildOverlayEntry` passes as `widget.alignment`, unmirrored. `JustTooltipOverlay` receives
`textDirection` and does not use it. The two sites never call each other; mirroring in one is
silently wrong in the other.

## Territories it holds in

- [placement](../territory/placement.md) — `getPositionForChild`'s `resolvedAlignment`.
- [painting](../territory/painting.md) — `TooltipShapePainter._arrowCenter`.

## What a violation looks like

In RTL, `direction: top`/`bottom`, `alignment: start` or `end`, `showArrow: true`: the body is
aligned to the target's opposite edge while the arrow is placed by `arrowPositionRatio` from the
unmirrored side, pointing away from the target. LTR and `center` are unaffected; the `*TargetCenter`
variants are too, since their arrow comes from `arrowCenterOverride`, computed against the target.

## Discovery history

- Reading, 2026-10-23: found while mapping; the RTL tests in `test/just_tooltip_test.dart` exercise the delegate only. Confirmed as a bug, not intended (maintainer, 2026-10-23). Not yet reproduced in a widget test.

## Where it will recur

Any new value the delegate resolves from widget input — a mirrored offset, a new alignment, a
cross-axis fallback direction — that the painter or the transitions also read. If the delegate
derives it and the painter re-derives it from the widget, it is subject to this.
