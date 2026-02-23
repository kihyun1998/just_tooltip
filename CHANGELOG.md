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
