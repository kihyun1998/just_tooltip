# 0005 — The tooltip draws through an OverlayPortal

- **Status:** Accepted
- **Date:** 2026-10-23
- **Context issue:** [#72](https://github.com/kihyun1998/just_tooltip/issues/72) (the tooltip ignores the Directionality, Theme and MediaQuery around it)

## Context

The tooltip was an `OverlayEntry` inserted imperatively into `Overlay.of(context)`. Its builder ran in the **Overlay's** context, so everything the tooltip inherited — the `Directionality` that mirrors `start`/`end`, the `Theme` the content reads, the `MediaQuery` text scale — came from above the Overlay, not from where the `JustTooltip` sits. Measured on Flutter 3.41.9, with each set directly around the tooltip: `Directionality(rtl)` → the content saw `ltr`; a red `Theme` → the app theme; text scale ×2 → ×1. An RTL section inside an LTR app got an unmirrored tooltip (a `top`/`start` body at 350–574 for a target at 350–450).

Flutter's `RawTooltip` (3.41) builds its overlay through `OverlayPortal`, whose overlay child "can depend on the same set of `InheritedWidget`s (such as `Theme`) that this widget can depend on" (`widgets/overlay.dart`).

## Decision

The tooltip is the overlay child of an `OverlayPortal` in `_JustTooltipState.build`, shown and hidden through an `OverlayPortalController`. Everything it inherits comes from the `JustTooltip`'s location. Maintainer's call (2026-10-23), chosen over two narrower options it was shown: reading only the direction from the tooltip's location, and wrapping the content in captured inherited widgets (`InheritedTheme.capture` + `Directionality` + `MediaQuery`, as `showDialog` does).

- **Plain `OverlayPortal`, not `overlayChildLayoutBuilder`.** The plain constructor is in Flutter 3.10 and fits the 3.13 floor; the layout builder `RawTooltip` uses is 3.32. The overlay child is still a `CustomSingleChildLayout` with `JustTooltipPositionDelegate`, laid out tight to the Overlay (as an entry was), and Target Tracking still re-aims per frame. Maintainer's call (2026-10-23): the floor stays; positioning during layout is a separate question.
- **The content is cut off from nesting.** The overlay child now sits in this tooltip's element subtree. It is wrapped in a `_TooltipScope` with no state, so a tooltip inside the content has no ancestor tooltips, as before. Seeing the host as an ancestor would let a content tooltip suppress the tooltip it lives in, which then hides and takes the content tooltip with it. Maintainer's call (2026-10-23).
- **`RawTooltip` is a reference, not a base.** It is 3.41+, aims at the child's centre with no clip walk, and owns its own hover timing, nesting and registry.

The visibility contracts are unchanged: intent vs render state and the reverse-catch (ADR-0001), the controller's queue (ADR-0002), nesting suppression (ADR-0003), the content gates (ADR-0004), the registry, `onShow` / `onHide`.

## Consequences

- **Positive:** the content and the placement follow the local `Directionality`, `Theme`, `DefaultTextStyle` and `MediaQuery`.
- **Positive:** a configuration change reaches a shown tooltip by the State's own rebuild. `_markOverlayDirty` and its post-frame hop are gone.
- **ADR-0002's post-frame apply stays; its reason changes.** A queued `controller.show()` is still applied after the first frame: `OverlayPortalController.show()` must not be called during build, and the target still needs a laid-out `RenderBox`. It was "the overlay is inserted imperatively"; it is now those two.
- **Hiding can wait a frame.** `OverlayPortalController.hide()` asserts during build and layout (`SchedulerPhase.persistentCallbacks`), which is where `deactivate` runs and where `didUpdateWidget` can reverse an animation already at `0.0`. Such a hide is deferred to a post-frame callback and skipped if the tooltip has been shown again by then.
- **Values out of layout still defer.** `onDirectionResolved` and `onArrowCenterResolved` report during layout and rebuild through a post-frame `setState`, as they rebuilt the entry before.
- **Behaviour change for consumers:** a tooltip under a local `Theme`, `Directionality`, `DefaultTextStyle` or `MediaQuery` now draws with it.
- **Accepted (ADR-0004):** a tooltip losing content still spends its fade rendering empty, now because the State's rebuild redraws the content at once.
