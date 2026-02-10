import 'package:flutter/rendering.dart';

import 'enums.dart';

/// Holds the computed anchor points and offset for positioning a tooltip
/// using [CompositedTransformFollower].
class TooltipPositionData {
  const TooltipPositionData({
    required this.targetAnchor,
    required this.followerAnchor,
    required this.offset,
  });

  /// The anchor point on the target (child) widget.
  final Alignment targetAnchor;

  /// The anchor point on the follower (tooltip) widget.
  final Alignment followerAnchor;

  /// Additional offset to apply between the target and follower.
  final Offset offset;
}

/// Computes the tooltip position data for a given [direction], [alignment],
/// and [gap] (the spacing between the child and tooltip).
///
/// [crossAxisOffset] shifts the tooltip along the cross-axis:
/// - For [TooltipAlignment.start]: positive moves toward center (inward).
/// - For [TooltipAlignment.end]: positive moves toward center (inward).
/// - For [TooltipAlignment.center]: positive moves toward the end direction.
///
/// When [textDirection] is [TextDirection.rtl], [TooltipAlignment.start] and
/// [TooltipAlignment.end] are swapped for horizontal directions (top/bottom).
TooltipPositionData computeTooltipPosition({
  required TooltipDirection direction,
  required TooltipAlignment alignment,
  required double gap,
  double crossAxisOffset = 0,
  TextDirection textDirection = TextDirection.ltr,
}) {
  // Resolve alignment for RTL when direction is top/bottom.
  var resolvedAlignment = alignment;
  if (textDirection == TextDirection.rtl &&
      (direction == TooltipDirection.top ||
          direction == TooltipDirection.bottom)) {
    if (alignment == TooltipAlignment.start) {
      resolvedAlignment = TooltipAlignment.end;
    } else if (alignment == TooltipAlignment.end) {
      resolvedAlignment = TooltipAlignment.start;
    }
  }

  switch (direction) {
    case TooltipDirection.top:
      return _topPosition(resolvedAlignment, gap, crossAxisOffset);
    case TooltipDirection.bottom:
      return _bottomPosition(resolvedAlignment, gap, crossAxisOffset);
    case TooltipDirection.left:
      return _leftPosition(resolvedAlignment, gap, crossAxisOffset);
    case TooltipDirection.right:
      return _rightPosition(resolvedAlignment, gap, crossAxisOffset);
  }
}

TooltipPositionData _topPosition(
  TooltipAlignment alignment,
  double gap,
  double crossAxisOffset,
) {
  final dx = alignment == TooltipAlignment.end
      ? -crossAxisOffset
      : crossAxisOffset;
  switch (alignment) {
    case TooltipAlignment.start:
      return TooltipPositionData(
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: Offset(dx, -gap),
      );
    case TooltipAlignment.center:
      return TooltipPositionData(
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: Offset(dx, -gap),
      );
    case TooltipAlignment.end:
      return TooltipPositionData(
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.bottomRight,
        offset: Offset(dx, -gap),
      );
  }
}

TooltipPositionData _bottomPosition(
  TooltipAlignment alignment,
  double gap,
  double crossAxisOffset,
) {
  final dx = alignment == TooltipAlignment.end
      ? -crossAxisOffset
      : crossAxisOffset;
  switch (alignment) {
    case TooltipAlignment.start:
      return TooltipPositionData(
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: Offset(dx, gap),
      );
    case TooltipAlignment.center:
      return TooltipPositionData(
        targetAnchor: Alignment.bottomCenter,
        followerAnchor: Alignment.topCenter,
        offset: Offset(dx, gap),
      );
    case TooltipAlignment.end:
      return TooltipPositionData(
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: Offset(dx, gap),
      );
  }
}

TooltipPositionData _leftPosition(
  TooltipAlignment alignment,
  double gap,
  double crossAxisOffset,
) {
  final dy = alignment == TooltipAlignment.end
      ? -crossAxisOffset
      : crossAxisOffset;
  switch (alignment) {
    case TooltipAlignment.start:
      return TooltipPositionData(
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.topRight,
        offset: Offset(-gap, dy),
      );
    case TooltipAlignment.center:
      return TooltipPositionData(
        targetAnchor: Alignment.centerLeft,
        followerAnchor: Alignment.centerRight,
        offset: Offset(-gap, dy),
      );
    case TooltipAlignment.end:
      return TooltipPositionData(
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.bottomRight,
        offset: Offset(-gap, dy),
      );
  }
}

TooltipPositionData _rightPosition(
  TooltipAlignment alignment,
  double gap,
  double crossAxisOffset,
) {
  final dy = alignment == TooltipAlignment.end
      ? -crossAxisOffset
      : crossAxisOffset;
  switch (alignment) {
    case TooltipAlignment.start:
      return TooltipPositionData(
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topLeft,
        offset: Offset(gap, dy),
      );
    case TooltipAlignment.center:
      return TooltipPositionData(
        targetAnchor: Alignment.centerRight,
        followerAnchor: Alignment.centerLeft,
        offset: Offset(gap, dy),
      );
    case TooltipAlignment.end:
      return TooltipPositionData(
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.bottomLeft,
        offset: Offset(gap, dy),
      );
  }
}
