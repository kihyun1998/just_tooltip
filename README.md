# just_tooltip

A lightweight, customizable Flutter tooltip widget. Combine direction (top/bottom/left/right) and alignment (start/center/end) for 12 positioning combinations with arrow indicators, viewport-aware auto-flipping, and programmatic control.

## Features

- **12 positioning combinations** &mdash; 4 directions &times; 3 alignments
- **Reusable theme** &mdash; `JustTooltipTheme` groups all visual styling
- **Arrow indicator** &mdash; unified shape with border support
- **Viewport overflow protection** &mdash; auto-flip direction and clamp position
- **Hover & tap triggers** &mdash; independently toggleable
- **Interactive tooltips** &mdash; stays visible while hovering tooltip content
- **Programmatic control** &mdash; show/hide/toggle via controller
- **Custom content** &mdash; any widget via `tooltipBuilder`
- **RTL support** &mdash; start/end automatically swapped for top/bottom directions
- **Single instance** &mdash; only one tooltip visible at a time

## Install

```yaml
dependencies:
  just_tooltip: ^0.2.3
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

In RTL environments, `start`/`end` are automatically swapped for top/bottom directions.

## Viewport Overflow Protection

When there isn't enough space in the preferred direction, the tooltip automatically flips to the opposite side. The tooltip position is also clamped to stay within screen bounds.

Use `screenMargin` to control the minimum distance from viewport edges. This also affects the maximum size of the tooltip.

```dart
JustTooltip(
  message: 'Safe tooltip',
  direction: TooltipDirection.top,
  screenMargin: 16.0,  // 16px minimum distance from screen edges (default: 8.0)
  child: MyWidget(),
)
```

## Theme

Use `JustTooltipTheme` to group all visual styling parameters. The theme is reusable across multiple tooltips.

```dart
// Define a reusable theme
const myTheme = JustTooltipTheme(
  backgroundColor: Colors.black87,
  textStyle: TextStyle(color: Colors.white),
  showArrow: true,
  borderColor: Colors.white,
  borderWidth: 1.0,
);

// Reuse across widgets
JustTooltip(message: 'A', theme: myTheme, child: WidgetA())
JustTooltip(message: 'B', theme: myTheme, child: WidgetB())
```

Use `copyWith()` to derive variations:

```dart
final warningTheme = myTheme.copyWith(
  backgroundColor: Colors.orange,
  borderColor: Colors.deepOrange,
);
```

## Arrow

Enable `showArrow` in the theme to display a triangular arrow pointing at the target widget. The arrow is rendered as a unified shape with the tooltip body, so background, shadow, and border all follow the combined outline.

```dart
JustTooltip(
  message: 'With arrow',
  theme: JustTooltipTheme(
    showArrow: true,
    arrowBaseWidth: 12.0,     // arrow base width (default: 12.0)
    arrowLength: 6.0,         // arrow protrusion length (default: 6.0)
  ),
  child: MyWidget(),
)
```

For `start`/`end` alignments, `arrowPositionRatio` controls where the arrow sits along the tooltip edge (0.0 = near the aligned edge, 1.0 = far end).

```dart
JustTooltip(
  message: 'Arrow near edge',
  alignment: TooltipAlignment.start,
  theme: JustTooltipTheme(
    showArrow: true,
    arrowPositionRatio: 0.25,  // 25% from the start edge (default: 0.25)
  ),
  child: MyWidget(),
)
```

The arrow auto-flips along with the tooltip when direction changes due to viewport constraints.

## Border

Add an outline that follows the tooltip shape, including the arrow.

```dart
JustTooltip(
  message: 'Bordered',
  theme: JustTooltipTheme(
    showArrow: true,
    borderColor: Colors.white,
    borderWidth: 1.5,
  ),
  child: MyWidget(),
)
```

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

The controller state automatically syncs when the tooltip is dismissed by hover-out, tap-outside, or auto-hide, so `show()` works correctly after any dismissal.

## Custom Content

Use `tooltipBuilder` to render any widget instead of plain text. The caller is responsible for managing the size of the content.

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

## Interactive & Timing

`interactive` keeps the tooltip visible when the cursor moves from the child to the tooltip itself. Useful for selectable text or clickable content inside the tooltip. When combined with `showDuration`, the auto-hide timer pauses while the cursor is on the tooltip.

`waitDuration` adds a delay before the tooltip appears. `showDuration` auto-hides the tooltip after a set time.

```dart
JustTooltip(
  message: 'Interactive tooltip',
  interactive: true,           // stay visible when hovering tooltip (default: true)
  waitDuration: Duration(milliseconds: 300),  // delay before showing
  showDuration: Duration(seconds: 3),         // auto-hide after 3s
  child: MyWidget(),
)
```

## Animation

Control the show/hide animation type, curve, and fine-tune parameters.

```dart
JustTooltip(
  message: 'Animated',
  animation: TooltipAnimation.fadeScale,
  animationCurve: Curves.elasticOut,
  animationDuration: Duration(milliseconds: 300),
  child: MyWidget(),
)
```

Available animation types:

| Type | Description |
|------|-------------|
| `none` | No animation, appears instantly |
| `fade` | Opacity fade (default) |
| `scale` | Scale from center |
| `slide` | Slide in from the opposite side of `direction` |
| `fadeScale` | Fade + scale combined |
| `fadeSlide` | Fade + slide combined |
| `rotation` | Fade + rotation combined |

Fine-tune each animation with optional parameters:

```dart
JustTooltip(
  message: 'Fine-tuned',
  animation: TooltipAnimation.fadeScale,
  animationCurve: Curves.bounceOut,
  fadeBegin: 0.0,       // starting opacity (default: 0.0)
  scaleBegin: 0.8,      // starting scale (default: 0.0) — 0.8 gives a subtle grow
  slideOffset: 0.3,     // slide distance ratio (default: 0.3)
  rotationBegin: -0.05, // starting rotation in turns (default: -0.05)
  child: MyWidget(),
)
```

## Box Shadow

Use `boxShadow` in the theme for fine-grained shadow control. When provided, `elevation` is ignored.

```dart
JustTooltip(
  message: 'Custom shadow',
  theme: JustTooltipTheme(
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 8.0,
        spreadRadius: 1.0,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: MyWidget(),
)
```

## Styling

All visual styling is configured through `JustTooltipTheme`:

```dart
JustTooltip(
  message: 'Styled',
  offset: 12.0,  // gap between child and tooltip
  theme: JustTooltipTheme(
    backgroundColor: Colors.indigo,
    borderRadius: BorderRadius.circular(12),
    padding: EdgeInsets.all(16),
    elevation: 8.0,
    textStyle: TextStyle(color: Colors.white, fontSize: 16),
    borderColor: Colors.white,
    borderWidth: 1.0,
    showArrow: true,
  ),
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

### JustTooltip

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | Target widget the tooltip is anchored to |
| `message` | `String?` | `null` | Text content (one of `message` or `tooltipBuilder` required) |
| `tooltipBuilder` | `WidgetBuilder?` | `null` | Custom widget builder |
| `direction` | `TooltipDirection` | `top` | Which side the tooltip appears on |
| `alignment` | `TooltipAlignment` | `center` | Alignment along the cross-axis |
| `offset` | `double` | `8.0` | Gap between child and tooltip |
| `crossAxisOffset` | `double` | `0.0` | Shift along the cross-axis (inward for start/end) |
| `screenMargin` | `double` | `8.0` | Minimum distance from viewport edges |
| `theme` | `JustTooltipTheme` | `JustTooltipTheme()` | Visual styling (see below) |
| `controller` | `JustTooltipController?` | `null` | Programmatic control |
| `enableTap` | `bool` | `false` | Tap trigger |
| `enableHover` | `bool` | `true` | Hover trigger |
| `interactive` | `bool` | `true` | Keep tooltip visible when hovering over it |
| `waitDuration` | `Duration?` | `null` | Delay before tooltip appears |
| `showDuration` | `Duration?` | `null` | Auto-hide after this duration |
| `animation` | `TooltipAnimation` | `fade` | Animation type (none, fade, scale, slide, fadeScale, fadeSlide, rotation) |
| `animationCurve` | `Curve?` | `null` | Curve applied to the animation |
| `fadeBegin` | `double` | `0.0` | Starting opacity for fade-based animations |
| `scaleBegin` | `double` | `0.0` | Starting scale for scale-based animations |
| `slideOffset` | `double` | `0.3` | Slide distance as a fraction of tooltip size |
| `rotationBegin` | `double` | `-0.05` | Starting rotation in turns |
| `animationDuration` | `Duration` | `150ms` | Animation duration |
| `onShow` | `VoidCallback?` | `null` | Called when tooltip is shown |
| `onHide` | `VoidCallback?` | `null` | Called when tooltip is hidden |

### JustTooltipTheme

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `backgroundColor` | `Color` | `Color(0xFF616161)` | Background color |
| `borderRadius` | `BorderRadius` | `circular(6)` | Corner radius |
| `padding` | `EdgeInsets` | `h:12, v:8` | Inner padding |
| `elevation` | `double` | `4.0` | Shadow elevation (ignored if `boxShadow` is set) |
| `boxShadow` | `List<BoxShadow>?` | `null` | Custom box shadows |
| `borderColor` | `Color?` | `null` | Border color |
| `borderWidth` | `double` | `0.0` | Border stroke width |
| `textStyle` | `TextStyle?` | `null` | Text style for `message` |
| `showArrow` | `bool` | `false` | Display triangular arrow pointing at target |
| `arrowBaseWidth` | `double` | `12.0` | Arrow base width |
| `arrowLength` | `double` | `6.0` | Arrow protrusion length |
| `arrowPositionRatio` | `double` | `0.25` | Arrow position along the edge for start/end (0.0-1.0) |

## Migration from 0.1.x

Individual styling parameters have been moved into `JustTooltipTheme`:

```dart
// Before (0.1.x)
JustTooltip(
  message: 'Hello',
  backgroundColor: Colors.blue,
  showArrow: true,
  borderColor: Colors.white,
  borderWidth: 1.0,
  child: MyWidget(),
)

// After (0.2.0)
JustTooltip(
  message: 'Hello',
  theme: JustTooltipTheme(
    backgroundColor: Colors.blue,
    showArrow: true,
    borderColor: Colors.white,
    borderWidth: 1.0,
  ),
  child: MyWidget(),
)
```

## Example

An interactive playground app is included in the `example/` folder.

```bash
cd example
flutter run
```
