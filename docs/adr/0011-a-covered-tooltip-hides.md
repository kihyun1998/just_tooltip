# 0011 — A covered tooltip hides

- **Status:** Accepted
- **Date:** 2026-11-08
- **Context issue:** [#100](https://github.com/kihyun1998/just_tooltip/issues/100) (a tooltip opened by a tap stays open while a route opens over it, and after the route is popped)

## Context

A tooltip stays shown until a trigger leaves, the user dismisses it (ADR-0010), `showDuration` runs out, or the widget leaves the tree. A route pushed over it does none of these: the tooltip's widget stays mounted under the new route. Reproduced on Flutter 3.47.1 (#100's triage): a `TooltipTap.observe` tooltip whose tap also opened a dialog stayed shown under the dialog. Under a page it stayed shown but offstage. In both cases it was still shown after the pop, and `onHide` was never called. The tooltip is an `OverlayPortal` child on the nearest `Overlay`, and Flutter paints that between its own route's entry and the next one, so the route above draws over it (read, not run).

Hover and keyboard focus usually end when a route opens, because the barrier takes the pointer and the route takes focus. A tap or `controller.show()` has no trigger that can leave, so those tooltips stayed.

## Decision

Maintainer's calls (2026-11-08, grilling on #100's triage):

- **A tooltip whose route is not current hides.** The term is [Covered](../../GLOSSARY.md#covered). A tooltip watches its own `ModalRoute` and hides when that route is no longer current. Chosen over closing on any pointer-down outside the tooltip, which is what Flutter's `RawTooltip` does (`_handleGlobalPointerEvent`, `enableTapToDismiss`). That alternative misses routes pushed or popped without a pointer, leaves the tooltip under a dialog until the first tap, and changes how hover and `interactive` tooltips close on the same page. Both together was rejected for the same breadth.
- **However it was opened.** Hover, focus, tap and `controller.show()` all hide, so the rule has no exceptions by trigger.
- **A covered tooltip does not show.** A `controller.show()` while covered is ignored, as a show without [Content](../../GLOSSARY.md#content) is, and a show queued before attach is dropped if the tooltip is covered when it would apply.
- **Hiding is a plain hide, not a [Dismissal](../../GLOSSARY.md#dismissal).** It fades out like any other hide and then calls `onHide`. After the pop, the tooltip does not reopen by itself, and the existing triggers decide whether it opens again. A pointer still over the child may bring it back by hover.
- **The tooltip's own route popping is not Covered** (maintainer, 2026-11-08, after #100's build measured it). At the confirm stop the maintainer first counted it as Covered, shown a reading that `ModalRoute.didPop` notifies `isCurrent` dependents. That reading was wrong: `didPop` calls `changedInternalState` only when it removes a local-history entry, and a plain pop goes to `TransitionRoute.didPop`. Measured on Flutter 3.47.1: `isCurrent` was `false` right after `pop()`, yet the tooltip got no notice and stayed shown through the 300 ms exit. Shown that, the maintainer kept today's behaviour, where the tooltip leaves with its route and `onHide` is not called. The alternative was to watch the route's animation turn to reverse, which adds a mechanism and still loses `onHide` when the fade outlasts the exit.
- **Only the nearest route is read** (maintainer, 2026-11-08, confirm stop). `ModalRoute.isCurrentOf` reads the nearest enclosing route, and a dependency on an outer one is not known to be reachable through public API: the scope it would need is the private `_ModalScopeStatus`.
- **A fade an opaque route stops is ended at once** (maintainer, 2026-11-08, after #100's build measured it). Measured in a widget test: an opaque `MaterialPageRoute` took about 500 ms to come in, and then the route below had its tickers disabled. A 2 s fade stopped there, and `onHide` came only after the pop. The 150 ms default ends well before. Chosen over accepting the delay, and over hiding a covered tooltip with no fade at all, which would drop the fade under a dialog too. Only a covered hide is ended this way.
- **An opt-out, on by default: `hideWhenCovered: bool = true`** on `JustTooltip`, the same form as `hideOnEmptyMessage`. `false` turns the whole rule off: the tooltip stays shown under a covering route and accepts shows while covered, as before this record. Turning it on while covered hides the tooltip at once.

The mechanism is the implementer's (no record of the maintainer's), each part chosen after the build's review measured the first cut:

- **The route is read as it is now.** A small widget inside the tooltip depends on `ModalRoute.of` and reports the route; whether the tooltip is covered is then read from `route.isCurrent` at the moment it is asked. A first cut kept the notified value, and the review found that `Navigator.pop(); controller.show();` in one handler dropped the show, since the notice arrives at the next build, and that a show right after a push flashed (`onShow`, then `onHide`).
- **The dependency sits on a child, not on the tooltip's State.** Depending on the route from the State rebuilt every tooltip on each route change: with 300 tooltips, a dialog push and pop took about 59 ms against 23 ms without the change (debug widget test, median of 30). On the child it took about 28 ms.
- **A covered hide starts after the frame.** The route's notice arrives during a build, and a fade with nothing left to animate ends at once, so `onHide` ran inside the build. The lens read measured it on #100's own path.

## Consequences

- **Accepted:** a menu drawn as a route (`showMenu`, `PopupMenuButton`, `DropdownButton`) or a bottom sheet is a `ModalRoute`, so opening one hides every tooltip on the route below, including one whose own content opened it.
- **Accepted:** a tap whose gesture both toggles a `TooltipTap.observe` tooltip and pushes a route never opens the tooltip: the toggle runs after the push, when the route is already covered. #100's brief expected the tooltip to open and close in that case; it does neither.
- **Not covered:** a menu drawn in the overlay — `MenuAnchor` and `DropdownMenu` (`raw_menu_anchor.dart`), `Autocomplete` — is an `OverlayPortal`, not a route, so it covers nothing (read in Flutter 3.47.1 and probed). A tooltip shown in the same tap that opens one paints over it, since overlay children of one entry paint in the order they were shown (read, not run).
- **Accepted:** the tooltip's own route leaving is not one rule. A plain pop sends no notice, so the tooltip leaves with the route, usually without `onHide`. A replacement (`pushReplacement`) does notify, so the tooltip hides and `onHide` is called (probed). A navigator rebuilt during the exit may notify a popping route too (`NavigatorState.didUpdateWidget` calls `changedExternalState`; read, not run), which is why the documentation says `onHide` *may* not be called.
- **Accepted:** the default changes behaviour for every consumer. A tap- or controller-shown tooltip that used to survive a dialog now closes; such a consumer sets `hideWhenCovered: false`.
- **Not covered:** a tooltip with no `ModalRoute` above it (no `Navigator`, or built straight into an `Overlay`) is never covered and behaves as before.
- **Not covered:** a tooltip on a page of a nested `Navigator`, under a route pushed on an outer one: `showDialog` uses the root navigator by default, so such a dialog leaves the tooltip shown.
- **Accepted:** reading whether this route's tickers run takes `TickerMode.of`, deprecated in favour of `TickerMode.valuesOf` (marked "after v3.35.0-0.0.pre"; first in a stable release with 3.41.0, by `git tag --contains`), which the 3.32 floor does not have. The call carries an `ignore` until the floor reaches 3.41.
- **Not covered:** closing a tooltip on a pointer-down outside it, on the same route. That is a separate change if it is wanted.
