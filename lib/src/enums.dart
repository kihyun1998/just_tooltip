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
  /// The visible part of the child's rect (default): the child intersected
  /// with every clip its ancestors apply. The child is both the hover region
  /// and the anchor — right for small children, wrong for one wider than the
  /// pointer's neighbourhood, whose visible centre is wherever the scroll
  /// viewport happens to be centred.
  ///
  /// The tooltip re-aims whenever the child moves, and hides once the child is
  /// clipped out of sight entirely.
  child,

  /// The pointer's position, captured when the tooltip is shown. The child
  /// stays the hover region; the tooltip appears beside the cursor.
  pointer,
}

/// How a tap on the child toggles the tooltip.
enum TooltipTap {
  /// A tap does nothing (default).
  none,

  /// The tap is claimed: the tooltip's tap recognizer competes in the gesture
  /// arena and, being innermost, wins it, so a tap handler on an ancestor does
  /// not fire.
  claim,

  /// The tap is watched without being claimed: the tooltip toggles **and** a
  /// tap handler on an ancestor still fires.
  ///
  /// The tooltip takes part in the gesture arena but never wins it. It toggles
  /// when a primary-button press is released within the touch slop of where
  /// it went down, provided no other gesture has won by then — so an
  /// ancestor's long press, drag or scroll leaves the tooltip alone.
  ///
  /// Gestures that are decided only after the release still see the tooltip
  /// toggle: an ancestor's double tap fires and the tooltip opens on the first
  /// tap and closes on the second, and a tap handler inside the child fires
  /// along with the tooltip. Unlike [claim], this mode gives screen readers no
  /// tap action to open the tooltip with.
  observe,
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
