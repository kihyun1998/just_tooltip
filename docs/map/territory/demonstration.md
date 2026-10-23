# Demonstration

## What it is

The example app and the spike: where the package's behaviour is shown to a reader and where
consumer policy (anchor choice, theme values, when to show) is modelled. Not a test.

## Governing decisions

**None** in `docs/adr/`. The open migration is specified on #60 (closed; its spec is the contract
for #62–#64) under the planning map #52.

## Design model

From the spike header and the open issues:

- A header comment is a specification: promise only what the screen can show (#37).
- `spike_wide_row.dart` is a development harness run with `flutter run -t`, holding the shapes behind #21/#22/#24/#26/#33 — including an Overlay inset from the window, the only demonstration of [overlay-coordinate-space](../invariant/overlay-coordinate-space.md). It is not a menu item and #64 must not copy from it.
- Planned (#62–#64): the example moves onto the `flutter_example_template` shell. Recipes import only `dart:`, `package:flutter/`, `package:just_tooltip/`; every knob has a default that is the feature's standard look; `nesting_recipe` and `content_recipe` show the two #22 contracts as behaviour.
- #62's pass condition, which no gate checks: the tooltip must be created inside `PreviewStage`'s own Overlay, because `Overlay.of(context)` finds the nearest.

## Code

- `example/lib/main.dart` — `PlaygroundApp`, `PlaygroundPage`
- `example/lib/spike_wide_row.dart` — `SpikeApp` and its header comment
- `example/test/widget_test.dart`, `example/pubspec.yaml`
- Planned, not built: `example/lib/app/destinations.dart`, `example/lib/pages/playground_page.dart`, `example/lib/recipes/`, `example/lib/scenarios/truncating_list_scenario.dart` (#62, #63, #64)

## Reference behaviour

- `flutter_example_template` shell and `flutter_table_plus/example/lib/` as the shape to follow (#62–#64 bodies; paths there are the maintainer's macOS checkouts).

## Cross-cutting invariants

- [overlay-coordinate-space](../invariant/overlay-coordinate-space.md)

## Blast radius

- [target-resolution](target-resolution.md), [target-tracking](target-tracking.md), [nesting-suppression](nesting-suppression.md), [content](content.md) — the spike header and the planned recipes describe them; a behaviour change can falsify a comment without failing anything.
- [release](release.md) — `example/lib` ships; example gates are local-only.

## Known holes / open

- Example → shell migration. Tracked: #62, #63, #64.
- Nothing checks that a header comment still describes the code.
