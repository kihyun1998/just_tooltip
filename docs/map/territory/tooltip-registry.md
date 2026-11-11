# Tooltip registry

## What it is

Enforces "one tooltip visible at a time" within a registry: showing one dismisses the one that
held the place, and the tooltips dismissed this way are re-derived once none holds it. Part of [arbitration](arbitration.md). Vocabulary:
[Tooltip Registry](../../../GLOSSARY.md#tooltip-registry).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — names the registry reactive and app-global, orthogonal to suppression, and rejects extending it with ancestry.
- [ADR-0007](../../adr/0007-a-host-gives-its-content-its-own-registry.md) — a host gives its content its own registry; which registry applies is chosen in the widget tree, not inside the registry (maintainer's call).
- [ADR-0010](../../adr/0010-a-keyboard-user-can-show-and-dismiss-a-tooltip.md) — a tooltip hidden by the registry comes back; amended by #113: only once no tooltip in its own registry holds the place (maintainer, 2026-11-11).

## Design model

From the glossary, confirmed in source:

- `_holder` is the one tooltip holding the place: shown, or fading out on its own hide. `show` makes the entry the holder and, when another held the place, moves that one into `_evicted` before calling its `dismissTooltip`, so a fade that ends at once (a zero `animationDuration`) and calls `remove` finds it no longer holding. At most one tooltip holds the place, because every show evicts the last holder; the evicted ones may still be fading out and do not hold it.
- `remove`, from `_endShow`, does nothing unless the entry holds the place; then it clears the holder and calls `reviveTooltip` on every evicted tooltip, once, emptying `_evicted`. So a show ending in another registry, or the end of an evicted tooltip's own fade, revives nothing. `show` takes the entry out of `_evicted`, so a tooltip that takes the place back does not wait to be revived. `forget`, from `dispose`, drops an evicted entry.
- Two parts of this are the implementer's derivation, not the maintainer's call: a holder fading out on its own hide still holds the place, so its evicted tooltips come back when its fade ends (what #111's tests already pinned); and `show` dismisses only the holder, not every registered tooltip, since the others are already evicted and fading.
- `forget` has no widget-level test: without it a disposed State stays in `_evicted` until the next revival, whose reconcile returns at `!mounted` (mutation survives the suite; the registry unit test pins `forget` itself).
- Before #113 the evicted tooltips sat in one static set in `just_tooltip.dart`, and every tooltip whose show ended re-derived all of them but itself: in a chain the first evicted came back when the middle one's fade ended, and dismissed the holder; a show ending in another registry did the same (measured, `test/just_tooltip_eviction_test.dart` red on efd4042).
- The default is the file-private `_sharedRegistry` in `just_tooltip.dart`; `JustTooltip.registry` injects another for test isolation or a scoped group.
- Resolution is `widget.registry ?? _inheritedContentRegistry ?? _sharedRegistry`. Each State owns `_contentRegistry`; the `_TooltipScope` around the overlay child carries it as `contentRegistry`, and the scope around the child passes on `_inheritedContentRegistry`, so a tooltip nested inside a content tooltip stays in that content. Before #84 a content tooltip shared the app-global registry with its host, and showing it dismissed the host and itself with it.
- Only the `TooltipRegistry` type is exported; `show`, `remove`, `forget`, `DismissibleTooltip` are `@internal`.
- Last to show wins — which is why it could not express nesting (ADR-0003 probes 1–2).

## Code

- `lib/src/tooltip_registry.dart` — `TooltipRegistry`, `_holder`, `_evicted`, `show`, `remove`, `forget`, `DismissibleTooltip` (`dismissTooltip`, `reviveTooltip`)
- `lib/src/just_tooltip.dart` — `_sharedRegistry`, `_registry`, `_contentRegistry`, `_inheritedContentRegistry`, `_TooltipScope.contentRegistry`, `dismissTooltip`, `reviveTooltip`, `_endShow` (`remove`), `dispose` (`forget`)
- Tests: `test/tooltip_registry_test.dart`, `test/just_tooltip_content_registry_test.dart`, `test/just_tooltip_eviction_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — static `RawTooltip._openedTooltips` and `dismissAllToolTips()`; a hovered enter dismisses open tooltips no other device is hovering.

## Cross-cutting invariants

- [a-show-ends-in-one-place](../invariant/a-show-ends-in-one-place.md)

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — `dismissTooltip` is `_hide`; registration lives in `_show` — a reverse-catch registers again — and `_endShow`, where both teardown paths end and the revival starts.
- [show-intent](show-intent.md) — `reviveTooltip` is a reconcile; whether the evicted tooltip shows again is its show intent's call.
- [target-tracking](target-tracking.md) — its per-frame cost bound assumes one visible tooltip.
- [nesting-suppression](nesting-suppression.md) — must stay orthogonal (ADR-0003); both read `_TooltipScope`, and the content scope's `state: null` (ADR-0005) and `contentRegistry` (ADR-0007) are set together.
- [public-surface](public-surface.md) — `registry` is a public parameter; the type is exported.

## Known holes / open

- The shared default is process-global; multiple independent app roots in one process share it. Nothing records whether that is intended.
- A tooltip whose `registry` changes while it is shown (#114) stays the old registry's holder, since `_endShow` reads the current `_registry`. The tooltips it evicted there wait for another show in that registry to end (measured with a probe for #113: before, the app-wide set brought them back when it hid; the same with a `TooltipRegistry()` created in a parent's `build` and the parent rebuilt while the evictor is shown — efd4042 `A=1`, after `A=0`), and the old registry still dismisses it on its next show. A tooltip evicted and then given another registry is not dropped by `forget` at dispose; the old registry keeps it until its next revival, which reconciles a disposed State that returns at `!mounted` (read, not run).
