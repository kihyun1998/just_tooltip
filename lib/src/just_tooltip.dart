import 'dart:async';

import 'package:flutter/material.dart';

import 'enums.dart';
import 'just_tooltip_controller.dart';
import 'just_tooltip_overlay.dart';
import 'tooltip_position_utils.dart';

/// A highly customizable tooltip widget that supports directional placement,
/// fine-grained alignment, and multiple trigger modes.
///
/// Either [message] or [tooltipBuilder] must be provided.
///
/// {@tool snippet}
/// ```dart
/// JustTooltip(
///   message: 'Hello!',
///   direction: TooltipDirection.top,
///   alignment: TooltipAlignment.start,
///   child: ElevatedButton(
///     onPressed: () {},
///     child: Text('Hover me'),
///   ),
/// )
/// ```
/// {@end-tool}
class JustTooltip extends StatefulWidget {
  const JustTooltip({
    super.key,
    required this.child,
    this.message,
    this.tooltipBuilder,
    this.direction = TooltipDirection.top,
    this.alignment = TooltipAlignment.center,
    this.offset = 8.0,
    this.crossAxisOffset = 0.0,
    this.backgroundColor = const Color(0xFF616161),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.elevation = 4.0,
    this.textStyle,
    this.controller,
    this.enableTap = false,
    this.enableHover = true,
    this.animationDuration = const Duration(milliseconds: 150),
    this.onShow,
    this.onHide,
  }) : assert(
         message != null || tooltipBuilder != null,
         'Either message or tooltipBuilder must be provided.',
       );

  /// The child widget that the tooltip is anchored to.
  final Widget child;

  /// Simple text content for the tooltip.
  final String? message;

  /// Builder for custom tooltip content. Takes precedence over [message].
  final WidgetBuilder? tooltipBuilder;

  /// The direction in which the tooltip appears relative to [child].
  final TooltipDirection direction;

  /// The alignment of the tooltip along the cross-axis of [direction].
  final TooltipAlignment alignment;

  /// The gap between the child and the tooltip edge.
  final double offset;

  /// Additional offset along the cross-axis of [direction].
  ///
  /// For [TooltipAlignment.start] and [TooltipAlignment.end], a positive value
  /// moves the tooltip toward center (inward from the aligned edge).
  /// For [TooltipAlignment.center], a positive value moves toward the end
  /// direction (right for top/bottom, down for left/right).
  final double crossAxisOffset;

  /// The background color of the tooltip box.
  final Color backgroundColor;

  /// The border radius of the tooltip box.
  final BorderRadius borderRadius;

  /// The padding inside the tooltip box.
  final EdgeInsets padding;

  /// The elevation (shadow) of the tooltip box.
  final double elevation;

  /// The text style for [message]. Ignored when [tooltipBuilder] is used.
  final TextStyle? textStyle;

  /// An optional controller for programmatic show/hide.
  final JustTooltipController? controller;

  /// Whether tapping the child toggles the tooltip.
  final bool enableTap;

  /// Whether hovering over the child shows the tooltip.
  final bool enableHover;

  /// The duration of the fade-in/fade-out animation.
  final Duration animationDuration;

  /// Called when the tooltip becomes visible.
  final VoidCallback? onShow;

  /// Called when the tooltip becomes hidden.
  final VoidCallback? onHide;

  @override
  State<JustTooltip> createState() => _JustTooltipState();
}

class _JustTooltipState extends State<JustTooltip>
    with SingleTickerProviderStateMixin {
  /// Tracks all currently visible tooltip states so only one is shown at a time.
  static final Set<_JustTooltipState> _visibleInstances = {};

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  Timer? _hoverHideTimer;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animationController.addStatusListener(_onAnimationStatus);
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(JustTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }
  }

  @override
  void deactivate() {
    // Immediately remove overlay when this widget is removed from the tree
    // (e.g., on route change).
    _hideImmediate();
    super.deactivate();
  }

  @override
  void dispose() {
    _hoverHideTimer?.cancel();
    widget.controller?.removeListener(_onControllerChanged);
    _animationController.removeStatusListener(_onAnimationStatus);
    _animationController.dispose();
    _hideImmediate();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controller listener
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    if (widget.controller!.shouldShow) {
      _show();
    } else {
      _hide();
    }
  }

  // ---------------------------------------------------------------------------
  // Show / hide logic
  // ---------------------------------------------------------------------------

  void _show() {
    if (_isShowing) return;

    // Dismiss any other visible tooltip first.
    for (final instance in _visibleInstances.toList()) {
      instance._hide();
    }

    _isShowing = true;
    _visibleInstances.add(this);

    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    widget.onShow?.call();
  }

  void _hide() {
    if (!_isShowing) return;
    _animationController.reverse();
  }

  void _hideImmediate() {
    _hoverHideTimer?.cancel();
    _isShowing = false;
    _visibleInstances.remove(this);
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _isShowing = false;
      _visibleInstances.remove(this);
      _overlayEntry?.remove();
      _overlayEntry?.dispose();
      _overlayEntry = null;
      widget.onHide?.call();
    }
  }

  // ---------------------------------------------------------------------------
  // Triggers
  // ---------------------------------------------------------------------------

  void _handleTap() {
    if (!widget.enableTap) return;
    if (_isShowing) {
      _hide();
    } else {
      _show();
    }
  }

  void _handleMouseEnter() {
    if (!widget.enableHover) return;
    _hoverHideTimer?.cancel();
    _show();
  }

  void _handleMouseExit() {
    if (!widget.enableHover) return;
    // Delay so that the user can move the cursor from the child to the tooltip
    // without the tooltip disappearing.
    _hoverHideTimer?.cancel();
    _hoverHideTimer = Timer(const Duration(milliseconds: 100), () {
      if (_isShowing) _hide();
    });
  }

  void _handleTooltipMouseEnter() {
    _hoverHideTimer?.cancel();
  }

  void _handleTooltipMouseExit() {
    if (!widget.enableHover) return;
    _hoverHideTimer?.cancel();
    _hoverHideTimer = Timer(const Duration(milliseconds: 100), () {
      if (_isShowing) _hide();
    });
  }

  // ---------------------------------------------------------------------------
  // Overlay entry
  // ---------------------------------------------------------------------------

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final textDirection = Directionality.of(context);
        final positionData = computeTooltipPosition(
          direction: widget.direction,
          alignment: widget.alignment,
          gap: widget.offset,
          crossAxisOffset: widget.crossAxisOffset,
          textDirection: textDirection,
        );

        return UnconstrainedBox(
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: positionData.targetAnchor,
            followerAnchor: positionData.followerAnchor,
            offset: positionData.offset,
            child: MouseRegion(
              onEnter: (_) => _handleTooltipMouseEnter(),
              onExit: (_) => _handleTooltipMouseExit(),
              child: FadeTransition(
                opacity: _animationController,
                child: JustTooltipOverlay(
                  direction: widget.direction,
                  alignment: widget.alignment,
                  backgroundColor: widget.backgroundColor,
                  borderRadius: widget.borderRadius,
                  padding: widget.padding,
                  elevation: widget.elevation,
                  message: widget.message,
                  tooltipBuilder: widget.tooltipBuilder,
                  textStyle: widget.textStyle,
                  textDirection: textDirection,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget child = CompositedTransformTarget(
      link: _layerLink,
      child: widget.child,
    );

    if (widget.enableHover) {
      child = MouseRegion(
        onEnter: (_) => _handleMouseEnter(),
        onExit: (_) => _handleMouseExit(),
        child: child,
      );
    }

    if (widget.enableTap) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: child,
      );
    }

    return child;
  }
}
