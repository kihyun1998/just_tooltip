# Live configuration

## What it is

Makes a tooltip already on screen follow its widget's current configuration — `message`,
`tooltipBuilder`, `theme`, `direction`, `alignment`, animation fields — instead of the values it
was opened with.

## Governing decisions

- [ADR-0004](../../adr/0004-content-gates-showing-suppressing-and-hiding.md) — lists #47 as a context issue and rejects comparing fields before marking dirty ("Alternatives rejected").

## Design model

From ADR-0004 and the glossary, confirmed in source:

- The overlay builder reads `widget` live; a shown tooltip only has to be rebuilt.
- `didUpdateWidget` calls `_markOverlayDirty` unconditionally — naming fields is how a new one goes stale, and `tooltipBuilder` is a new closure on nearly every rebuild anyway.
- The rebuild is coalesced (`_overlayRebuildQueued`) and post-frame.
- `animationDuration` and `animationCurve` changes are applied to the controller / `CurvedAnimation` directly.
- Accepted: a tooltip losing content fades out rendering an empty bubble (ADR-0004 consequences).

## Code

- `lib/src/just_tooltip.dart` — `didUpdateWidget`, `_markOverlayDirty`, `_overlayRebuildQueued`, `_updateCurvedAnimation`
- Tests: `test/just_tooltip_live_config_test.dart`

## Reference behaviour

**None.**

## Cross-cutting invariants

- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md)

## Blast radius

- [content](content.md) — the same `didUpdateWidget` is where content loss hides; order there matters.
- [programmatic-control](programmatic-control.md) — the controller swap is handled in the same method.
- [painting](painting.md) and [placement](placement.md) — every rebuild re-runs the overlay box and the delegate.

## Known holes / open

- The unconditional rebuild's cost has never been measured against a conditional one (accepted by ADR-0004, not measured).
