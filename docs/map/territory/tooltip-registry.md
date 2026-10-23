# Tooltip registry

## What it is

Enforces "one tooltip visible at a time" within a registry: showing one dismisses every other
registered tooltip. Part of [arbitration](arbitration.md). Vocabulary:
[Tooltip Registry](../../../GLOSSARY.md#tooltip-registry).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — names the registry reactive and app-global, orthogonal to suppression, and rejects extending it with ancestry.

## Design model

From the glossary, confirmed in source:

- `show` dismisses every other registered `DismissibleTooltip`, then adds the entry; `remove` unregisters.
- The default is the file-private `_sharedRegistry` in `just_tooltip.dart`; `JustTooltip.registry` injects another for test isolation or a scoped group.
- Only the `TooltipRegistry` type is exported; `show`, `remove`, `DismissibleTooltip` are `@internal`.
- Last to show wins — which is why it could not express nesting (ADR-0003 probes 1–2).

## Code

- `lib/src/tooltip_registry.dart` — `TooltipRegistry`, `show`, `remove`, `DismissibleTooltip`
- `lib/src/just_tooltip.dart` — `_sharedRegistry`, `_registry`, `dismissTooltip`
- Tests: `test/tooltip_registry_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — static `RawTooltip._openedTooltips` and `dismissAllToolTips()`; a hovered enter dismisses open tooltips no other device is hovering.

## Cross-cutting invariants

**None.**

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — `dismissTooltip` is `_hide`; registration lives in `_show` and both teardown paths.
- [target-tracking](target-tracking.md) — its per-frame cost bound assumes one visible tooltip.
- [nesting-suppression](nesting-suppression.md) — must stay orthogonal (ADR-0003).
- [public-surface](public-surface.md) — `registry` is a public parameter; the type is exported.

## Known holes / open

- The shared default is process-global; multiple independent app roots in one process share it. Nothing records whether that is intended.
