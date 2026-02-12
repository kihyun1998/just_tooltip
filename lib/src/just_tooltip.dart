import 'dart:async';

import 'package:flutter/material.dart';

import 'enums.dart';
import 'just_tooltip_controller.dart';
import 'just_tooltip_overlay.dart';
import 'tooltip_position_utils.dart';

/// A highly customizable tooltip widget that supports directional placement,
/// fine-grained alignment, and multiple trigger modes.
///
/// The tooltip automatically stays within the viewport bounds, flipping
/// direction when there is not enough space, and clamping its position
/// so it never extends beyond the screen edges.
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
    this.screenMargin = 8.0,
    this.backgroundColor = const Color(0xFF616161),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.elevation = 4.0,
    this.boxShadow,
    this.borderColor,
    this.borderWidth = 0.0,
    this.textStyle,
    this.controller,
    this.enableTap = false,
    this.enableHover = true,
    this.interactive = true,
    this.showArrow = false,
    this.arrowBaseWidth = 12.0,
    this.arrowLength = 6.0,
    this.arrowPositionRatio = 0.25,
    this.waitDuration,
    this.showDuration,
    this.animationDuration = const Duration(milliseconds: 150),
    this.onShow,
    this.onHide,
  })  : assert(
          message != null || tooltipBuilder != null,
          'Either message or tooltipBuilder must be provided.',
        ),
        assert(arrowBaseWidth > 0, 'arrowBaseWidth must be positive.'),
        assert(arrowLength > 0, 'arrowLength must be positive.'),
        assert(
          arrowPositionRatio >= 0.0 && arrowPositionRatio <= 1.0,
          'arrowPositionRatio must be between 0.0 and 1.0.',
        );

  /// The child widget that the tooltip is anchored to.
  final Widget child;

  /// Simple text content for the tooltip.
  final String? message;

  /// Builder for custom tooltip content. Takes precedence over [message].
  ///
  /// The caller is responsible for managing the size of the content returned
  /// by this builder. The tooltip is constrained to fit within the viewport
  /// (minus [screenMargin]), but content that exceeds those constraints may
  /// be clipped. Consider wrapping large content in a [SingleChildScrollView]
  /// or applying explicit size constraints.
  final WidgetBuilder? tooltipBuilder;

  /// The direction in which the tooltip appears relative to [child].
  ///
  /// If there is not enough space in this direction, the tooltip automatically
  /// flips to the opposite side.
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

  /// Minimum distance between the tooltip and the viewport edges.
  ///
  /// This margin is used both to constrain the tooltip's maximum size
  /// (viewport size minus margin on each side) and to clamp its position
  /// so it never extends beyond this boundary.
  final double screenMargin;

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

  /// The text style for [message]. Ignored when [tooltipBuilder] is used.
  final TextStyle? textStyle;

  /// An optional controller for programmatic show/hide.
  final JustTooltipController? controller;

  /// Whether tapping the child toggles the tooltip.
  final bool enableTap;

  /// Whether hovering over the child shows the tooltip.
  final bool enableHover;

  /// Whether the tooltip stays visible when the cursor moves over it.
  ///
  /// When `true` (default), the user can hover over the tooltip content
  /// without it disappearing. This is useful for tooltips with selectable
  /// text or interactive content.
  ///
  /// When `false`, the tooltip will begin to hide as soon as the cursor
  /// leaves the child widget, even if it enters the tooltip area.
  final bool interactive;

  /// Whether to display a triangular arrow connecting the tooltip to the target.
  ///
  /// When `true`, a small triangle is drawn on the tooltip's edge closest to
  /// the target widget. The arrow is part of the tooltip's unified shape, so
  /// background, shadow, and any future border all follow the combined outline.
  /// The arrow correctly follows auto-flip when the tooltip direction changes
  /// due to insufficient viewport space.
  final bool showArrow;

  /// The width of the arrow's base (the edge flush against the tooltip body).
  ///
  /// For top/bottom tooltips, this is the horizontal width.
  /// For left/right tooltips, this is the vertical height.
  /// Defaults to 12.0.
  final double arrowBaseWidth;

  /// The length of the arrow from its base to tip.
  ///
  /// This determines how far the arrow protrudes from the tooltip body toward
  /// the target widget. Defaults to 6.0.
  final double arrowLength;

  /// Where the arrow sits along the tooltip edge for [TooltipAlignment.start]
  /// and [TooltipAlignment.end], as a ratio from 0.0 to 1.0.
  ///
  /// `0.0` places the arrow at the border-radius edge, `0.5` at the center.
  /// For [TooltipAlignment.end], the value is mirrored (`1 - ratio`).
  /// Defaults to `0.25`.
  final double arrowPositionRatio;

  /// The delay before the tooltip appears after hovering.
  ///
  /// If `null` (default), the tooltip appears immediately on hover.
  final Duration? waitDuration;

  /// The duration the tooltip remains visible before automatically hiding.
  ///
  /// If `null` (default), the tooltip stays visible until the user moves
  /// the cursor away (hover) or taps again (tap).
  final Duration? showDuration;

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

  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  Timer? _hoverHideTimer;
  Timer? _hoverShowTimer;
  Timer? _autoHideTimer;
  bool _isShowing = false;

  /// The actual direction after auto-flip, used to orient the arrow.
  TooltipDirection? _resolvedDirection;

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
    _hoverShowTimer?.cancel();
    _autoHideTimer?.cancel();
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
    _restartAutoHideTimer();
  }

  void _restartAutoHideTimer() {
    _autoHideTimer?.cancel();
    if (widget.showDuration != null) {
      _autoHideTimer = Timer(widget.showDuration!, () {
        if (_isShowing) _hide();
      });
    }
  }

  void _hide() {
    if (!_isShowing) return;
    _animationController.reverse();
  }

  void _hideImmediate() {
    _hoverHideTimer?.cancel();
    _hoverShowTimer?.cancel();
    _autoHideTimer?.cancel();
    _isShowing = false;
    _resolvedDirection = null;
    _visibleInstances.remove(this);
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _isShowing = false;
      _resolvedDirection = null;
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
    if (_isShowing) {
      // Already visible — reset the auto-hide timer on re-enter.
      _restartAutoHideTimer();
      return;
    }
    if (widget.waitDuration != null) {
      _hoverShowTimer?.cancel();
      _hoverShowTimer = Timer(widget.waitDuration!, () {
        _show();
      });
    } else {
      _show();
    }
  }

  void _handleMouseExit() {
    if (!widget.enableHover) return;
    _hoverShowTimer?.cancel();
    // When showDuration is set, let the auto-hide timer handle hiding.
    if (widget.showDuration != null) return;
    if (widget.interactive) {
      // Delay so that the user can move the cursor from the child to the tooltip
      // without the tooltip disappearing.
      _hoverHideTimer?.cancel();
      _hoverHideTimer = Timer(const Duration(milliseconds: 100), () {
        if (_isShowing) _hide();
      });
    } else {
      if (_isShowing) _hide();
    }
  }

  void _handleTooltipMouseEnter() {
    if (!widget.interactive) return;
    _hoverHideTimer?.cancel();
    // Pause the auto-hide timer while the cursor is on the tooltip.
    _autoHideTimer?.cancel();
  }

  void _handleTooltipMouseExit() {
    if (!widget.interactive) return;
    if (!widget.enableHover) return;
    if (widget.showDuration != null) {
      // Resume the auto-hide countdown after leaving the tooltip.
      _restartAutoHideTimer();
      return;
    }
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

        // Get target's global position and size.
        final renderBox = this.context.findRenderObject() as RenderBox;
        final targetPosition = renderBox.localToGlobal(Offset.zero);
        final targetRect = targetPosition & renderBox.size;

        return CustomSingleChildLayout(
          delegate: TooltipPositionDelegate(
            targetRect: targetRect,
            direction: widget.direction,
            alignment: widget.alignment,
            gap: widget.offset,
            crossAxisOffset: widget.crossAxisOffset,
            screenMargin: widget.screenMargin,
            textDirection: textDirection,
            onDirectionResolved: widget.showArrow
                ? (resolved) {
                    if (_resolvedDirection != resolved) {
                      _resolvedDirection = resolved;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _overlayEntry?.markNeedsBuild();
                      });
                    }
                  }
                : null,
          ),
          child: MouseRegion(
            onEnter: (_) => _handleTooltipMouseEnter(),
            onExit: (_) => _handleTooltipMouseExit(),
            child: FadeTransition(
              opacity: _animationController,
              child: JustTooltipOverlay(
                direction: _resolvedDirection ?? widget.direction,
                alignment: widget.alignment,
                backgroundColor: widget.backgroundColor,
                borderRadius: widget.borderRadius,
                padding: widget.padding,
                elevation: widget.elevation,
                boxShadow: widget.boxShadow,
                message: widget.message,
                tooltipBuilder: widget.tooltipBuilder,
                textStyle: widget.textStyle,
                textDirection: textDirection,
                showArrow: widget.showArrow,
                arrowBaseWidth: widget.arrowBaseWidth,
                arrowLength: widget.arrowLength,
                arrowPositionRatio: widget.arrowPositionRatio,
                borderColor: widget.borderColor,
                borderWidth: widget.borderWidth,
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
    Widget child = widget.child;

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
