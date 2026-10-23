# Release

## What it is

Getting a version to pub.dev and to the consumers: the manifest (version, SDK floor), what the
archive contains, CI, the changelog and README migration sections, publishing, and closing the
downstream loop.

## Governing decisions

**None.** The rules live as working discipline in `docs/agents/theflow.md` Step 7 and `docs/downstream-consumers.md`, not as decision records.

## Design model

From the bindings and history, confirmed where the repo can show it:

- CI (`.github/workflows/ci.yml`) runs `pub get`, repo-wide `dart format --set-exit-if-changed`, `analyze`, `test` on Flutter 3.41.9 pinned. It does not analyse or test `example/`, does not run `pub publish --dry-run`, and never builds at the declared floor.
- `.pubignore` replaces `.gitignore` for pub, so everything git ignores is repeated there (`coverage/`, `pubspec.lock`, `build/`), plus internal docs and example platform dirs.
- `CHANGELOG.md` entries are publish-time snapshots; a correction opens a new version.
- On `0.x`, `^0.4.0` does not admit `0.5.0`: a fix shipped as a minor reaches nobody (ADR-0004 consequences; 0.4.4 shipped as a patch).
- A deprecation inside the consumers' caret range turns their `flutter analyze` red, because an info is fatal there by default and no consumer commits `pubspec.lock`. Measured for #66 (2026-10-23): flutter_folderview, flutter_table_plus and flutter_password_input went from rc 0 to rc 1 on `deprecated_member_use` of `enableTap`. So #66 ships as `0.5.0`, which `^0.4.4` does not admit and each consumer takes with its migration (maintainer, 2026-10-23).
- Publishing is irreversible and run by the maintainer, never an agent (`docs/agents/theflow.md` Step 7).
- Consumers are derived at release time (`for d in ../*/; do grep -l '^  just_tooltip:' "$d/pubspec.yaml"; done`) and unioned with `docs/downstream-consumers.md` for the private one.

## Code

- `pubspec.yaml` — `version`, `environment`
- `.pubignore`, `CHANGELOG.md`, `README.md` (`## Install`, `## Migration to …`)
- `.github/workflows/ci.yml` — `FLUTTER_VERSION`, the `run:` steps
- `docs/downstream-consumers.md`

## Reference behaviour

- pub.dev API, `https://pub.dev/api/packages/just_tooltip` — what is actually published (`docs/agents/theflow.md` Step 1).

## Cross-cutting invariants

- [sdk-floor-covers-api-use](../invariant/sdk-floor-covers-api-use.md)

## Blast radius

- [public-surface](public-surface.md) — an export or parameter change decides the version segment.
- [demonstration](demonstration.md) — `example/lib` ships in the archive; its separate manifest is gated by hand only.

## Known holes / open

- Nothing builds at the declared floor (3.13).
- `example/` analyse/test and the publish dry run are local-only gates.
- `docs/downstream-consumers.md` says "All four are on `just_tooltip 0.3.0`"; the three sibling repos declare `^0.4.4` (2026-10-23). It also calls itself the source of truth while the release rule derives the list.
