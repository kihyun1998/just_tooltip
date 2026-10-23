# Transitions

## What it is

How the tooltip animates in and out: a pure transform from an already-curved `Animation<double>`
and a `TooltipTransitionSpec` to a wrapped widget. Vocabulary: [Transition Spec](../../../GLOSSARY.md#transition-spec).

## Governing decisions

**None.**

## Design model

From the glossary, confirmed in source:

- `TooltipTransitions.build` owns no lifecycle; the State owns the `AnimationController` and `CurvedAnimation`.
- Seven `TooltipAnimation` values; composite ones nest (`fadeScale` = fade(scale), `fadeSlide`, `rotation` = fade(rotate)).
- Slide uses the spec's `direction`, which `_buildAnimatedChild` sets to `_resolvedDirection ?? widget.direction` — the resolved one. The glossary's "uses the *preferred* `direction`" is stale against this.

## Code

- `lib/src/tooltip_transitions.dart` — `TooltipTransitionSpec`, `TooltipTransitions.build`, `_fade`, `_scale`, `_slideOffset`
- `lib/src/just_tooltip.dart` — `_buildAnimatedChild`, `_animation`
- `lib/src/enums.dart` — `TooltipAnimation`
- Tests: `test/tooltip_transitions_test.dart`

## Reference behaviour

**None.**

## Cross-cutting invariants

**None.**

## Blast radius

- [placement](placement.md) — slide direction is placement's resolved output.
- [visibility-lifecycle](visibility-lifecycle.md) — the animation status this wraps decides when the entry is removed.
- [public-surface](public-surface.md) — `animation`, `fadeBegin`, `scaleBegin`, `slideOffset`, `rotationBegin`, `animationCurve`, `animationDuration`.

## Known holes / open

- `GLOSSARY.md` → Transition Spec says slide uses the preferred direction; the code uses the resolved one. The fix to that glossary line exists only on the unmerged branch `docs/map-and-thegraph` (b0c182d, 2026-08-25).
