# Tap trigger

## What it is

`tap:` makes a tap on the child toggle the tooltip — `TooltipTap.claim` by winning the gesture
arena, `TooltipTap.observe` by watching pointers outside it — and is the only way a touch (which
fires no `MouseRegion` callbacks) gives the tooltip a pointer position. `enableTap` is the
deprecated spelling of `claim`.

## Governing decisions

- The shape is one enum, `tap: TooltipTap { none, claim, observe }`, with `enableTap` deprecated and both together an assertion error — chosen over a `tapClaimsGesture` flag beside `enableTap`, which would be a silent no-op without it (maintainer, 2026-10-23, on #66's triage).
- [ADR-0006](../../adr/0006-a-tap-goes-to-the-innermost-tooltip.md) — nested, the innermost tooltip with content takes the tap; taps are coalesced per pointer event (maintainer, 2026-10-24).

ADR-0003 governs hover only and says so.

## Design model

From reading only:

- `claim`: `build` wraps the child in `GestureDetector(behavior: HitTestBehavior.opaque, onTapDown, onTap)`. `onTapDown` writes `_anchorCandidate`; `onTap` calls `_scheduler.onTap`, which toggles immediately.
- The `TapGestureRecognizer` enters the gesture arena and, being innermost, beats an ancestor's tap recognizer — `claim` takes the tap from a tappable surface around it (measured in flutter_folderview#134 on 2026-10-20, reproduced in #66's triage on 2026-10-23).
- `observe`: `RawGestureDetector(behavior: HitTestBehavior.translucent)` with `_ObservedTapRecognizer`, a `PrimaryPointerGestureRecognizer` that joins the arena and never wins it: at pointer-up, if still a member, it resolves itself rejected and reports the tap, so the remaining members decide as if it had never joined. A gesture that wins before the release rejects it first, and no tap is reported. Chosen over an arena-free `Listener` (maintainer, 2026-10-23), shown measurements of both: the `Listener` toggled under an ancestor's held long press and under a 10 px mouse drag an ancestor pans with (a mouse's pan slop is 2 px, `computePanSlop`); the arena member does neither.
- Its slop and button rules are Flutter 3.41.9's: `PrimaryPointerGestureRecognizer.preAcceptSlopTolerance` defaults to `gestureSettings.touchSlop ?? kTouchSlop` for **every** pointer kind (not `computeHitSlop`), measured from the down position, so `gestureSettings` is set on it from `MediaQuery` the way `GestureDetector` does; the base `isPointerAllowed` admits more than the primary button, so it filters to `kPrimaryButton` itself, and a button change mid-press rejects (`gestures/tap.dart`). Cancel rejects as `BaseTapGestureRecognizer` does — no test can see it, since a cancelled pointer sends no up.
- It takes only the first pointer (`addAllowedPointer` returns unless `state == ready`). A primary-pointer recognizer tracks one pointer but would still join every later pointer's arena, where nothing resolves it, so it won that arena's sweep and rejected the ancestor's member for a second finger — found by a review probe, pinned by "a second finger is never claimed from an ancestor". `claim`'s `TapGestureRecognizer` (via `BaseTapGestureRecognizer`) still joins them that way.
- `observe` writes the down position to `_anchorCandidate` at pointer-up, just before the toggle, so a press that another gesture won leaves no anchor behind.
- Each `TooltipTap` value is a different widget above `child`, so changing `tap` (or `enableTap`) at runtime recreates the child subtree's state.
- Tap bypasses [hover intent](hover-intent.md): no hover suppression, no content check until `_show`.
- `_toggleFromTap` adds the tooltip to the static `_tapBatch` and schedules one `_resolveTapBatch` microtask; there a tooltip that is an ancestor (whole `_ancestor` chain) of a batch member with content does not toggle. The batch exists because the reports arrive in an order nobody chose: an `observe` member reports during the up event's routing, a `claim` member after the arena sweep, so before ADR-0006 the outer one opened last and dismissed the inner one through the registry (measured: inner `observe` → outer shown, both modes, touch and mouse).

## Code

- `lib/src/just_tooltip.dart` — `_JustTooltipState.build` (the `switch (_tap)` block), `_tap`, `_toggleFromTap`, `_tapBatch`, `_resolveTapBatch`, `_ObservedTapRecognizer`
- `lib/src/enums.dart` — `TooltipTap`
- `lib/src/tooltip_visibility_scheduler.dart` — `onTap`
- Tests: `test/just_tooltip_tap_test.dart`, `test/just_tooltip_test.dart`, `test/just_tooltip_anchor_test.dart`

## Reference behaviour

- Flutter 3.41.9 `widgets/raw_tooltip.dart` — `RawTooltipState._handlePointerDown` hands each pointer-down from a `Listener` to its own `TapGestureRecognizer` / `LongPressGestureRecognizer`, which still enter the gesture arena. It is not an example of `observe`; whether it beats an ancestor's tap has not been measured. `observe`'s slop and button rules are taken from `gestures/recognizer.dart` and `gestures/tap.dart` instead.

## Cross-cutting invariants

**None.**

## Blast radius

- [nesting-suppression](nesting-suppression.md) — the tap batch reads the same `_ancestor` chain and the same content gate; a change to either reaches both.
- [target-resolution](target-resolution.md) — a tap-shown pointer anchor freezes the tap's down position; both modes must write `_anchorCandidate` before the toggle.
- [visibility-scheduling](visibility-scheduling.md) — `onTap` cancels hover timers; tap and hover share the scheduler.
- [public-surface](public-surface.md) — `enableTap` is passed through by `flutter_table_plus` and `flutter_folderview` themes; its deprecation reaches them as an analyzer info.

## Known holes / open

- `observe` under a gesture decided after the release: an ancestor's double tap fires and the tooltip opens on the first tap and closes on the second (pinned in `test/just_tooltip_tap_test.dart`); a tap handler inside the child fires along with the tooltip.
- `observe` exposes no `SemanticsAction.tap`, so a screen reader cannot open it; `claim` gets one from its `GestureDetector`. See the hub's scope on accessibility. Tracked: #69.
