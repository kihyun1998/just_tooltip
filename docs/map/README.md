# MAP — just_tooltip

<!-- grill-map build stamp: 024bd2d -->
<!-- grill-map synced at: 881d104 (2026-10-06) -->

The territory map. A comment's why, trap and measured value go to a note here. Notes are added as they come up, or all at once with `grill-map`, which also reads hand-written notes as leads and keeps their paths.

## The two questions

1. **If I touch this, what else moves?** Open the territory you are entering and read its
   `## Blast radius` — a checklist. Opening a listed territory and finding nothing to do is a
   correct outcome; not opening it is the miss. Then follow `## Cross-cutting invariants`.
2. **What decision is this derived from?** Read `## Governing decisions`, then
   `## Reference behaviour`. A **None.** is the answer, not an omission.

## Territories

Visibility — [visibility-chain](territory/visibility-chain.md) (aggregate):
[hover-intent](territory/hover-intent.md) ·
[visibility-scheduling](territory/visibility-scheduling.md) ·
[visibility-lifecycle](territory/visibility-lifecycle.md) ·
[programmatic-control](territory/programmatic-control.md) ·
[tap-trigger](territory/tap-trigger.md)

Aim — [target-resolution](territory/target-resolution.md) ·
[placement](territory/placement.md) ·
[target-tracking](territory/target-tracking.md) ·
[live-configuration](territory/live-configuration.md)

Who shows — [arbitration](territory/arbitration.md) (aggregate):
[nesting-suppression](territory/nesting-suppression.md) ·
[tooltip-registry](territory/tooltip-registry.md) ·
[content](territory/content.md)

Look — [painting](territory/painting.md) · [transitions](territory/transitions.md)

Outside — [public-surface](territory/public-surface.md) ·
[release](territory/release.md) · [demonstration](territory/demonstration.md)

## Invariants

[overlay-coordinate-space](invariant/overlay-coordinate-space.md) ·
[overlay-rebuild-is-post-frame](invariant/overlay-rebuild-is-post-frame.md) ·
[a-still-pointer-sends-no-edge](invariant/a-still-pointer-sends-no-edge.md) ·
[sdk-floor-covers-api-use](invariant/sdk-floor-covers-api-use.md)

## Conventions

- Headings are exact English strings across every note; an empty section holds `**None.**`.
- Symbols, never line numbers. Plain relative links.
- Link a fact, never restate it; an issue is cited as evidence, `Tracked: #N` for open work.
- Every claim carries its evidence (a symbol, a record, a commit) or its source and date `(maintainer, yyyy-mm-dd)`.
- Vocabulary is [`GLOSSARY.md`](../../GLOSSARY.md); decisions are [`docs/adr/`](../adr/).

```sh
rg -lU '## Governing decisions\r?\n(\r?\n)?\*\*None\.\*\*' docs/map/territory/   # nobody decided
rg -lU '## Reference behaviour\r?\n(\r?\n)?\*\*None\.\*\*' docs/map/territory/   # never compared
```

## What this map cannot answer

Source files and issues are text inside notes, not nodes. It tracks no status. It is not a call
graph: territory edges are change-blast edges, and two areas that share an assumption without a
call get an invariant note instead.

## Scope, and what an absent note means

Covers `lib/`, `test/` (each territory's `## Code` names its tests), `example/`, the manifest,
`.pubignore`, CI and the release path. Out of scope: `docs/agents/` (working discipline, read by
it, not by the system), generated output (`build/`, `coverage/`, `.dart_tool/`, IDE files,
`example/` platform runners). A territory appears when something in the repo commits to it — code,
a record, or an open issue with a design (#62–#64 are why `demonstration` lists planned files).

Not built, and nothing commits to building them, so they have no note: **accessibility** — no
`Semantics` anywhere in `lib/`, where Flutter's `RawTooltip` wraps its child in
`Semantics(tooltip:)`; and **keyboard/focus** — no trigger on focus, no dismiss key.

## What the orientation found

A single Flutter package whose `lib/src/just_tooltip.dart` holds most of the behaviour: fourteen of
the seventeen territories name it (`grep -l 'lib/src/just_tooltip\.dart' docs/map/territory/*.md`) under `## Code`, and the map is deliberately finer than the
files. Five ADRs govern the visibility chain, the controller and arbitration (0001–0004, 0006), and one the overlay (0005); **nothing records
decisions about geometry** — target resolution, placement, tracking and painting are governed only
by issues, the glossary and the changelog, and that is where the known bugs land (#65 in placement; #72 in placement's inputs). The reference implementation is Flutter's `RawTooltip`, which converges with this
package more than earlier notes claimed (exclusive nested regions, a global open list, a 100 ms
exit delay) and diverges on the visible-rect anchor and content gating.
