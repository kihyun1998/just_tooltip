import 'package:flutter/material.dart';

/// Groups all visual styling parameters for [JustTooltip] into a single
/// reusable data class.
///
/// {@tool snippet}
/// ```dart
/// const myTheme = JustTooltipTheme(
///   backgroundColor: Colors.black87,
///   textStyle: TextStyle(color: Colors.white),
///   showArrow: true,
/// );
///
/// JustTooltip(message: 'Hello', theme: myTheme, child: MyWidget())
/// ```
/// {@end-tool}
class JustTooltipTheme {
  const JustTooltipTheme({
    this.backgroundColor = const Color(0xFF616161),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.elevation = 4.0,
    this.boxShadow,
    this.borderColor,
    this.borderWidth = 0.0,
    this.textStyle,
    this.showArrow = false,
    this.arrowBaseWidth = 12.0,
    this.arrowLength = 6.0,
    this.arrowPositionRatio = 0.25,
  })  : assert(arrowBaseWidth > 0, 'arrowBaseWidth must be positive.'),
        assert(arrowLength > 0, 'arrowLength must be positive.'),
        assert(
          arrowPositionRatio >= 0.0 && arrowPositionRatio <= 1.0,
          'arrowPositionRatio must be between 0.0 and 1.0.',
        );

  /// The background color of the tooltip box.
  final Color backgroundColor;

  /// The border radius of the tooltip box.
  final BorderRadius borderRadius;

  /// The padding inside the tooltip box.
  final EdgeInsets padding;

  /// The elevation (shadow) of the tooltip box.
  ///
  /// Ignored when [boxShadow] is provided.
  final double elevation;

  /// Custom box shadows for the tooltip.
  ///
  /// When provided, [elevation] is ignored and these shadows are used instead,
  /// allowing fine-grained control over shadow color, blur, spread, and offset.
  final List<BoxShadow>? boxShadow;

  /// The border color drawn along the tooltip outline.
  ///
  /// When [showArrow] is `true`, the border follows the unified shape
  /// (including the arrow). When `null` or [borderWidth] is 0, no border
  /// is drawn.
  final Color? borderColor;

  /// The border stroke width.
  final double borderWidth;

  /// The text style for the tooltip message. Ignored when a custom
  /// `tooltipBuilder` is used.
  final TextStyle? textStyle;

  /// Whether to display a triangular arrow connecting the tooltip to the target.
  final bool showArrow;

  /// The width of the arrow's base (the edge flush against the tooltip body).
  final double arrowBaseWidth;

  /// The length of the arrow from its base to tip.
  final double arrowLength;

  /// Where the arrow sits along the tooltip edge for start/end alignment,
  /// as a ratio from 0.0 to 1.0.
  final double arrowPositionRatio;

  /// Creates a copy of this theme with the given fields replaced.
  JustTooltipTheme copyWith({
    Color? backgroundColor,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    double? elevation,
    List<BoxShadow>? boxShadow,
    Color? borderColor,
    double? borderWidth,
    TextStyle? textStyle,
    bool? showArrow,
    double? arrowBaseWidth,
    double? arrowLength,
    double? arrowPositionRatio,
  }) {
    return JustTooltipTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      elevation: elevation ?? this.elevation,
      boxShadow: boxShadow ?? this.boxShadow,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      textStyle: textStyle ?? this.textStyle,
      showArrow: showArrow ?? this.showArrow,
      arrowBaseWidth: arrowBaseWidth ?? this.arrowBaseWidth,
      arrowLength: arrowLength ?? this.arrowLength,
      arrowPositionRatio: arrowPositionRatio ?? this.arrowPositionRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JustTooltipTheme) return false;
    return backgroundColor == other.backgroundColor &&
        borderRadius == other.borderRadius &&
        padding == other.padding &&
        elevation == other.elevation &&
        boxShadow == other.boxShadow &&
        borderColor == other.borderColor &&
        borderWidth == other.borderWidth &&
        textStyle == other.textStyle &&
        showArrow == other.showArrow &&
        arrowBaseWidth == other.arrowBaseWidth &&
        arrowLength == other.arrowLength &&
        arrowPositionRatio == other.arrowPositionRatio;
  }

  @override
  int get hashCode {
    return Object.hash(
      backgroundColor,
      borderRadius,
      padding,
      elevation,
      boxShadow,
      borderColor,
      borderWidth,
      textStyle,
      showArrow,
      arrowBaseWidth,
      arrowLength,
      arrowPositionRatio,
    );
  }
}
