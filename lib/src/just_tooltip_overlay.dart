import 'package:flutter/material.dart';

import 'enums.dart';
import 'just_tooltip_theme.dart';
import 'tooltip_shape_painter.dart';

/// The overlay content for a tooltip.
///
/// Renders the tooltip box as a [Material] widget with the configured styling.
/// When [theme.showArrow] is `true`, renders using a [CustomPaint] with a
/// unified path that integrates the arrow into the tooltip shape, so that
/// background, shadow, and border all follow the combined outline.
class JustTooltipOverlay extends StatelessWidget {
  const JustTooltipOverlay({
    super.key,
    required this.direction,
    required this.alignment,
    required this.theme,
    this.message,
    this.tooltipBuilder,
    this.textDirection = TextDirection.ltr,
  }) : assert(
          message != null || tooltipBuilder != null,
          'Either message or tooltipBuilder must be provided.',
        );

  final TooltipDirection direction;
  final TooltipAlignment alignment;
  final JustTooltipTheme theme;
  final String? message;
  final WidgetBuilder? tooltipBuilder;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final rawContent = tooltipBuilder != null
        ? tooltipBuilder!(context)
        : Text(
            message!,
            style:
                theme.textStyle ?? TextStyle(color: Colors.white, fontSize: 14),
          );

    if (!theme.showArrow) {
      return _buildMaterialBox(rawContent);
    }

    return _buildArrowBox(rawContent);
  }

  /// Original Material-based rendering (no arrow).
  Widget _buildMaterialBox(Widget content) {
    final padded = Padding(padding: theme.padding, child: content);
    final hasBorder = theme.borderColor != null && theme.borderWidth > 0;

    if (theme.boxShadow != null || hasBorder) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: theme.borderRadius,
          color: theme.backgroundColor,
          boxShadow: theme.boxShadow,
          border: hasBorder
              ? Border.all(color: theme.borderColor!, width: theme.borderWidth)
              : null,
        ),
        child: Material(
          elevation: 0,
          borderRadius: theme.borderRadius,
          color: Colors.transparent,
          child: padded,
        ),
      );
    }

    return Material(
      elevation: theme.elevation,
      borderRadius: theme.borderRadius,
      color: theme.backgroundColor,
      child: padded,
    );
  }

  /// CustomPaint-based rendering with unified shape (box + arrow).
  Widget _buildArrowBox(Widget content) {
    // Extra padding on the arrow side so content doesn't overlap the arrow.
    final arrowPadding = switch (direction) {
      TooltipDirection.top => EdgeInsets.only(bottom: theme.arrowLength),
      TooltipDirection.bottom => EdgeInsets.only(top: theme.arrowLength),
      TooltipDirection.left => EdgeInsets.only(right: theme.arrowLength),
      TooltipDirection.right => EdgeInsets.only(left: theme.arrowLength),
    };

    return DefaultTextStyle(
      style: theme.textStyle ?? TextStyle(color: Colors.white, fontSize: 14),
      child: CustomPaint(
        painter: TooltipShapePainter(
          direction: direction,
          alignment: alignment,
          theme: theme,
        ),
        child: Padding(
          padding: theme.padding + arrowPadding,
          child: content,
        ),
      ),
    );
  }
}
