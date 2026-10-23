# thegraph — just_tooltip

## What this project is

A Flutter tooltip engine whose identity is its boundary: it owns the mechanism and leaves policy to consumers (see `CLAUDE.md`).

## References

| Source | Informs | Reached by | Binding |
|---|---|---|---|
| Flutter SDK (rendering, widgets, gestures) | how it works | local source tree `/d/flutter/packages/flutter/lib/src/` — raw | binding |
| Flutter `RawTooltip` (`material/tooltip.dart` is a thin shell over it) | how it works | `/d/flutter/packages/flutter/lib/src/widgets/raw_tooltip.dart` — raw | example |
