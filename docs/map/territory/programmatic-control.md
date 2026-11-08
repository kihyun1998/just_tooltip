# Programmatic control

## What it is

`JustTooltipController`: show, hide, toggle and query a tooltip from outside, with commands queued
before the widget attaches. Vocabulary: [Controller Target](../../../GLOSSARY.md#controller-target).

## Governing decisions

- [ADR-0002](../../adr/0002-controller-is-attach-based-not-changenotifier.md) — attach-based command source, not a `ChangeNotifier`; queue-before-attach, consume-and-clear on attach, `false` when detached.
- [ADR-0011](../../adr/0011-a-covered-tooltip-hides.md) — a show while covered is ignored, a queued one included; a covered tooltip a controller opened is hidden directly, having no show intent (maintainer, 2026-11-08).

## Design model

From ADR-0002, confirmed in source:

- The controller holds only `_target` and `_pendingShow`. `attach` asserts single attachment, returns and clears the pending show; `detach` clears only if `identical`.
- The State holds the controller only while it is in the tree (#102): `_attachController` runs in `initState`, the controller swap in `didUpdateWidget` and `activate`; `deactivate` detaches. A subtree replaced in one frame — a parent key change, a wrapper added above — deactivates the old State before the new one's `initState` (`Element.updateChild` deactivates the old child, then inflates; Flutter 3.47.1 `framework.dart`), so the new State attaches cleanly. Attaching in `initState` and detaching only in `dispose` hit the single-attachment assert there, since disposal waits for the end of the frame (measured in flutter_folderview's View Mode switch). The assert stays: two States in the tree with one controller still fail it. Flutter's `_OverlayPortalState` takes the other route — it relaxes its assert when the attached State is inactive and detaches only in `dispose` — which would leave a deactivated State taking commands until the frame ends; not adopted (derivation, #102).
- The State applies a queued show post-frame (`_applyQueuedShowAfterLayout`, guarded by `mounted`) because the overlay needs the child's `RenderBox`; a reattach in `activate` applies one queued while no State held the controller.
- `showTooltip` calls `_show` then `_scheduler.startAutoHide` — the only timer a programmatic show arms.
- A tooltip fading out is still `_isShowing`: `show()` turns the fade back through `_show` (#101), and `isShowing` reads `true` throughout. `toggle()` takes a fading tooltip as closed and opens it again (maintainer, 2026-11-08, #101's confirm stop); a tap on a fading tooltip still hides it, since the scheduler's `onTap` reads only `isShown`.
- A programmatic show is not suppressed by a descendant's hover (ADR-0003) and has no show intent, so content loss must close it directly (ADR-0004).
- A listenable `isShowing` is deferred, not forbidden (ADR-0002).
- `_show` reads whether the route is current at the call, not from the last notice, so `Navigator.pop(); controller.show();` in one handler shows and a show right after a push does not flash (ADR-0011, mechanism).

## Code

- `lib/src/just_tooltip_controller.dart` — `JustTooltipController`, `show`, `hide`, `toggle`, `isShowing`, `attach`, `detach`, `JustTooltipControllerTarget`
- `lib/src/just_tooltip.dart` — `showTooltip`, `hideTooltip`, `toggleTooltip`, `isTooltipShowing`, `_attachController`, `activate`, `deactivate`, `_applyQueuedShowAfterLayout`, the controller swap in `didUpdateWidget`
- Tests: `test/just_tooltip_controller_test.dart`, `test/just_tooltip_fading_test.dart`, `test/just_tooltip_reattach_test.dart`

## Reference behaviour

- Flutter 3.41.9 — `RawTooltip` has no controller type: `RawTooltipState.ensureTooltipVisible()` via a key, and the static `dismissAllToolTips()`. ADR-0002 compares against `OverlayPortalController` instead.

## Cross-cutting invariants

- [a-muted-ticker-holds-a-fade](../invariant/a-muted-ticker-holds-a-fade.md)

## Blast radius

- [visibility-lifecycle](visibility-lifecycle.md) — commands land on `_show` / `_hide`.
- [content](content.md) — a controller-shown tooltip is the case that forced content loss to hide directly.
- [target-resolution](target-resolution.md) — with no pointer, the anchor is the child's Visible Rect, and a fully clipped child anchors at the clip edge.
- [public-surface](public-surface.md) — the controller is exported; `flutter_password_input` owns and recreates controllers (`docs/downstream-consumers.md`).

## Known holes / open

- `activate` runs before `didUpdateWidget` (`Element.inflateWidget` reactivates a `GlobalKey` element, then updates it), so a State moved and given a new controller in the same frame reattaches its old controller first. If another tooltip took that old controller in the same frame, the reattach fails the assert (probed in #102's review; the same frame failed before #102 too, in the other tooltip's `initState`). A show queued on the old controller in that frame opens the moved tooltip, now under the new controller.
- Two sibling tooltips swapping controllers in one frame fail the assert in the first one's `didUpdateWidget` (read, not run; predates #102).
- Whether the attach-in-tree rule should hold for the other registrations a State keeps: suppressors (`_releaseAncestors`) and `_evicted` are released in `dispose` and re-read in `activate`, the registry and heard set in `deactivate`. Not all agree, so no invariant note (#102).
- `attach` asserts one target, in debug only; in release a second attach silently replaces the first.
