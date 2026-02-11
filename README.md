# just_tooltip

A custom Flutter tooltip widget. Combine direction (top/bottom/left/right) and alignment (start/center/end) to position tooltips exactly where you want.

## Install

```yaml
dependencies:
  just_tooltip: ^0.1.3
```

## Basic Usage

Pass a `message` string. Defaults to hover trigger, top-center position.

```dart
JustTooltip(
  message: 'Hello!',
  child: Text('Hover me'),
)
```

## Direction & Alignment

`direction` controls which side the tooltip appears on. `alignment` controls where it aligns along that side.

```dart
JustTooltip(
  message: 'Top left aligned',
  direction: TooltipDirection.top,
  alignment: TooltipAlignment.start,
  child: MyWidget(),
)
```

12 combinations are available:

| direction | alignment | position |
|-----------|-----------|----------|
| `top` | `start` | above, left-aligned |
| `top` | `center` | above, centered |
| `top` | `end` | above, right-aligned |
| `bottom` | `start` | below, left-aligned |
| `bottom` | `center` | below, centered |
| `bottom` | `end` | below, right-aligned |
| `left` | `start` | left, top-aligned |
| `left` | `center` | left, centered |
| `left` | `end` | left, bottom-aligned |
| `right` | `start` | right, top-aligned |
| `right` | `center` | right, centered |
| `right` | `end` | right, bottom-aligned |

In RTL environments, `start`/`end` are automatically swapped.

## Trigger

Hover and tap triggers can be toggled independently.

```dart
// Tap only
JustTooltip(
  message: 'Tap tooltip',
  enableTap: true,
  enableHover: false,
  child: MyButton(),
)
```

## Controller

Use `JustTooltipController` for programmatic control.

```dart
final controller = JustTooltipController();

// Widget
JustTooltip(
  message: 'Controlled',
  controller: controller,
  enableHover: false,
  child: MyWidget(),
)

// Control
controller.show();
controller.hide();
controller.toggle();
```

## Custom Content

Use `tooltipBuilder` to render any widget instead of plain text.

```dart
JustTooltip(
  tooltipBuilder: (context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.info, color: Colors.white, size: 16),
      SizedBox(width: 8),
      Text('Custom content', style: TextStyle(color: Colors.white)),
    ],
  ),
  child: MyWidget(),
)
```

## Cross-Axis Offset

Use `crossAxisOffset` to shift the tooltip along the cross-axis from the aligned edge. For `start`/`end`, a positive value pushes the tooltip inward (toward center). For `center`, a positive value moves toward the end direction.

```dart
JustTooltip(
  message: 'Shifted inward',
  direction: TooltipDirection.top,
  alignment: TooltipAlignment.start,
  crossAxisOffset: 10, // left-aligned but shifted 10px to the right
  child: MyWidget(),
)
```

| direction | alignment | crossAxisOffset: 10 |
|-----------|-----------|---------------------|
| top/bottom | `start` | shifts right |
| top/bottom | `center` | shifts right |
| top/bottom | `end` | shifts left (inward) |
| left/right | `start` | shifts down |
| left/right | `center` | shifts down |
| left/right | `end` | shifts up (inward) |

## Styling

```dart
JustTooltip(
  message: 'Styled',
  backgroundColor: Colors.indigo,
  borderRadius: BorderRadius.circular(12),
  padding: EdgeInsets.all(16),
  elevation: 8.0,
  offset: 12.0,  // gap between child and tooltip
  crossAxisOffset: 10.0,  // shift along the cross-axis
  textStyle: TextStyle(color: Colors.white, fontSize: 16),
  child: MyWidget(),
)
```

## Callbacks

```dart
JustTooltip(
  message: 'With callbacks',
  onShow: () => print('shown'),
  onHide: () => print('hidden'),
  child: MyWidget(),
)
```

## API Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | Target widget the tooltip is anchored to |
| `message` | `String?` | `null` | Text content (one of `message` or `tooltipBuilder` required) |
| `tooltipBuilder` | `WidgetBuilder?` | `null` | Custom widget builder |
| `direction` | `TooltipDirection` | `top` | Which side the tooltip appears on |
| `alignment` | `TooltipAlignment` | `center` | Alignment along the cross-axis |
| `offset` | `double` | `8.0` | Gap between child and tooltip |
| `crossAxisOffset` | `double` | `0.0` | Shift along the cross-axis (inward for start/end) |
| `backgroundColor` | `Color` | `Color(0xFF616161)` | Background color |
| `borderRadius` | `BorderRadius` | `circular(6)` | Corner radius |
| `padding` | `EdgeInsets` | `h:12, v:8` | Inner padding |
| `elevation` | `double` | `4.0` | Shadow elevation |
| `textStyle` | `TextStyle?` | `null` | Text style for `message` |
| `controller` | `JustTooltipController?` | `null` | Programmatic control |
| `enableTap` | `bool` | `false` | Tap trigger |
| `enableHover` | `bool` | `true` | Hover trigger |
| `animationDuration` | `Duration` | `150ms` | Fade animation duration |
| `onShow` | `VoidCallback?` | `null` | Called when tooltip is shown |
| `onHide` | `VoidCallback?` | `null` | Called when tooltip is hidden |

## Example

An interactive playground app is included in the `example/` folder.

```bash
cd example
flutter run
```
