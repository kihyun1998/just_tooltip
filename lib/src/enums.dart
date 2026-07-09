/// The animation type used when showing and hiding the tooltip.
enum TooltipAnimation {
  /// No animation; the tooltip appears and disappears instantly.
  none,

  /// Opacity fade (default). Same as the original behavior.
  fade,

  /// Scales from center.
  scale,

  /// Slides in from the opposite side of [TooltipDirection].
  slide,

  /// Fade + scale combined.
  fadeScale,

  /// Fade + slide combined.
  fadeSlide,

  /// Fade + rotation combined.
  rotation,
}

/// What the tooltip is positioned against.
enum TooltipAnchor {
  /// The child's rect (default). The child is both the hover region and the
  /// anchor — right for small children, wrong for one wider than the pointer's
  /// neighbourhood.
  child,

  /// The pointer's position, captured when the tooltip is shown. The child
  /// stays the hover region; the tooltip appears beside the cursor.
  pointer,
}

/// The direction in which the tooltip appears relative to the child widget.
enum TooltipDirection {
  /// Tooltip appears above the child.
  top,

  /// Tooltip appears below the child.
  bottom,

  /// Tooltip appears to the left of the child.
  left,

  /// Tooltip appears to the right of the child.
  right,
}

/// The alignment of the tooltip along the cross-axis of the direction.
///
/// For [TooltipDirection.top] and [TooltipDirection.bottom]:
/// - [start] aligns to the left (or right in RTL).
/// - [center] aligns to the horizontal center.
/// - [end] aligns to the right (or left in RTL).
///
/// For [TooltipDirection.left] and [TooltipDirection.right]:
/// - [start] aligns to the top.
/// - [center] aligns to the vertical center.
/// - [end] aligns to the bottom.
enum TooltipAlignment {
  /// Aligns the tooltip to the start edge of the child.
  start,

  /// Aligns the tooltip to the center of the child.
  center,

  /// Aligns the tooltip to the end edge of the child.
  end,

  /// Aligns the tooltip like [start], but the arrow points to the center of
  /// the target widget instead of using the fixed [arrowPositionRatio].
  startTargetCenter,

  /// Aligns the tooltip like [end], but the arrow points to the center of
  /// the target widget instead of using the fixed [arrowPositionRatio].
  endTargetCenter,
}
