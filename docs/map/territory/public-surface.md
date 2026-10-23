# Public surface

## What it is

What consumers can name: the export barrel, `JustTooltip`'s parameters and dartdoc, the enums,
`JustTooltipTheme`, `JustTooltipController` and the `TooltipRegistry` type — and the policy
boundary they draw (`CLAUDE.md`: consumers own anchor choice, theme values, `show()` timing,
content, hover enabling).

## Governing decisions

- [ADR-0002](../../adr/0002-controller-is-attach-based-not-changenotifier.md) — the controller's public shape and the 0.3.0 break.

## Design model

From reading, with consumer evidence:

- `lib/just_tooltip.dart` exports `enums`, the widget, the controller (`hide JustTooltipControllerTarget`), the theme, and `TooltipRegistry` only. Scheduler, position delegate, overlay, painter, transitions are internal.
- All three sibling consumers re-export from this barrel: `flutter_folderview` (d925465, 2026-10-21, `lib/flutter_folderview.dart`), `flutter_table_plus` (af801af, 2026-10-06, `lib/flutter_table_plus.dart`), `flutter_password_input` (84d6261, 2026-10-06, `lib/flutter_password_input.dart`). Narrowing an export is a transitive break for their consumers, and nothing here fails.
- Dartdoc on `enums.dart`, the widget fields and the controller is pub.dev's API reference and has been the last surface to describe a fixed bug as a contract (#37).
- Internal contracts are `@internal` and hidden from the barrel but importable via `src/`.

## Code

- `lib/just_tooltip.dart` — the barrel
- `lib/src/just_tooltip.dart` — `JustTooltip` (constructor and fields)
- `lib/src/enums.dart` — `TooltipAnimation`, `TooltipAnchor`, `TooltipDirection`, `TooltipAlignment`
- `lib/src/just_tooltip_theme.dart` — `JustTooltipTheme`
- `lib/src/just_tooltip_controller.dart` — `JustTooltipController`
- `lib/src/tooltip_registry.dart` — `TooltipRegistry`
- Derived (a tool can see it): `rg -n '^export' lib/just_tooltip.dart`; `rg -n '^  final ' lib/src/just_tooltip.dart lib/src/just_tooltip_theme.dart`
- Hand-written (no tool can see it): the re-exporting consumers above; `acra_client` per `docs/downstream-consumers.md`.

## Reference behaviour

**None.**

## Cross-cutting invariants

**None.**

## Blast radius

- [release](release.md) — any change here decides whether the release is breaking and which version reaches whom.
- [demonstration](demonstration.md) — README snippets and the example use these names.
- Every behavioural territory whose parameter is declared here: [target-resolution](target-resolution.md), [placement](placement.md), [visibility-scheduling](visibility-scheduling.md), [content](content.md), [painting](painting.md), [transitions](transitions.md), [tap-trigger](tap-trigger.md), [programmatic-control](programmatic-control.md), [tooltip-registry](tooltip-registry.md) — a changed behaviour falsifies the dartdoc here.

## Known holes / open

- No gate on dartdoc describing current behaviour.
- `JustTooltip`'s constructor asserts `message != null || tooltipBuilder != null` in debug only.
