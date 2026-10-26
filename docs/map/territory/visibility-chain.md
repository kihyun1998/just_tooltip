# Aggregate — the visibility chain

**This note owns no detail.** Four layers, each fed only by the one above it.

| Concept | Note |
|---|---|
| pointer facts → a derived boolean, transitions only | [show-intent](show-intent.md) |
| transitions → timed show/hide requests | [visibility-scheduling](visibility-scheduling.md) |
| requests → intent `_isShowing` → render state | [visibility-lifecycle](visibility-lifecycle.md) |
| commands that enter below show intent | [programmatic-control](programmatic-control.md), [tap-trigger](tap-trigger.md) |

## Why they sit together

`pointer facts → show intent → intent (_isShowing) → render state (AnimationController)`
(`GLOSSARY.md` → Intent vs Render State). Each layer reads the one above and writes nothing back:
the scheduler never sees an edge or an animation status (ADR-0001), the lifecycle never sees a
timer.

## Where each input enters

Hover enters at the top and is the only input gated by suppression and the hover formula. Tap
enters at the scheduler (`onTap`). A controller enters at the lifecycle (`showTooltip` → `_show`,
plus `startAutoHide`). So "is this suppressed / content-gated / delayed?" is answered by where the
input enters: only `_show`'s content guard covers all three, which is why content loss needs its own
direct hide ([content](content.md)).
