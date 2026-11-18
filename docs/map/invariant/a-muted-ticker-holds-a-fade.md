# A muted ticker holds a fade

## The fact

A `reverse()` on the tooltip's `AnimationController` makes no progress while the tooltip's tickers
are muted, so `_onAnimationStatus` would not reach `dismissed` and `onHide` would not be called
until they run again. An opaque route mutes the route below it: in a widget test (Flutter 3.47.1) a
pushed `MaterialPageRoute` took about 500 ms to come in, and from then on `TickerMode` was off for
the tooltip; a 2 s fade stopped there and `onHide` came only after the pop (#100's build). Any
`TickerMode(enabled: false)` a consumer places above the tooltip does the same. Checkable: every
fade-out the code waits for is ended by the code itself once the tickers are stopped — `reverse()`
appears only in `_hide`, which ends the fade at once when `_tickerEnabled` is `false`, and
`_updateCovered` ends one after the frame in which the tickers stop (ADR-0011, as amended by #104).

## Why it is cross-cutting

Every hide goes through `_hide` (`reverse()`), and its callers do not call each other:

- `_syncCovered` — a covered hide.
- `hideTooltip` — `controller.hide()`, which can reach a tooltip under an opaque route when
  `hideWhenCovered` is `false`.
- the scheduler's auto-hide (`startAutoHide`, `onClose: _closeOnRequest`) — a `Timer`, which fires
  while the route is offstage.
- the content-loss hide in `didUpdateWidget`, `dismissTooltip` (the registry) and `_dismissByUser`
  (Escape).
- `toggleTooltip`, `_hideClippedAway` (post-frame), the suppressed or content-less hide in the
  show-intent reconcile (a microtask), and the scheduler's `onHide` — the trigger leaving, the
  Hover Bridge's `Timer`, the pointer leaving the body, and a `showDuration` change in
  `didUpdateWidget` (a build).

All are handled in `_hide` itself, not per caller. Of the first group, each of the last five is pinned in
`test/just_tooltip_covered_test.dart`, group *hideWhenCovered: false, a hide under an opaque page*,
red on b3ef97d and red again with the line in `_hide` removed; the mid-fade case (a hide just before
the push) is pinned there too, red with `_updateCovered` limited to a covered tooltip again.

Ending the fade sets the value to `0.0`, so the show ends exactly as a zero `animationDuration`
ends it inside `reverse()`: synchronously, inside the caller. `_endHeldFade` acts only on `_fadingOut`: a tooltip moved by a `GlobalKey` mid-fade keeps the `reverse` status with `_isShowing` false (`deactivate` stops the controller), and ending that status later ran `_settleClose` on a hover then waiting out `waitDuration`, which left the tooltip shown after the pointer left (pinned in the same file, red with a status-only check). That path was already supported at
every caller — `_callOnHide` defers `onHide` out of a build, and `_show` registers last so a
dismissal's synchronous end acts on a complete show
([a-show-is-set-before-the-registry-runs-another-tooltip](a-show-is-set-before-the-registry-runs-another-tooltip.md)).

`_tickerEnabled` is what `_RouteStatus` last reported from `TickerMode.of` (deprecated; see
[sdk-floor-covers-api-use](sdk-floor-covers-api-use.md)). Inside the build in which the tickers change
it can be one step behind the controller's ticker, since `TickerMode` mutes the ticker before
`_RouteStatus` below it rebuilds, and the tooltip's `didUpdateWidget` can run between the two. When
they stop, a hide in that window only `reverse()`s and the after-frame check in `_updateCovered`
ends it. When they start again, a hide in that window (content lost in the same build) still reads
them as stopped and skips a fade that could have run: one fade lost, `onHide` on time (read, not
run; #104's lens).

## Territories it holds in

- [visibility-lifecycle](../territory/visibility-lifecycle.md) — `_hide`, `_onAnimationStatus`, `_endHeldFade`, `_endHeldFadeAfterFrame`, `_updateCovered`.
- [programmatic-control](../territory/programmatic-control.md) — `hideTooltip`.
- [visibility-scheduling](../territory/visibility-scheduling.md) — the auto-hide timer.

## What a violation looks like

A consumer that waits for `onHide` before acting — removing data, starting another tooltip —
waits until the user comes back to the route. Nothing is drawn wrongly: the tooltip is offstage
with its route.

## Discovery history

- #100 — measured on the covered hide, which was then finished at once; the other hides were left
  as they were.
- #104 — the other five hides measured on b3ef97d; every hide now ends a held fade (maintainer,
  2026-11-17).

## Where it will recur

Any new animation the tooltip drives to an end the code waits for. Fades on show are not ended this
way (out of #104's scope): a show under muted tickers, such as a revival under an opaque page,
stays at its first frame until the tickers run (read, not run).
