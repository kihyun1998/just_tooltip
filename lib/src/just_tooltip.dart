import 'package:flutter/material.dart';

import 'enums.dart';
import 'just_tooltip_controller.dart';
import 'just_tooltip_overlay.dart';
import 'just_tooltip_theme.dart';
import 'tooltip_position_utils.dart';
import 'tooltip_visibility_scheduler.dart';

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
    this.theme = const JustTooltipTheme(),
    this.controller,
    this.enableTap = false,
    this.enableHover = true,
    this.interactive = true,
    this.waitDuration,
    this.showDuration,
    this.animation = TooltipAnimation.fade,
    this.animationCurve,
    this.fadeBegin = 0.0,
    this.scaleBegin = 0.0,
    this.slideOffset = 0.3,
    this.rotationBegin = -0.05,
    this.animationDuration = const Duration(milliseconds: 150),
    this.hideOnEmptyMessage = true,
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

  /// Visual styling for the tooltip (colors, borders, arrow, etc.).
  ///
  /// Defaults to [const JustTooltipTheme()] which uses a dark-grey
  /// background, 6 px border-radius, and no arrow.
  final JustTooltipTheme theme;

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

  /// The delay before the tooltip appears after hovering.
  ///
  /// If `null` (default), the tooltip appears immediately on hover.
  final Duration? waitDuration;

  /// The duration the tooltip remains visible before automatically hiding.
  ///
  /// If `null` (default), the tooltip stays visible until the user moves
  /// the cursor away (hover) or taps again (tap).
  final Duration? showDuration;

  /// The type of animation used to show and hide the tooltip.
  ///
  /// Defaults to [TooltipAnimation.fade].
  final TooltipAnimation animation;

  /// The curve applied to the tooltip animation.
  ///
  /// If `null` (default), the raw controller is used without a curve.
  final Curve? animationCurve;

  /// The starting opacity for fade-based animations.
  ///
  /// Used by [TooltipAnimation.fade], [TooltipAnimation.fadeScale],
  /// [TooltipAnimation.fadeSlide], and [TooltipAnimation.rotation].
  /// Defaults to `0.0` (fully transparent).
  final double fadeBegin;

  /// The starting scale for scale-based animations.
  ///
  /// Used by [TooltipAnimation.scale] and [TooltipAnimation.fadeScale].
  /// Defaults to `0.0` (point). Set to `0.8` for a subtle grow effect.
  final double scaleBegin;

  /// The slide distance as a fraction of the tooltip size.
  ///
  /// Used by [TooltipAnimation.slide] and [TooltipAnimation.fadeSlide].
  /// The direction is determined automatically from [direction].
  /// Defaults to `0.3`.
  final double slideOffset;

  /// The starting rotation in turns for the rotation animation.
  ///
  /// Used by [TooltipAnimation.rotation].
  /// Negative values rotate counter-clockwise, positive clockwise.
  /// Defaults to `-0.05` (about -18 degrees).
  final double rotationBegin;

  /// The duration of the show/hide animation.
  final Duration animationDuration;

  /// Whether to suppress the tooltip when [message] is empty.
  ///
  /// When `true` (default), the tooltip will not appear if [message] is
  /// provided but its value is an empty string. Set to `false` to allow
  /// empty-message tooltips to display.
  ///
  /// This has no effect when [tooltipBuilder] is used.
  final bool hideOnEmptyMessage;

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
  CurvedAnimation? _curvedAnimation;
  late final TooltipVisibilityScheduler _scheduler;
  bool _isShowing = false;

  /// The actual direction after auto-flip, used to orient the arrow.
  TooltipDirection? _resolvedDirection;

  /// The arrow's cross-axis position for [TooltipAlignment.targetCenter].
  double? _arrowCenterOffset;

  /// Returns the animation to drive transitions.
  /// Uses [CurvedAnimation] when a curve is configured, otherwise the raw controller.
  Animation<double> get _animation => _curvedAnimation ?? _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animationController.addStatusListener(_onAnimationStatus);
    _updateCurvedAnimation();
    _scheduler = TooltipVisibilityScheduler(
      onShow: _handleShowRequest,
      onHide: _hide,
    );
    widget.controller?.addListener(_onControllerChanged);
  }

  /// Snapshots the current widget config for the scheduler. Rebuilt per event
  /// so the scheduler holds no configuration state of its own.
  TooltipScheduleConfig get _scheduleConfig => TooltipScheduleConfig(
        enableHover: widget.enableHover,
        interactive: widget.interactive,
        waitDuration: widget.waitDuration,
        showDuration: widget.showDuration,
      );

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
    if (oldWidget.animationCurve != widget.animationCurve) {
      _updateCurvedAnimation();
    }
  }

  void _updateCurvedAnimation() {
    _curvedAnimation?.dispose();
    final curve = widget.animationCurve;
    if (curve != null) {
      _curvedAnimation = CurvedAnimation(
        parent: _animationController,
        curve: curve,
      );
    } else {
      _curvedAnimation = null;
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
    _scheduler.dispose();
    widget.controller?.removeListener(_onControllerChanged);
    _animationController.removeStatusListener(_onAnimationStatus);
    _curvedAnimation?.dispose();
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
      // A programmatic show bypasses the scheduler's pointer events, so start
      // the auto-hide countdown explicitly.
      _scheduler.startAutoHide(_scheduleConfig);
    } else {
      _hide();
    }
  }

  // ---------------------------------------------------------------------------
  // Show / hide logic
  // ---------------------------------------------------------------------------

  void _show() {
    if (_isShowing) return;
    if (widget.hideOnEmptyMessage &&
        widget.tooltipBuilder == null &&
        (widget.message == null || widget.message!.isEmpty)) {
      return;
    }

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
    _scheduler.reset();
    _isShowing = false;
    _resolvedDirection = null;
    _arrowCenterOffset = null;
    _visibleInstances.remove(this);
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    widget.controller?.resetShouldShow();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _isShowing = false;
      _resolvedDirection = null;
      _arrowCenterOffset = null;
      _visibleInstances.remove(this);
      _overlayEntry?.remove();
      _overlayEntry?.dispose();
      _overlayEntry = null;
      widget.controller?.resetShouldShow();
      widget.onHide?.call();
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduler show request
  // ---------------------------------------------------------------------------

  /// Handles an `onShow` request from the scheduler. Reconciles the request
  /// against the real render state: if the tooltip is fading out, re-forward
  /// it (the reverse-catch); otherwise show it fresh.
  void _handleShowRequest() {
    if (_isShowing) {
      if (_animationController.status == AnimationStatus.reverse) {
        _animationController.forward();
      }
      return;
    }
    _show();
  }

  // ---------------------------------------------------------------------------
  // Overlay entry
  // ---------------------------------------------------------------------------

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final textDirection = Directionality.of(context);
        final theme = widget.theme;

        // Get target's global position and size.
        final renderBox = this.context.findRenderObject() as RenderBox;
        final targetPosition = renderBox.localToGlobal(Offset.zero);
        final targetRect = targetPosition & renderBox.size;

        return CustomSingleChildLayout(
          delegate: JustTooltipPositionDelegate(
            targetRect: targetRect,
            direction: widget.direction,
            alignment: widget.alignment,
            gap: widget.offset,
            crossAxisOffset: widget.crossAxisOffset,
            screenMargin: widget.screenMargin,
            textDirection: textDirection,
            onDirectionResolved: theme.showArrow
                ? (resolved) {
                    if (_resolvedDirection != resolved) {
                      _resolvedDirection = resolved;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _overlayEntry?.markNeedsBuild();
                      });
                    }
                  }
                : null,
            onArrowCenterResolved: theme.showArrow
                ? (center) {
                    if (_arrowCenterOffset != center) {
                      _arrowCenterOffset = center;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _overlayEntry?.markNeedsBuild();
                      });
                    }
                  }
                : null,
          ),
          child: MouseRegion(
            onEnter: (_) => _scheduler.onTooltipEnter(config: _scheduleConfig),
            onExit: (_) => _scheduler.onTooltipExit(
              isShown: _isShowing,
              config: _scheduleConfig,
            ),
            child: _buildAnimatedChild(
              child: JustTooltipOverlay(
                direction: _resolvedDirection ?? widget.direction,
                alignment: widget.alignment,
                theme: theme,
                message: widget.message,
                tooltipBuilder: widget.tooltipBuilder,
                textDirection: textDirection,
                arrowCenterOverride: _arrowCenterOffset,
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Animation builder
  // ---------------------------------------------------------------------------

  Widget _buildAnimatedChild({required Widget child}) {
    final anim = _animation;

    switch (widget.animation) {
      case TooltipAnimation.none:
        return child;
      case TooltipAnimation.fade:
        return _wrapFade(anim, child);
      case TooltipAnimation.scale:
        return _wrapScale(anim, child);
      case TooltipAnimation.slide:
        return SlideTransition(
          position: _slideOffset(anim),
          child: child,
        );
      case TooltipAnimation.fadeScale:
        return _wrapFade(anim, _wrapScale(anim, child));
      case TooltipAnimation.fadeSlide:
        return _wrapFade(
          anim,
          SlideTransition(position: _slideOffset(anim), child: child),
        );
      case TooltipAnimation.rotation:
        return _wrapFade(
          anim,
          RotationTransition(
            turns: Tween<double>(begin: widget.rotationBegin, end: 0.0)
                .animate(anim),
            child: child,
          ),
        );
    }
  }

  Widget _wrapFade(Animation<double> anim, Widget child) {
    if (widget.fadeBegin == 0.0) {
      return FadeTransition(opacity: anim, child: child);
    }
    return FadeTransition(
      opacity: Tween<double>(begin: widget.fadeBegin, end: 1.0).animate(anim),
      child: child,
    );
  }

  Widget _wrapScale(Animation<double> anim, Widget child) {
    if (widget.scaleBegin == 0.0) {
      return ScaleTransition(scale: anim, child: child);
    }
    return ScaleTransition(
      scale: Tween<double>(begin: widget.scaleBegin, end: 1.0).animate(anim),
      child: child,
    );
  }

  Animation<Offset> _slideOffset(Animation<double> anim) {
    final d = widget.slideOffset;
    final Offset begin;
    switch (widget.direction) {
      case TooltipDirection.top:
        begin = Offset(0, -d);
      case TooltipDirection.bottom:
        begin = Offset(0, d);
      case TooltipDirection.left:
        begin = Offset(-d, 0);
      case TooltipDirection.right:
        begin = Offset(d, 0);
    }
    return Tween<Offset>(begin: begin, end: Offset.zero).animate(anim);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (widget.enableHover) {
      child = MouseRegion(
        onEnter: (_) =>
            _scheduler.onChildEnter(isShown: _isShowing, config: _scheduleConfig),
        onExit: (_) =>
            _scheduler.onChildExit(isShown: _isShowing, config: _scheduleConfig),
        child: child,
      );
    }

    if (widget.enableTap) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            _scheduler.onTap(isShown: _isShowing, config: _scheduleConfig),
        child: child,
      );
    }

    return child;
  }
}
