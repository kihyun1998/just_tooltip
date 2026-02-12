import 'package:flutter/material.dart';

import 'enums.dart';
import 'tooltip_shape_painter.dart';

/// The overlay content for a tooltip.
///
/// Renders the tooltip box as a [Material] widget with the configured styling.
/// When [showArrow] is `true`, renders using a [CustomPaint] with a unified
/// path that integrates the arrow into the tooltip shape, so that background,
/// shadow, and any future border all follow the combined outline.
class JustTooltipOverlay extends StatelessWidget {
  const JustTooltipOverlay({
    super.key,
    required this.direction,
    required this.alignment,
    required this.backgroundColor,
    required this.borderRadius,
    required this.padding,
    required this.elevation,
    this.boxShadow,
    this.message,
    this.tooltipBuilder,
    this.textStyle,
    this.textDirection = TextDirection.ltr,
    this.showArrow = false,
    this.arrowBaseWidth = 12.0,
    this.arrowLength = 6.0,
    this.arrowPositionRatio = 0.25,
    this.borderColor,
    this.borderWidth = 0.0,
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
  final List<BoxShadow>? boxShadow;
  final String? message;
  final WidgetBuilder? tooltipBuilder;
  final TextStyle? textStyle;
  final TextDirection textDirection;

  /// Whether to display a triangular arrow connecting the tooltip to the target.
  final bool showArrow;

  /// The width of the arrow's base (the edge flush against the tooltip body).
  final double arrowBaseWidth;

  /// The length of the arrow from its base to tip.
  final double arrowLength;

  /// Where the arrow sits along the edge for start/end alignment (0.0–1.0).
  final double arrowPositionRatio;

  /// The border color drawn along the tooltip outline (including arrow).
  final Color? borderColor;

  /// The border stroke width.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final rawContent = tooltipBuilder != null
        ? tooltipBuilder!(context)
        : Text(
            message!,
            style: textStyle ?? TextStyle(color: Colors.white, fontSize: 14),
          );

    if (!showArrow) {
      return _buildMaterialBox(rawContent);
    }

    return _buildArrowBox(rawContent);
  }

  /// Original Material-based rendering (no arrow).
  Widget _buildMaterialBox(Widget content) {
    final padded = Padding(padding: padding, child: content);
    final hasBorder = borderColor != null && borderWidth > 0;

    if (boxShadow != null || hasBorder) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
          border: hasBorder
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
        ),
        child: Material(
          elevation: 0,
          borderRadius: borderRadius,
          color: backgroundColor,
          child: padded,
        ),
      );
    }

    return Material(
      elevation: elevation,
      borderRadius: borderRadius,
      color: backgroundColor,
      child: padded,
    );
  }

  /// CustomPaint-based rendering with unified shape (box + arrow).
  Widget _buildArrowBox(Widget content) {
    // Extra padding on the arrow side so content doesn't overlap the arrow.
    final arrowPadding = switch (direction) {
      TooltipDirection.top => EdgeInsets.only(bottom: arrowLength),
      TooltipDirection.bottom => EdgeInsets.only(top: arrowLength),
      TooltipDirection.left => EdgeInsets.only(right: arrowLength),
      TooltipDirection.right => EdgeInsets.only(left: arrowLength),
    };

    return DefaultTextStyle(
      style: textStyle ?? TextStyle(color: Colors.white, fontSize: 14),
      child: CustomPaint(
        painter: TooltipShapePainter(
          direction: direction,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          alignment: alignment,
          showArrow: true,
          arrowBaseWidth: arrowBaseWidth,
          arrowLength: arrowLength,
          arrowPositionRatio: arrowPositionRatio,
          elevation: elevation,
          boxShadow: boxShadow,
          borderColor: borderColor,
          borderWidth: borderWidth,
        ),
        child: Padding(
          padding: padding + arrowPadding,
          child: content,
        ),
      ),
    );
  }
}
