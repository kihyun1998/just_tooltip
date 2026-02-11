import 'package:flutter/material.dart';

import 'enums.dart';

/// The overlay content for a tooltip.
///
/// Renders the tooltip box as a [Material] widget with the configured styling.
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

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: tooltipBuilder != null
          ? tooltipBuilder!(context)
          : Text(
              message!,
              style: textStyle ?? TextStyle(color: Colors.white, fontSize: 14),
            ),
    );

    if (boxShadow != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: Material(
          elevation: 0,
          borderRadius: borderRadius,
          color: backgroundColor,
          child: content,
        ),
      );
    }

    return Material(
      elevation: elevation,
      borderRadius: borderRadius,
      color: backgroundColor,
      child: content,
    );
  }
}
