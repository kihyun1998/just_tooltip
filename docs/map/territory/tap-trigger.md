# Tap trigger

## What it is

`enableTap: true` makes a tap on the child toggle the tooltip, and is the only way a touch
(which fires no `MouseRegion` callbacks) gives the tooltip a pointer position.

## Governing decisions

**None.** ADR-0003 governs hover only and says so; nothing decides tap.

## Design model

From reading only:

- `build` wraps the child in `GestureDetector(behavior: HitTestBehavior.opaque, onTapDown, onTap)`. `onTapDown` writes `_anchorCandidate`; `onTap` calls `_scheduler.onTap`, which toggles immediately.
- The `TapGestureRecognizer` enters the gesture arena and, being innermost, beats an ancestor's tap recognizer — the tooltip takes the tap from a tappable surface around it (#66, measured in flutter_folderview#134 on 2026-10-20 per the issue).
- Tap bypasses [hover intent](hover-intent.md): no suppression, no content check until `_show`.

## Code

- `lib/src/just_tooltip.dart` — `_JustTooltipState.build` (the `if (widget.enableTap)` block)
- `lib/src/tooltip_visibility_scheduler.dart` — `onTap`
- Tests: `test/just_tooltip_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltipState._handlePointerDown` hands each pointer-down from a `Listener` to its own `TapGestureRecognizer` / `LongPressGestureRecognizer`, which still enter the gesture arena. It is not an example of the non-claiming mode #66 asks for; whether it beats an ancestor's tap has not been measured.

## Cross-cutting invariants

**None.**

## Blast radius

- [target-resolution](target-resolution.md) — a tap-shown pointer anchor freezes the `onTapDown` position; any non-claiming observer must still write `_anchorCandidate` before the toggle.
- [visibility-scheduling](visibility-scheduling.md) — `onTap` cancels hover timers; tap and hover share the scheduler.
- [public-surface](public-surface.md) — `enableTap` is passed through by `flutter_table_plus` and `flutter_folderview` themes.

## Known holes / open

- A tap mode that does not claim the gesture, with its own tap-vs-drag slop decision. Tracked: #66.
- Whether a tap on a nested tooltip should suppress ancestors: nothing decides it.
