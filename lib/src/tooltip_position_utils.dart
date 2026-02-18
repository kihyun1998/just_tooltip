import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'enums.dart';

/// A [SingleChildLayoutDelegate] that positions a tooltip relative to a target
/// widget, with automatic direction flipping and viewport clamping.
///
/// The tooltip is constrained to fit within the viewport minus [screenMargin],
/// and its position is clamped so it never extends beyond that boundary.
/// If there is not enough space in the preferred [direction], the tooltip
/// automatically flips to the opposite side.
class JustTooltipPositionDelegate extends SingleChildLayoutDelegate {
  JustTooltipPositionDelegate({
    required this.targetRect,
    required this.direction,
    required this.alignment,
    required this.gap,
    this.crossAxisOffset = 0,
    this.screenMargin = 8.0,
    this.textDirection = TextDirection.ltr,
    this.onDirectionResolved,
  });

  /// The global rect of the target (child) widget.
  final Rect targetRect;

  /// The preferred direction in which the tooltip appears.
  final TooltipDirection direction;

  /// The alignment of the tooltip along the cross-axis.
  final TooltipAlignment alignment;

  /// The gap between the child and the tooltip edge.
  final double gap;

  /// Additional offset along the cross-axis.
  final double crossAxisOffset;

  /// Minimum distance from the viewport edges.
  final double screenMargin;

  /// Text direction for RTL support.
  final TextDirection textDirection;

  /// Called during layout with the actual direction used after auto-flip.
  ///
  /// This enables the overlay to orient its arrow on the correct side,
  /// even when the preferred direction was flipped due to space constraints.
  final ValueChanged<TooltipDirection>? onDirectionResolved;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: math.max(0, constraints.maxWidth - screenMargin * 2),
      maxHeight: math.max(0, constraints.maxHeight - screenMargin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
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

    // Try preferred direction; flip if not enough space.
    var dir = direction;
    if (!_hasSpace(dir, size, childSize)) {
      final flipped = _flip(dir);
      if (_hasSpace(flipped, size, childSize)) {
        dir = flipped;
      }
      // If neither direction has space, keep original and let clamping handle it.
    }

    // Notify listener of the resolved direction.
    onDirectionResolved?.call(dir);

    // Compute ideal position.
    final offset = _computeOffset(dir, resolvedAlignment, childSize);

    // Clamp to viewport bounds respecting screenMargin.
    return Offset(
      offset.dx.clamp(
        screenMargin,
        math.max(screenMargin, size.width - childSize.width - screenMargin),
      ),
      offset.dy.clamp(
        screenMargin,
        math.max(screenMargin, size.height - childSize.height - screenMargin),
      ),
    );
  }

  /// Whether there is enough space in the given [dir] for the tooltip.
  bool _hasSpace(TooltipDirection dir, Size viewport, Size childSize) {
    switch (dir) {
      case TooltipDirection.top:
        return targetRect.top - gap - childSize.height >= screenMargin;
      case TooltipDirection.bottom:
        return targetRect.bottom + gap + childSize.height <=
            viewport.height - screenMargin;
      case TooltipDirection.left:
        return targetRect.left - gap - childSize.width >= screenMargin;
      case TooltipDirection.right:
        return targetRect.right + gap + childSize.width <=
            viewport.width - screenMargin;
    }
  }

  /// Returns the opposite direction.
  static TooltipDirection _flip(TooltipDirection dir) {
    switch (dir) {
      case TooltipDirection.top:
        return TooltipDirection.bottom;
      case TooltipDirection.bottom:
        return TooltipDirection.top;
      case TooltipDirection.left:
        return TooltipDirection.right;
      case TooltipDirection.right:
        return TooltipDirection.left;
    }
  }

  /// Computes the ideal tooltip offset (before clamping).
  Offset _computeOffset(
    TooltipDirection dir,
    TooltipAlignment align,
    Size childSize,
  ) {
    double x, y;

    switch (dir) {
      case TooltipDirection.top:
        y = targetRect.top - gap - childSize.height;
        x = _crossAxisX(align, childSize.width);
      case TooltipDirection.bottom:
        y = targetRect.bottom + gap;
        x = _crossAxisX(align, childSize.width);
      case TooltipDirection.left:
        x = targetRect.left - gap - childSize.width;
        y = _crossAxisY(align, childSize.height);
      case TooltipDirection.right:
        x = targetRect.right + gap;
        y = _crossAxisY(align, childSize.height);
    }

    return Offset(x, y);
  }

  /// Cross-axis X position for top/bottom directions.
  double _crossAxisX(TooltipAlignment align, double tooltipWidth) {
    final dx =
        align == TooltipAlignment.end ? -crossAxisOffset : crossAxisOffset;
    switch (align) {
      case TooltipAlignment.start:
        return targetRect.left + dx;
      case TooltipAlignment.center:
        return targetRect.center.dx - tooltipWidth / 2 + dx;
      case TooltipAlignment.end:
        return targetRect.right - tooltipWidth + dx;
    }
  }

  /// Cross-axis Y position for left/right directions.
  double _crossAxisY(TooltipAlignment align, double tooltipHeight) {
    final dy =
        align == TooltipAlignment.end ? -crossAxisOffset : crossAxisOffset;
    switch (align) {
      case TooltipAlignment.start:
        return targetRect.top + dy;
      case TooltipAlignment.center:
        return targetRect.center.dy - tooltipHeight / 2 + dy;
      case TooltipAlignment.end:
        return targetRect.bottom - tooltipHeight + dy;
    }
  }

  @override
  bool shouldRelayout(JustTooltipPositionDelegate oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        direction != oldDelegate.direction ||
        alignment != oldDelegate.alignment ||
        gap != oldDelegate.gap ||
        crossAxisOffset != oldDelegate.crossAxisOffset ||
        screenMargin != oldDelegate.screenMargin ||
        textDirection != oldDelegate.textDirection;
  }
}
