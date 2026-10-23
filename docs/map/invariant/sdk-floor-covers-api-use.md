# The SDK floor covers every SDK API the code uses

## The fact

`pubspec.yaml`'s `environment` lower bound is at least the first Flutter/Dart release that ships
every SDK API `lib/` calls. Checkable: for each SDK symbol whose signature changed recently,
`cd /d/flutter && git log -S "<signature>"` then `git tag --contains <sha>` is ≤ the declared floor.

## Why it is cross-cutting

The two sites never meet in any build here. `_JustTooltipState._ancestorClip` calls
`describeApproximatePaintClip` on `RenderObject.parent`, which is `RenderObject?` only from Flutter
3.13 (it was `AbstractNode?`). `pubspec.yaml` `environment` declares `flutter: ">=3.13.0"` and the
comment above it says why. `flutter analyze` runs on the installed SDK and CI pins 3.41.9
(`.github/workflows/ci.yml` — `FLUTTER_VERSION`), so code can adopt a newer API and stay green while
the floor lies; consumers resolving at the floor are the first to compile it.

## Territories it holds in

- [release](../territory/release.md) — `pubspec.yaml` `environment`.
- [target-resolution](../territory/target-resolution.md) — `_ancestorClip`, today's floor-setting call.

## What a violation looks like

Everything here green; a consumer on an older SDK gets a compile error in `just_tooltip`'s own
source after `flutter pub get`, because `^0.4.x` admitted the new patch.

## Discovery history

- #38 — declared `>=3.10.0` while using `RenderObject? get parent` (3.13+); the raise reached `table_plus#69` (`docs/agents/lessons.md`, "membrane propagation").

## Where it will recur

Any change in `lib/` that calls an SDK member not already used, or whose type changed across
releases. Nothing builds at the floor, so the check is by hand.
