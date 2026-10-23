# Placement

## What it is

Lays the tooltip body out beside a target rect: preferred direction with flip-to-opposite,
cross-axis alignment (RTL-mirrored for top/bottom), `offset` gap, `crossAxisOffset`, size
constrained and position clamped by `screenMargin`, and the arrow centre for `*TargetCenter`
alignments.

## Governing decisions

**None.**

## Design model

From reading only:

- `JustTooltipPositionDelegate` is a `SingleChildLayoutDelegate`, so it decides with the measured child size during layout.
- `getConstraintsForChild` caps the body at the Overlay minus `screenMargin` on each side.
- Flip: if the preferred side lacks space and the opposite has it, flip; if neither fits, keep the preferred side and let the clamp decide. The flip is single-axis — it never tries the cross axis.
- The resolved direction is reported out through `onDirectionResolved` and is what the arrow and the slide transition use (`_resolvedDirection ?? widget.direction`).
- RTL mirrors `start`↔`end` (and the `*TargetCenter` pair) for top/bottom in one function, `resolveTooltipAlignment`, which the delegate and `_buildOverlayEntry` (for the painter) both call — before layout, since a flip never changes the axis, so unlike the resolved direction it needs no post-frame hop. Until #70 the delegate mirrored a local copy and the painter got `widget.alignment`, so in RTL the arrow of a `start`/`end` tooltip pointed past the target (measured: arrow tip at x 288 / 512 for a target spanning 350–450). The direction it mirrors by is the Overlay's, not the tooltip's (#72).
- Where it will recur: any value the delegate resolves from widget input — a mirrored offset, a new alignment, a cross-axis fallback — that the painter or the transitions also read. Derive it once and hand the result to every reader, as `resolveTooltipAlignment` and `onDirectionResolved` do; a second derivation from `widget` is how #70 happened. (This was the invariant note `alignment-means-one-edge` until #70 made both sites call one function, which no longer meets the invariant bar.)
- With a zero-size (pointer) target, `start`/`center`/`end` say which of the tooltip's own edges lands on the pointer (`GLOSSARY.md` → Anchor).

## Code

- `lib/src/tooltip_position_utils.dart` — `resolveTooltipAlignment`, `JustTooltipPositionDelegate`, `getConstraintsForChild`, `getPositionForChild`, `_hasSpace`, `_flip`, `_computeOffset`, `_crossAxisX`, `_crossAxisY`, `shouldRelayout`, `onDirectionResolved`, `onArrowCenterResolved`
- `lib/src/just_tooltip.dart` — `_buildOverlayEntry` (constructs the delegate), `_resolvedDirection`, `_arrowCenterOffset`
- `lib/src/enums.dart` — `TooltipDirection`, `TooltipAlignment`
- Tests: `test/just_tooltip_test.dart`, `test/just_tooltip_rtl_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `_TooltipPositionDelegate` / `positionDependentBox`: vertical only, `preferBelow` + `verticalOffset`. Never compared against this delegate beyond that.

## Cross-cutting invariants

- [overlay-coordinate-space](../invariant/overlay-coordinate-space.md) — `screenMargin` clamps against the Overlay, not the window.
- [overlay-rebuild-is-post-frame](../invariant/overlay-rebuild-is-post-frame.md) — both resolved values leave layout through deferred rebuilds.

## Blast radius

- [painting](painting.md) — the arrow's edge comes from the resolved direction and its position from `arrowCenterOverride`.
- [transitions](transitions.md) — slide enters from the resolved direction.
- [hover-intent](hover-intent.md) — hover assumes the body never lands under the pointer: a body clamped onto the target is hit first, the child gets `onExit`, and hiding uncovers it again — placement can cause hover edges.
- [visibility-scheduling](visibility-scheduling.md) — whether a body under the pointer survives is decided there (`interactive` arms the bridge and `onTooltipEnter` cancels it; non-interactive hides at once).
- [target-resolution](target-resolution.md) — the delegate knows the target only as one rect; any placement rule about the pointer needs resolution to hand it more.
- [public-surface](public-surface.md) — `direction`, `alignment`, `offset`, `crossAxisOffset`, `screenMargin` and their dartdoc.

## Known holes / open

- When neither side fits, the clamp can put the body under the pointer and a hover tooltip toggles every frame. Tracked: #65.
- An RTL `Directionality` below the Overlay is ignored: the direction is read from the overlay entry's context. Tracked: #72.
- `_crossAxisX` / `_crossAxisY` push `crossAxisOffset` inward only for `end`, so `endTargetCenter` is pushed outward (from reading). Tracked: #73.
- The `targetRect` dartdoc says to resolve it with `localToGlobal(Offset.zero, ancestor: overlayBox)`; `_resolveTarget` deliberately does not (the `Transform.scale` extent).
