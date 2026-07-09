# just_tooltip

A lightweight, customizable Flutter tooltip widget. Combine direction (top/bottom/left/right) and alignment (start/center/end/startTargetCenter/endTargetCenter) for 20 positioning combinations with arrow indicators, viewport-aware auto-flipping, and programmatic control.

## Features

- **20 positioning combinations** &mdash; 4 directions &times; 5 alignments
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
  just_tooltip: ^0.3.0
```

## Basic Usage

Pass a `message` string. Defaults to hover trigger, top-center position.

```dart
JustTooltip(
  message: 'Hello!',
  child: Text('Hover me'),
)
```

## Anchoring to the pointer

By default the child's rect is both the hover region and the anchor, which is right for a button or an icon. For a child much wider than the pointer's neighbourhood — a table row, a wide card — the two roles come apart: the child's centre is nowhere near where the user is looking.

`anchor: TooltipAnchor.pointer` keeps the whole child as the hover region, so the tooltip does not blink off as the cursor crosses it, and anchors the tooltip at the cursor:

```dart
JustTooltip(
  anchor: TooltipAnchor.pointer,
  tooltipBuilder: (context) => RowDetailsCard(row),
  child: TableRow(row),   // 3000px wide, scrolled horizontally
)
```

The anchor is captured when the tooltip appears and does not follow the cursor afterwards, so an `interactive` tooltip stays reachable. A tap-triggered tooltip anchors at the tap. A programmatic `controller.show()` with no pointer present falls back to the child's rect.

Against a point there are no target edges to align to, so `alignment` picks which of the tooltip's own edges lands on the pointer: `start` extends it to the trailing side, `end` to the leading side, `center` centres it.

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

20 combinations are available:

| direction | alignment | position |
|-----------|-----------|----------|
| `top` | `start` | above, left-aligned |
| `top` | `center` | above, centered |
| `top` | `end` | above, right-aligned |
| `top` | `startTargetCenter` | above, left-aligned, arrow at target center |
| `top` | `endTargetCenter` | above, right-aligned, arrow at target center |
| `bottom` | `start` | below, left-aligned |
| `bottom` | `center` | below, centered |
| `bottom` | `end` | below, right-aligned |
| `bottom` | `startTargetCenter` | below, left-aligned, arrow at target center |
| `bottom` | `endTargetCenter` | below, right-aligned, arrow at target center |
| `left` | `start` | left, top-aligned |
| `left` | `center` | left, centered |
| `left` | `end` | left, bottom-aligned |
| `left` | `startTargetCenter` | left, top-aligned, arrow at target center |
| `left` | `endTargetCenter` | left, bottom-aligned, arrow at target center |
| `right` | `start` | right, top-aligned |
| `right` | `center` | right, centered |
| `right` | `end` | right, bottom-aligned |
| `right` | `startTargetCenter` | right, top-aligned, arrow at target center |
| `right` | `endTargetCenter` | right, bottom-aligned, arrow at target center |

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

Use `startTargetCenter` or `endTargetCenter` to keep the arrow pointing at the target widget's center. This is useful when the tooltip is wider than the target.

```dart
JustTooltip(
  message: 'A long tooltip message that is wider than the target',
  alignment: TooltipAlignment.startTargetCenter,
  theme: JustTooltipTheme(showArrow: true),
  child: SmallIcon(),
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

// Read the live visibility (reflects hover/tap/auto-hide too)
if (controller.isShowing) { /* ... */ }
```

The tooltip is the single source of truth for its visibility — the controller drives it and reads its live state through `isShowing`. There is no separate controller state to keep in sync, so `show()`/`hide()`/`toggle()` behave correctly no matter how the tooltip was last dismissed (hover-out, tap, or auto-hide). Calling `show()` before the widget has mounted is honoured once it mounts.

To observe visibility changes, use the widget's `onShow`/`onHide` callbacks.

> **Migrating from ≤ 0.2.x:** `JustTooltipController` is no longer a `ChangeNotifier`. Replace the removed `shouldShow` getter with `isShowing`, and replace `addListener` with the widget's `onShow`/`onHide` callbacks. See the migration section below.

## Single Instance & Scoping

By default, showing any tooltip dismisses any other — only one is visible at a time, app-wide. This is enforced by a shared `TooltipRegistry`.

To scope the policy to a group (so tooltips in different groups don't dismiss each other), pass a shared `TooltipRegistry` instance:

```dart
final registry = TooltipRegistry();

JustTooltip(message: 'A', registry: registry, child: WidgetA())
JustTooltip(message: 'B', registry: registry, child: WidgetB())
// A and B dismiss each other, but not tooltips outside this registry.
```

Omit `registry` to use the app-global default.

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

## Hide on Empty Message

By default, the tooltip is suppressed when `message` is an empty string. This prevents showing an empty tooltip box when the message content is not yet available or intentionally cleared.

```dart
// Tooltip will NOT appear when message is ''
JustTooltip(
  message: '',  // empty → tooltip suppressed
  child: MyWidget(),
)

// Explicitly allow empty-message tooltips
JustTooltip(
  message: '',
  hideOnEmptyMessage: false,  // shows an empty tooltip box
  child: MyWidget(),
)
```

This only affects `message`-based tooltips. When `tooltipBuilder` is used, this parameter has no effect.

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
| `alignment` | `TooltipAlignment` | `center` | Alignment along the cross-axis (start, center, end, startTargetCenter, endTargetCenter) |
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
| `hideOnEmptyMessage` | `bool` | `true` | Suppress tooltip when `message` is empty |
| `onShow` | `VoidCallback?` | `null` | Called when tooltip is shown |
| `onHide` | `VoidCallback?` | `null` | Called when tooltip is hidden |
| `registry` | `TooltipRegistry?` | `null` | Scopes the "one visible at a time" policy; `null` uses the app-global default |

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

## Migration to 0.3.0

`JustTooltipController` is no longer a `ChangeNotifier`; it drives the tooltip and reads its live state instead of holding its own.

```dart
// Before (≤ 0.2.x)
if (controller.shouldShow) { ... }
controller.addListener(() { /* visibility changed */ });

// After (0.3.0)
if (controller.isShowing) { ... }          // shouldShow → isShowing
// observe via the widget's callbacks instead of addListener:
JustTooltip(onShow: () {...}, onHide: () {...}, controller: controller, child: ...)
```

- `shouldShow` → `isShowing` (now reflects hover/tap/auto-hide too).
- `addListener`/`removeListener`/`dispose` removed — use `onShow`/`onHide`. You no longer need to dispose the controller.
- The internal `resetShouldShow()` was removed (it is no longer needed).
- `JustTooltipPositionDelegate`, `TooltipShapePainter`, and `JustTooltipOverlay` are no longer exported (internal implementation details).

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
