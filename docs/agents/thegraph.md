# thegraph — just_tooltip

## What this project is

A Flutter tooltip package (pub.dev `just_tooltip`) — a core whose identity is its boundary. It is
a tooltip engine, and it stays correct by *not* absorbing its consumers' concerns.

## References

| Source | Informs | Reached by | Binding |
|---|---|---|---|
| Flutter SDK `rendering/` `widgets/` `gestures/` | how it works | `packages/flutter/lib/src/` checkout — macOS `~/development/flutter`, Windows `/d/flutter` — raw | **binding** |
| Flutter `widgets/raw_tooltip.dart` (+ `material/tooltip.dart`, a thin Material shell) | how it works | same checkout — raw | example |
| `super_tooltip` | how it works | `github.com/bensonarafat/super_tooltip` — raw tree | example |
| `flutter_portal` | how it works | `github.com/fzyzcjy/flutter_portal` — raw tree | example |
| `el_tooltip` | how it works | `github.com/marcelogil/el_tooltip` — raw tree | example |
| the `lib/src/` layout of the packages above | where files go | same trees — raw | example |
| pub.dev API | what is actually published | `curl https://pub.dev/api/packages/just_tooltip` — raw | binding |

**None of the third-party packages above does Visible Rect (the ancestor clip walk)** — checked
(`describeApproximatePaintClip` has 0 hits, `material/tooltip.dart` included). The only
implementation is Flutter's `rendering/`. Aligning with the peers would not be a fix but the
deletion of a mechanism.

## Proof · gates · release

- **A consumer round trip is the strongest proof.** Temporarily wire the local build into a
  consumer repo with `dependency_overrides` (without touching its `pubspec.yaml`) and run its full
  suite. Strongest evidence = a consumer test that froze the bug as its expected value *breaks*;
  everything else passing = no regressions. Afterwards revert `pubspec_overrides.yaml` and the
  generated files `flutter pub get` produced. **A synthetic in-repo repro passes only in the
  *imagined tree*** (#34).
- **Gates CI doesn't run — by hand before publishing.** `cd example && flutter analyze`,
  `flutter pub publish --dry-run` (0 warnings). CI (`.github/workflows/ci.yml`, the actual
  source) is **pinned to Flutter 3.41.9**, so it **does not build** at the `environment` floor
  (3.32) — when using a new SDK API, raise the floor by hand and check it. Neither
  `flutter analyze` nor pub.dev catches it (#38).
- **After touching `environment`, run `flutter pub get` before the gates.** The language version
  comes from it, and `dart format` changes style at 3.7; a check on the stale `package_config`
  passes locally and fails in CI (#88→#89).
- **`flutter pub publish` cannot be undone (retract only). Agents never run it — the user does.**
- **In the 0.x range `^0.4.0` does not accept `0.5.0`** — a bug fix shipped as a minor reaches no
  one. Blast radius = reach × size of change; even if wide, a change that "only ever moves toward
  the right answer" is a patch (#33).
- **Branch → PR → merge.** Commit as `type(scope): … (#n)`, open a squash PR with `Closes #n`,
  merge once CI is green.
- **Never tie `--delete-branch` to a stacked PR's merge call** — the child PR gets CLOSED
  (#48→#49). Order: `gh pr merge <lower> --squash` → confirm the child moved onto main → *then*
  delete.
