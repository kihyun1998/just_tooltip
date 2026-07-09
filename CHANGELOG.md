## Unreleased

### Fixed

* Nested `JustTooltip`s now reliably show only the innermost tooltip under the pointer ([#22](https://github.com/kihyun1998/just_tooltip/issues/22)). Previously this held only by coincidence — the "one tooltip at a time" registry dismissed the ancestor *after* it had shown — and broke in three ways:
  * an ancestor's `waitDuration` timer would fire while the pointer rested on a nested child, replacing the inner tooltip with the outer one;
  * moving from a nested child back onto its ancestor showed nothing at all, because the ancestor's hover region was never exited and so never re-entered;
  * tooltips scoped to separate `TooltipRegistry` instances showed both at once.

### Changed

* **Behaviour change for nested tooltips.** A `JustTooltip` containing the pointer now suppresses *every* enclosing `JustTooltip`, regardless of registry. If you relied on a nested tooltip and its ancestor being visible together (only reachable by giving them separate `TooltipRegistry` instances), that no longer happens. Suppression gates hover only — a programmatic `controller.show()` is unaffected.

### Internal

* Pointer facts (`_pointerInside`) are now retained and a *hover intent* boolean derived from them, coalesced into a microtask and handed to `TooltipVisibilityScheduler` on transition only. This makes hover behaviour independent of Flutter's `MouseTracker` dispatch order. See ADR-0003.
* `TooltipVisibilityScheduler` and `TooltipRegistry` are unchanged.

## 0.3.0

### Breaking

* `JustTooltipController` is no longer a `ChangeNotifier`. It is now an attach-based command source (modeled on Flutter's `OverlayPortalController`): `show()`/`hide()`/`toggle()` drive the attached tooltip, which is the single source of truth for visibility.
  * removed the `shouldShow` getter — use `isShowing` (reflects the tooltip's live state) instead
  * removed `addListener`/`removeListener`/`dispose` (`ChangeNotifier` API) — observe visibility via the widget's `onShow`/`onHide` callbacks
  * removed the internal `resetShouldShow()`
* Narrowed the public API — `JustTooltipPositionDelegate`, `TooltipShapePainter`, and `JustTooltipOverlay` are no longer exported (they are internal implementation details). The public surface is now `JustTooltip`, `JustTooltipController`, `JustTooltipTheme`, `TooltipRegistry`, and the enums.

### Added

* An optional `registry` parameter and `TooltipRegistry` class to scope the "one tooltip visible at a time" policy — pass a shared `TooltipRegistry()` to a group of tooltips to isolate them (or a test); omitting it keeps the app-global default.

### Fixed

* `controller.show()` called before the `JustTooltip` mounts is now honoured (the queued show is applied once mounted); previously it was ignored.
* `slide` and `fadeSlide` animations now enter from the auto-flipped (resolved) direction — a tooltip that flips (e.g. `top` → `bottom` near a screen edge) slides in from the side it actually appears on, not the originally-requested one.

### Internal

* Extracted the hover/auto-hide timing into a dedicated `TooltipVisibilityScheduler` (timer cancellation collapsed into one place).
* Extracted the 7 show/hide animations into a dedicated `TooltipTransitions` module.
* Moved the single-visible-tooltip policy out of a static `Set` into the injectable `TooltipRegistry`.
* Test coverage raised to ~97% (scheduler, transitions, registry, controller, painter, and hover integration).

## 0.2.5

* **feat** add `TooltipAlignment.startTargetCenter` and `endTargetCenter` alignments where the arrow dynamically points to the center of the target widget
* **example** add `Top-StartTarget` and `Top-EndTarget` quick presets to playground

## 0.2.4

* **feat** add `hideOnEmptyMessage` parameter to suppress tooltip when `message` is empty (default: `true`)
* **example** add `hideOnEmptyMessage` toggle to Content section in playground

## 0.2.3

* **fix** `borderColor` not visible on non-arrow tooltips (`showArrow: false`) due to `Material` background covering `DecoratedBox` border

## 0.2.2

* **fix** rename `TooltipPositionDelegate` → `JustTooltipPositionDelegate` to resolve name conflict with Flutter SDK's `TooltipPositionDelegate` (introduced in Flutter 3.32)

## 0.2.1

* **feat** add `TooltipAnimation` enum with 7 animation types: `none`, `fade`, `scale`, `slide`, `fadeScale`, `fadeSlide`, `rotation`
* **feat** add `animation` and `animationCurve` parameters for animation type and curve selection
* **feat** add `fadeBegin`, `scaleBegin`, `slideOffset`, `rotationBegin` parameters for fine-tuning animations
* **docs** add Animation section to README with usage examples and API reference
* **example** add Animation section with type/curve dropdowns and parameter sliders

## 0.2.0

* **BREAKING** extract 12 visual styling parameters into `JustTooltipTheme` class
  * `backgroundColor`, `borderRadius`, `padding`, `elevation`, `boxShadow`, `borderColor`, `borderWidth`, `textStyle`, `showArrow`, `arrowBaseWidth`, `arrowLength`, `arrowPositionRatio` are now accessed via `theme` parameter
  * Migration: wrap style params in `theme: JustTooltipTheme(...)`
* **feat** add `JustTooltipTheme.copyWith()` for easy theme derivation
* **feat** `JustTooltipTheme` is a reusable data class with `==` / `hashCode` support

## 0.1.7

* **fix** controller `show()` not working after tooltip was dismissed by hover-out or auto-hide

## 0.1.6

* **feat** add `showArrow` parameter with unified path rendering (arrow integrated into tooltip shape)
* **feat** add `arrowBaseWidth` and `arrowLength` parameters for arrow size customization
* **feat** add `arrowPositionRatio` parameter to control arrow placement along the tooltip edge
* **feat** add `borderColor` and `borderWidth` parameters for tooltip outline (follows arrow shape)
* **feat** arrow auto-flips with tooltip direction when viewport space is insufficient
* **fix** tooltip not reappearing when re-hovering during fade-out animation

## 0.1.5

* **feat** add viewport overflow protection with auto direction flip and position clamping
* **feat** add `screenMargin` parameter to control minimum distance from screen edges
* **docs** `tooltipBuilder` now documents that content sizing is the caller's responsibility

## 0.1.4

* **fix** `interactive` mode now properly pauses auto-hide timer while cursor is on tooltip

## 0.1.3

* **feat** add `boxShadow` parameter for custom shadow control (color, blur, spread, offset)

## 0.1.2

* **feat** add `interactive` option to control whether tooltip stays visible on hover
* **feat** add `waitDuration` for delayed tooltip appearance on hover
* **feat** add `showDuration` for auto-hiding tooltip after a set time with timer reset on re-enter

## 0.1.1

* **feat** add `crossAxisOffset` parameter for shifting tooltip along the cross-axis

## 0.1.0

* **implement** JustTooltip core widget with direction (top/bottom/left/right) + alignment (start/center/end)
* **implement** JustTooltipController for programmatic show/hide/toggle
* **implement** tooltip position utils with 12-combination anchor mapping and RTL support
* **feat** hover and tap trigger modes
* **feat** fade animation with configurable duration
* **feat** custom tooltip content via `tooltipBuilder`
* **feat** single-instance enforcement (only one tooltip visible at a time)
* **feat** interactive playground example app with theme switching
