import 'package:flutter/material.dart';

import 'arrow_painter.dart';
import 'enums.dart';

/// The overlay content for a tooltip, combining the tooltip box and an
/// optional arrow indicator.
///
/// For [TooltipDirection.top]/[bottom], the box and arrow are arranged in a
/// [Column]. For [TooltipDirection.left]/[right], they are arranged in a [Row].
class JustTooltipOverlay extends StatelessWidget {
  const JustTooltipOverlay({
    super.key,
    required this.direction,
    required this.alignment,
    required this.backgroundColor,
    required this.borderRadius,
    required this.padding,
    required this.elevation,
    required this.showArrow,
    required this.arrowWidth,
    required this.arrowHeight,
    this.message,
    this.tooltipBuilder,
    this.textStyle,
    this.textDirection = TextDirection.ltr,
  }) : assert(
         message != null || tooltipBuilder != null,
         'Either message or tooltipBuilder must be provided.',
       );

  final TooltipDirection direction;
  final TooltipAlignment alignment;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double elevation;
  final bool showArrow;
  final double arrowWidth;
  final double arrowHeight;
  final String? message;
  final WidgetBuilder? tooltipBuilder;
  final TextStyle? textStyle;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final box = Material(
      elevation: elevation,
      borderRadius: borderRadius,
      color: backgroundColor,
      child: Padding(
        padding: padding,
        child: tooltipBuilder != null
            ? tooltipBuilder!(context)
            : Text(
                message!,
                style: textStyle ??
                    TextStyle(color: Colors.white, fontSize: 14),
              ),
      ),
    );

    if (!showArrow) return box;

    final arrow = CustomPaint(
      size: _arrowSize,
      painter: ArrowPainter(
        direction: direction,
        color: backgroundColor,
      ),
    );

    final crossAlignment = _resolveCrossAxisAlignment();

    final isVertical =
        direction == TooltipDirection.top || direction == TooltipDirection.bottom;

    // For top: box first, then arrow (arrow points down toward child).
    // For bottom: arrow first (arrow points up toward child), then box.
    // For left: box first, then arrow (arrow points right toward child).
    // For right: arrow first (arrow points left toward child), then box.
    final children = _shouldArrowBeFirst
        ? [arrow, box]
        : [box, arrow];

    return isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAlignment,
            children: children,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAlignment,
            children: children,
          );
  }

  Size get _arrowSize {
    final isVertical =
        direction == TooltipDirection.top || direction == TooltipDirection.bottom;
    return isVertical
        ? Size(arrowWidth, arrowHeight)
        : Size(arrowHeight, arrowWidth);
  }

  bool get _shouldArrowBeFirst =>
      direction == TooltipDirection.bottom || direction == TooltipDirection.right;

  CrossAxisAlignment _resolveCrossAxisAlignment() {
    var resolved = alignment;

    // For horizontal directions (top/bottom), apply RTL resolution.
    final isVertical =
        direction == TooltipDirection.top || direction == TooltipDirection.bottom;
    if (isVertical && textDirection == TextDirection.rtl) {
      if (alignment == TooltipAlignment.start) {
        resolved = TooltipAlignment.end;
      } else if (alignment == TooltipAlignment.end) {
        resolved = TooltipAlignment.start;
      }
    }

    switch (resolved) {
      case TooltipAlignment.start:
        return CrossAxisAlignment.start;
      case TooltipAlignment.center:
        return CrossAxisAlignment.center;
      case TooltipAlignment.end:
        return CrossAxisAlignment.end;
    }
  }
}
