# The SDK floor covers every SDK API the code uses

## The fact

`pubspec.yaml`'s `environment` lower bound is at least the first Flutter/Dart release that ships
every SDK API `lib/` calls. Checkable: for each SDK symbol whose signature changed recently,
`cd /d/flutter && git log -S "<signature>"` then `git tag --contains <sha>` is ≤ the declared floor.

## Why it is cross-cutting

The two sites never meet in any build here. `_JustTooltipState.build` calls
`OverlayPortal.overlayChildLayoutBuilder`, first in Flutter 3.32.0 (`git tag --contains`), and
`pubspec.yaml` `environment` declares `flutter: ">=3.32.0"` with the comment above it saying why.
Before it, `_ancestorClip` set the floor: it calls `describeApproximatePaintClip` on
`RenderObject.parent`, which is `RenderObject?` only from Flutter 3.13 (it was `AbstractNode?`). `flutter analyze` runs on the installed SDK and CI pins 3.41.9
(`.github/workflows/ci.yml` — `FLUTTER_VERSION`), so code can adopt a newer API and stay green while
the floor lies; consumers resolving at the floor are the first to compile it.

## Territories it holds in

- [release](../territory/release.md) — `pubspec.yaml` `environment`.
- [target-resolution](../territory/target-resolution.md) — `_ancestorClip`, the floor-setting call until ADR-0008.
- [target-tracking](../territory/target-tracking.md) — `OverlayPortal.overlayChildLayoutBuilder`, today's floor-setting call.

## What a violation looks like

Everything here green; a consumer on an older SDK gets a compile error in `just_tooltip`'s own
source after `flutter pub get`, because `^0.4.x` admitted the new patch.

## Discovery history

- #38 — declared `>=3.10.0` while using `RenderObject? get parent` (3.13+); the raise reached `table_plus#69` (`docs/agents/lessons.md`, "membrane propagation").
- #83 / ADR-0008 — raised to 3.32 on purpose, in the 0.5.0 breaking release; flutter_password_input (`sdk: ">=3.4.0"`, no Flutter floor) has to follow.

## Where it will recur

Any change in `lib/` that calls an SDK member not already used, or whose type changed across
releases. Nothing builds at the floor, so the check is by hand.
