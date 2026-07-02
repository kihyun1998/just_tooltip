# Downstream consumers

Repos (owner `kihyun1998`) that depend on `just_tooltip`. **Update these when
`just_tooltip` ships a new version — especially a breaking one.**

This file is the source of truth, not a search: `gh search code` misses
unindexed/private repos (see the acra_client note below), so keep this list
current by hand.

| Repo | Public | How it uses just_tooltip | Upgrade risk |
| --- | --- | --- | --- |
| [flutter_table_plus](https://github.com/kihyun1998/flutter_table_plus) | ✅ | Wraps `JustTooltip` in `FlutterTooltipPlus`; re-exports the enums. Passthrough only. | Low — usually a version bump |
| [flutter_folderview](https://github.com/kihyun1998/flutter_folderview) | ✅ | Re-exports `JustTooltipController` / `JustTooltipTheme` / enums; controller is a passthrough field. | Low — but its **re-export** transitively exposes any export change |
| [flutter_password_input](https://github.com/kihyun1998/flutter_password_input) | ✅ | **Owns** caps-lock/paste `JustTooltipController`s in `WarningTooltipLayout` (creates, drives, recreates them). | High — the one that needed real code changes for 0.3.0 |
| acra_client | (private / other) | `ACRAJustTooltip` wrapper; passthrough only. | Low. **Not found by `gh search code --owner kihyun1998`** — maintained directly. |

All four are on `just_tooltip 0.3.0`.

## Release checklist

When releasing a new `just_tooltip` version:

1. `dart pub publish --dry-run` — 0 warnings, sane archive size, `CHANGELOG` current.
2. If **breaking**, scan each consumer for the changed API before bumping:
   - controller API (`isShowing`, `show`/`hide`/`toggle`), removed members, narrowed exports.
   - watch **re-exports** (folderview) — a narrowed export is a transitive breaking change.
   - watch consumers that **own/dispose** controllers (password_input) — lifecycle changes hit them hardest.
3. Bump `just_tooltip:` in each consumer's `pubspec.yaml` (caret on `0.x` pins the minor, so `^0.2.x` will **not** accept `0.3.0` — bump the constraint), `flutter pub get`, `flutter analyze`, `flutter test`.
4. Re-run `gh search code "just_tooltip" --owner kihyun1998 --filename pubspec.yaml` to catch any newly-added consumer, and add it here.

## Finding consumers

```sh
gh search code "just_tooltip" --owner kihyun1998 --filename pubspec.yaml \
  --json repository,path
```

Caveats: indexes default branches only, lags recent pushes, and can miss
private/unindexed repos. Treat the table above as authoritative.
