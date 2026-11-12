# Tooltip registry

## What it is

Enforces "one tooltip visible at a time" within a registry: showing one dismisses the one that
held the place, and the tooltips dismissed this way are re-derived once none holds it. Part of [arbitration](arbitration.md). Vocabulary:
[Tooltip Registry](../../../GLOSSARY.md#tooltip-registry).

## Governing decisions

- [ADR-0003](../../adr/0003-nesting-suppression-gates-a-derived-hover-intent.md) — names the registry reactive and app-global, orthogonal to suppression, and rejects extending it with ancestry.
- [ADR-0007](../../adr/0007-a-host-gives-its-content-its-own-registry.md) — a host gives its content its own registry; which registry applies is chosen in the widget tree, not inside the registry (maintainer's call); amended by #114: a tooltip whose registry changes moves to the new one at once (maintainer, 2026-11-11).
- [ADR-0010](../../adr/0010-a-keyboard-user-can-show-and-dismiss-a-tooltip.md) — a tooltip hidden by the registry comes back; amended by #113: only once no tooltip in its own registry holds the place (maintainer, 2026-11-11); amended by #116: before that, it shows again only on a new trigger act (maintainer, 2026-11-12).

## Design model

From the glossary, confirmed in source:

- `_holder` is the one tooltip holding the place: shown, or fading out on its own hide. `show` makes the entry the holder and, when another held the place, moves that one into `_evicted` before calling its `dismissTooltip`, so a fade that ends at once (a zero `animationDuration`) and calls `remove` finds it no longer holding. At most one tooltip holds the place, because every show evicts the last holder; the evicted ones may still be fading out and do not hold it.
- `remove`, from `_endShow`, does nothing unless the entry holds the place; then it clears the holder and calls `reviveTooltip` on every evicted tooltip, once, emptying `_evicted`. So a show ending in another registry, or the end of an evicted tooltip's own fade, revives nothing. `show` takes the entry out of `_evicted`, so a tooltip that takes the place back does not wait to be revived. `forget`, from `dispose`, drops an evicted entry.
- Two parts of this are the implementer's derivation, not the maintainer's call: a holder fading out on its own hide still holds the place, so its evicted tooltips come back when its fade ends (what #111's tests already pinned); and `show` dismisses only the holder, not every registered tooltip, since the others are already evicted and fading.
- **The record gates the evicted tooltip's own show intent** (ADR-0010 as amended by #116). `isEvicted` answers whether an entry sits in `_evicted`; `_reconcileShowIntent` reads it and lets an evicted tooltip gain show intent only on a new trigger act ([show-intent](show-intent.md)). It needs no state of its own: an entry is in `_evicted` exactly from its eviction until `remove` revives it, `take` makes it the holder again, or `forget`/`leave` drops it, and `keepsWaiting`/`wait` put it back when a revival finds another holder. Since every path that clears `_holder` also empties `_evicted`, an entry recorded there always has a holder other than itself.
- `forget` has no widget-level test: without it a disposed State stays in `_evicted` until the next revival, whose reconcile returns at `!mounted` (mutation survives the suite; the registry unit test pins `forget` itself).
- Before #113 the evicted tooltips sat in one static set in `just_tooltip.dart`, and every tooltip whose show ended re-derived all of them but itself: in a chain the first evicted came back when the middle one's fade ended, and dismissed the holder; a show ending in another registry did the same (measured, `test/just_tooltip_eviction_test.dart` red on efd4042).
- The default is the file-private `_sharedRegistry` in `just_tooltip.dart`; `JustTooltip.registry` injects another for test isolation or a scoped group.
- Resolution is `widget.registry ?? _inheritedContentRegistry ?? _sharedRegistry`, done in `_syncRegistry` only — from `didUpdateWidget` and `_readScope` (`didChangeDependencies`, `activate`) — and kept in the `_registry` field, so a show registers, ends and is forgotten in one registry. Each State owns `_contentRegistry`; the `_TooltipScope` around the overlay child carries it as `contentRegistry`, and the scope around the child passes on `_inheritedContentRegistry`, so a tooltip nested inside a content tooltip stays in that content. Before #84 a content tooltip shared the app-global registry with its host, and showing it dismissed the host and itself with it.
- **A tooltip whose registry changes moves at once** (ADR-0007 as amended by #114; maintainer, 2026-11-11). `_syncRegistry` calls `leave` on the old registry — it drops the entry from `_evicted` and, when the entry holds the place, does what `remove` does: clears it and revives the evicted tooltips. Then a tooltip that was evicted calls `wait` on the new one (it waits there to be revived, or is revived when nothing holds the place), and a shown tooltip that passes `_show`'s gates — not fading out, with content, not Covered — calls `take`, which makes it the holder and records the previous holder as evicted at once; that holder's `dismissTooltip` runs in a microtask through `dismissEvicted`, which skips it if it took the place back meanwhile. The evicted case, the gates and the fading-out case (leaves, does not join) are the implementer's derivation, recorded in the ADR. Pinned in `test/just_tooltip_registry_change_test.dart`; seven of its tests were red on 61223c9, where the registry was re-resolved on every read: the show stayed registered in the old registry, which kept dismissing it, while `_endShow` and `dispose` reported to the new one.
- **Why the record moves at once but the dismissal waits.** `_syncRegistry` runs inside a build (`didUpdateWidget`, `didChangeDependencies`). Dismissing there reversed a zero-length fade synchronously, and a `scale`, `slide` or `rotation` transition (an `AnimatedWidget`) outside the building subtree called `setState` during build — Flutter's debug assertion (measured with a probe; no earlier path called the registry during build). Deferring the whole join instead broke a group move, below. The gates are read synchronously because the new widget is already in place: checked later, a tooltip that lost its content in the same rebuild dismissed the new registry's holder first (measured).
- **A revival is checked when it runs.** `reviveTooltip` defers to a microtask and then asks `keepsWaiting`: when another tooltip holds the place in the registry the tooltip belongs to by then, it waits again instead of reconciling. This is what keeps a group move whole — a `TooltipRegistry()` created in a parent's `build` moves every tooltip of the group in one rebuild, and the holder leaving the old registry revives its evicted tooltips there before they reach the new one. Checked at once, the evicted A came back and dismissed X in either tree order (measured, `A=1 X=0`); now A waits for X in the new registry. Pinned in both orders.
- The inherited content registry changes only when the tooltip, or an enclosing tooltip with it, is moved by a `GlobalKey`: the overlay scope's `_contentRegistry` is `final`, and a child scope passes on its tooltip's own inherited registry. `deactivate` ends the show before `activate` re-reads the scope, so on that path only an evicted record moves, and the tooltip waits in its new registry; `activate`'s own reconcile is not a new trigger act, so it does not show the tooltip while that registry has a holder (#116). `_readScope` reads the scope with `getInheritedWidgetOfExactType`, so a scope change alone does not call `didChangeDependencies` (see Known holes for where that misses a change).
- Only the `TooltipRegistry` type is exported; `show`, `take`, `isEvicted`, `dismissEvicted`, `remove`, `forget`, `leave`, `wait`, `keepsWaiting`, `DismissibleTooltip` are `@internal`.
- Last to show wins — which is why it could not express nesting (ADR-0003 probes 1–2).

## Code

- `lib/src/tooltip_registry.dart` — `TooltipRegistry`, `_holder`, `_evicted`, `show`, `take`, `isEvicted`, `dismissEvicted`, `remove`, `forget`, `leave`, `wait`, `keepsWaiting`, `DismissibleTooltip` (`dismissTooltip`, `reviveTooltip`)
- `lib/src/just_tooltip.dart` — `_sharedRegistry`, `_registry`, `_syncRegistry`, `_contentRegistry`, `_inheritedContentRegistry`, `_TooltipScope.contentRegistry`, `dismissTooltip`, `reviveTooltip`, `_endShow` (`remove`), `dispose` (`forget`)
- Tests: `test/tooltip_registry_test.dart`, `test/just_tooltip_content_registry_test.dart`, `test/just_tooltip_eviction_test.dart`, `test/just_tooltip_registry_change_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — static `RawTooltip._openedTooltips` and `dismissAllToolTips()`; a hovered enter dismisses open tooltips no other device is hovering.

## Cross-cutting invariants

- [a-show-ends-in-one-place](../invariant/a-show-ends-in-one-place.md)
- [show-intent-drops-after-settling-a-fading-close](../invariant/show-intent-drops-after-settling-a-fading-close.md)

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — `dismissTooltip` is `_hide`, after settling a close already fading out ([show-intent](show-intent.md)); registration lives in `_show` — a reverse-catch registers again — and `_endShow`, where both teardown paths end and the revival starts.
- [show-intent](show-intent.md) — `reviveTooltip` is a reconcile; whether the evicted tooltip shows again is its show intent's call, and until the revival its show intent reads `isEvicted`.
- [target-tracking](target-tracking.md) — its per-frame cost bound assumes one visible tooltip.
- [nesting-suppression](nesting-suppression.md) — must stay orthogonal (ADR-0003); both read `_TooltipScope`, and the content scope's `state: null` (ADR-0005) and `contentRegistry` (ADR-0007) are set together; `_readScope` also re-resolves the registry, which can move an evicted record.
- [public-surface](public-surface.md) — `registry` is a public parameter; the type is exported.

## Known holes / open

- The shared default is process-global; multiple independent app roots in one process share it. Nothing records whether that is intended.
- A tooltip moved by a `GlobalKey` together with an enclosing tooltip keeps the content registry of its old place. `activate` runs top-down: the inner tooltip's `_readScope` reads the enclosing tooltip's `_TooltipScope` before that tooltip has rebuilt it, and since the read registers no dependency nothing reads it again (a `tap: TooltipTap.observe` tooltip, which depends on `MediaQuery`, does re-read). Measured with a probe (#114's lens, F1): A wrapping T moved into host H's content, then `t.show()` — T showed on the shared registry and dismissed H, so the content went with it (`hostBody=0`), on 61223c9 and after #114 alike. The reverse move leaves T in a dead host's `_contentRegistry`. A dependency read (`dependOnInheritedWidgetOfExactType`; `updateShouldNotify` already compares `contentRegistry`) would close it, against `_readScope`'s note that the enclosing tooltip's identity is stable — true of `state`, not of `contentRegistry`. Not fixed: it predates #114.
