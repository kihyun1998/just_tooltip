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
