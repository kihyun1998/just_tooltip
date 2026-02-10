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
}
