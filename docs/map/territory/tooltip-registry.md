# Tooltip registry

## What it is

Enforces "one tooltip visible at a time" within a registry: showing one dismisses every other
registered tooltip. Part of [arbitration](arbitration.md). Vocabulary:
[Tooltip Registry](../../../GLOSSARY.md#tooltip-registry).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — names the registry reactive and app-global, orthogonal to suppression, and rejects extending it with ancestry.
- [ADR-0007](../../adr/0007-a-host-gives-its-content-its-own-registry.md) — a host gives its content its own registry; which registry applies is chosen in the widget tree, not inside the registry (maintainer's call).

## Design model

From the glossary, confirmed in source:

- `show` dismisses every other registered `DismissibleTooltip`, then adds the entry; `remove` unregisters.
- The default is the file-private `_sharedRegistry` in `just_tooltip.dart`; `JustTooltip.registry` injects another for test isolation or a scoped group.
- Resolution is `widget.registry ?? _inheritedContentRegistry ?? _sharedRegistry`. Each State owns `_contentRegistry`; the `_TooltipScope` around the overlay child carries it as `contentRegistry`, and the scope around the child passes on `_inheritedContentRegistry`, so a tooltip nested inside a content tooltip stays in that content. Before #84 a content tooltip shared the app-global registry with its host, and showing it dismissed the host and itself with it.
- Only the `TooltipRegistry` type is exported; `show`, `remove`, `DismissibleTooltip` are `@internal`.
- Last to show wins — which is why it could not express nesting (ADR-0003 probes 1–2).

## Code

- `lib/src/tooltip_registry.dart` — `TooltipRegistry`, `show`, `remove`, `DismissibleTooltip`
- `lib/src/just_tooltip.dart` — `_sharedRegistry`, `_registry`, `_contentRegistry`, `_inheritedContentRegistry`, `_TooltipScope.contentRegistry`, `dismissTooltip`
- Tests: `test/tooltip_registry_test.dart`, `test/just_tooltip_content_registry_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — static `RawTooltip._openedTooltips` and `dismissAllToolTips()`; a hovered enter dismisses open tooltips no other device is hovering.

## Cross-cutting invariants

**None.**

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — `dismissTooltip` is `_hide`; registration lives in `_show` and both teardown paths.
- [target-tracking](target-tracking.md) — its per-frame cost bound assumes one visible tooltip.
- [nesting-suppression](nesting-suppression.md) — must stay orthogonal (ADR-0003); both read `_TooltipScope`, and the content scope's `state: null` (ADR-0005) and `contentRegistry` (ADR-0007) are set together.
- [public-surface](public-surface.md) — `registry` is a public parameter; the type is exported.

## Known holes / open

- The shared default is process-global; multiple independent app roots in one process share it. Nothing records whether that is intended.
