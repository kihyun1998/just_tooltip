import 'dart:async';

import 'package:flutter/material.dart';

import 'enums.dart';
import 'just_tooltip_controller.dart';
import 'just_tooltip_overlay.dart';
import 'just_tooltip_theme.dart';
import 'tooltip_position_utils.dart';
import 'tooltip_registry.dart';
import 'tooltip_transitions.dart';
import 'tooltip_visibility_scheduler.dart';

/// App-global registry used when a [JustTooltip] is not given an explicit one,
/// preserving the "only one tooltip visible at a time" default.
final TooltipRegistry _sharedRegistry = TooltipRegistry();

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
    this.anchor = TooltipAnchor.child,
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
    this.registry,
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

  /// What the tooltip is positioned against — the [child]'s rect (default) or
  /// the pointer.
  ///
  /// With [TooltipAnchor.pointer] the child remains the hover region while the
  /// tooltip appears beside the cursor. Use it when the child is much wider
  /// than the area the pointer occupies — a table row, a wide card — where the
  /// child's centre is nowhere near where the user is looking.
  ///
  /// The anchor is captured when the tooltip is shown and does not follow the
  /// pointer afterwards, so [interactive] tooltips stay reachable.
  final TooltipAnchor anchor;

  /// The alignment of the tooltip along the cross-axis of [direction].
  ///
  /// With [TooltipAnchor.pointer] the anchor is a point, so there are no target
  /// edges to align to. Alignment then says which of the *tooltip's* own edges
  /// lands on the pointer: [TooltipAlignment.start] extends the tooltip away
  /// from the pointer's leading side, [TooltipAlignment.end] from its trailing
  /// side, and [TooltipAlignment.center] centres it on the pointer.
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

  /// The registry that enforces "one tooltip visible at a time".
  ///
  /// Defaults to an app-global shared registry, so showing any tooltip
  /// dismisses any other. Pass an explicit [TooltipRegistry] to scope a group
  /// of tooltips independently (or to isolate a test).
  final TooltipRegistry? registry;

  @override
  State<JustTooltip> createState() => _JustTooltipState();
}

/// Exposes a [JustTooltip]'s state to the tooltips nested inside its child, so
/// a descendant can suppress its ancestors while the pointer is inside it.
class _TooltipScope extends InheritedWidget {
  const _TooltipScope({required this.state, required super.child});

  final _JustTooltipState state;

  @override
  bool updateShouldNotify(_TooltipScope oldWidget) => state != oldWidget.state;
}

class _JustTooltipState extends State<JustTooltip>
    with SingleTickerProviderStateMixin
    implements JustTooltipControllerTarget, DismissibleTooltip {
  TooltipRegistry get _registry => widget.registry ?? _sharedRegistry;

  /// The nearest enclosing [JustTooltip], if any. Walking this chain reaches
  /// every ancestor tooltip.
  _JustTooltipState? _ancestor;

  /// The descendant tooltips currently holding the pointer. Non-empty means
  /// this tooltip is nested-suppressed and must not show.
  final Set<_JustTooltipState> _suppressors = {};

  bool get _suppressed => _suppressors.isNotEmpty;

  /// Whether the pointer is within this tooltip's child. Retained because
  /// [MouseRegion] reports edges only: an ancestor released by a descendant
  /// never receives a second `onEnter`.
  bool _pointerInside = false;

  /// The pointer's last known global position, or `null` when no pointer has
  /// been seen. The positional sibling of [_pointerInside].
  Offset? _anchorCandidate;

  /// [_anchorCandidate] as captured when the tooltip was shown. A tooltip that
  /// chased the pointer could never be entered, so [JustTooltip.interactive]
  /// depends on this not moving.
  Offset? _frozenAnchor;

  /// The last hover intent handed to the scheduler — `_pointerInside`, gated by
  /// [JustTooltip.enableHover] and nesting suppression. Only its *transitions*
  /// reach the scheduler.
  bool _hoverIntent = false;

  bool _reconcileQueued = false;

  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  CurvedAnimation? _curvedAnimation;
  late final TooltipVisibilityScheduler _scheduler;
  bool _isShowing = false;

  /// The actual direction after auto-flip, used to orient the arrow.
  TooltipDirection? _resolvedDirection;

  /// The arrow's cross-axis position for [TooltipAlignment.targetCenter].
  double? _arrowCenterOffset;

  /// The target the visible overlay was last built against.
  Rect? _builtTargetRect;

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
    final controller = widget.controller;
    if (controller != null && controller.attach(this)) {
      _applyQueuedShowAfterLayout();
    }
  }

  /// Applies a controller's queued show once the widget has laid out (the
  /// overlay needs the target's [RenderBox]). Guarded against a same-frame
  /// dispose.
  void _applyQueuedShowAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTooltip();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A read, not a dependency: the enclosing tooltip's identity is stable, and
    // rebuilding this subtree when it changes would serve no purpose.
    _ancestor = context.getInheritedWidgetOfExactType<_TooltipScope>()?.state;
  }

  // ---------------------------------------------------------------------------
  // Nesting suppression — the innermost tooltip under the pointer wins
  // ---------------------------------------------------------------------------

  /// Suppresses every ancestor tooltip. Walks the whole chain rather than
  /// forwarding through the nearest ancestor: an intermediate tooltip with
  /// `enableHover: false` has no [MouseRegion] to forward with, and would
  /// break the chain.
  void _claimAncestors() {
    for (var a = _ancestor; a != null; a = a._ancestor) {
      a._addSuppressor(this);
    }
  }

  void _releaseAncestors() {
    for (var a = _ancestor; a != null; a = a._ancestor) {
      a._removeSuppressor(this);
    }
  }

  void _addSuppressor(_JustTooltipState suppressor) {
    if (_suppressors.add(suppressor)) _scheduleReconcile();
  }

  void _removeSuppressor(_JustTooltipState suppressor) {
    if (_suppressors.remove(suppressor)) _scheduleReconcile();
  }

  // ---------------------------------------------------------------------------
  // Hover intent — derived from pointer facts, not from MouseRegion edges
  // ---------------------------------------------------------------------------

  /// Coalesces the reconcile to the end of the current pointer-event batch.
  ///
  /// Flutter dispatches every exit, then every enter, synchronously for one
  /// pointer move. Reading the *net* state afterwards makes hover intent
  /// independent of that dispatch order — an ancestor released by a leaving
  /// descendant sees its own exit in the same batch and never flashes.
  void _scheduleReconcile() {
    if (_reconcileQueued) return;
    _reconcileQueued = true;
    scheduleMicrotask(_reconcileHoverIntent);
  }

  /// Runs a queued reconcile now.
  ///
  /// The tooltip body's `onEnter` cancels the hover bridge that the child's
  /// `onExit` arms — and Flutter delivers both in one batch. Since the child's
  /// exit is deferred to a microtask, the cancel would otherwise run before
  /// there is anything to cancel, and the bridge would hide an interactive
  /// tooltip the cursor is sitting on.
  void _flushReconcile() {
    if (_reconcileQueued) _reconcileHoverIntent();
  }

  void _reconcileHoverIntent() {
    _reconcileQueued = false;
    if (!mounted) return;

    final wants = widget.enableHover && _pointerInside && !_suppressed;
    if (wants == _hoverIntent) return;
    _hoverIntent = wants;

    if (wants) {
      _scheduler.onChildEnter(isShown: _isShowing, config: _scheduleConfig);
    } else if (_suppressed) {
      // Suppression is not a hover exit: it bypasses the scheduler's hide
      // policy (a `showDuration` tooltip refuses to hide on child exit) and
      // drops the tooltip immediately.
      _scheduler.reset();
      _hide();
    } else {
      _scheduler.onChildExit(isShown: _isShowing, config: _scheduleConfig);
    }
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
      oldWidget.controller?.detach(this);
      final controller = widget.controller;
      if (controller != null && controller.attach(this)) {
        _applyQueuedShowAfterLayout();
      }
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
    _releaseAncestors();
    _scheduler.dispose();
    widget.controller?.detach(this);
    _animationController.removeStatusListener(_onAnimationStatus);
    _curvedAnimation?.dispose();
    _animationController.dispose();
    _hideImmediate();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // JustTooltipControllerTarget — commands from an attached controller
  // ---------------------------------------------------------------------------

  @override
  void showTooltip() {
    _show();
    // A programmatic show bypasses the scheduler's pointer events, so start
    // the auto-hide countdown explicitly.
    _scheduler.startAutoHide(_scheduleConfig);
  }

  @override
  void hideTooltip() => _hide();

  @override
  void toggleTooltip() {
    if (_isShowing) {
      _hide();
    } else {
      showTooltip();
    }
  }

  @override
  bool get isTooltipShowing => _isShowing;

  // ---------------------------------------------------------------------------
  // DismissibleTooltip — dismissed by the registry when another tooltip shows
  // ---------------------------------------------------------------------------

  @override
  void dismissTooltip() => _hide();

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

    _isShowing = true;
    _frozenAnchor =
        widget.anchor == TooltipAnchor.pointer ? _anchorCandidate : null;
    // Register (and dismiss any other visible tooltip in the same registry).
    _registry.show(this);

    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _trackTarget();
    _animationController.forward();
    widget.onShow?.call();
  }

  void _hide() {
    if (!_isShowing) return;
    _animationController.reverse();
  }

  void _hideImmediate() {
    _scheduler.reset();
    _pointerInside = false;
    _hoverIntent = false;
    _isShowing = false;
    _frozenAnchor = null;
    _resolvedDirection = null;
    _arrowCenterOffset = null;
    _registry.remove(this);
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _isShowing = false;
      _frozenAnchor = null;
      _resolvedDirection = null;
      _arrowCenterOffset = null;
      _registry.remove(this);
      _overlayEntry?.remove();
      _overlayEntry?.dispose();
      _overlayEntry = null;
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

  /// The intersection of every clip an ancestor applies to [target], expressed
  /// in [overlayBox]'s coordinate space. `null` when nothing clips it.
  ///
  /// [RenderObject.describeApproximatePaintClip] returns each clip in *its own*
  /// coordinate space, so every one is transformed into the overlay's before
  /// being intersected — the same walk Flutter's semantics phase performs.
  ///
  /// Each step passes the parent's actual child, not [target]: a viewport
  /// narrows the parameter to [RenderSliver] and would reject a [RenderBox].
  ///
  /// A viewport reports a clip whenever its `clipBehavior` is not [Clip.none],
  /// whether or not anything overflows, so most scrolled children land here.
  static Rect? _ancestorClip(RenderBox target, RenderBox overlayBox) {
    Rect? clip;
    RenderObject child = target;
    RenderObject? parent = child.parent;

    while (parent != null && parent != overlayBox) {
      final local = parent.describeApproximatePaintClip(child);
      if (local != null) {
        final inOverlay = MatrixUtils.transformRect(
          parent.getTransformTo(overlayBox),
          local,
        );
        clip = clip == null ? inOverlay : clip.intersect(inOverlay);
      }
      child = parent;
      parent = child.parent;
    }
    return clip;
  }

  /// The rect the tooltip is positioned against, in [overlayBox]'s coordinate
  /// space (see [JustTooltipPositionDelegate.targetRect]).
  ///
  /// A pointer anchor is a degenerate rect at the cursor. The delegate needs no
  /// special case: direction flipping, `screenMargin` clamping and the arrow
  /// all work against a zero-size target.
  ///
  /// Otherwise the target is the part of the child that is actually visible.
  /// Aiming at the child's whole rect points the tooltip at a spot the user
  /// cannot see whenever an ancestor clips the child — a row wider than its
  /// horizontal scroll viewport, say. `screenMargin` does not save it: that
  /// confines the tooltip to the [Overlay], usually the whole app, which the
  /// off-screen anchor happily satisfies.
  ///
  /// When the child is clipped away entirely — reachable only through
  /// [JustTooltipController.show], since a hovering pointer proves a visible
  /// part exists — the anchor is the child's centre clamped into the clip. It
  /// pins the tooltip to the edge the child lies beyond, which at least points
  /// the right way. Refusing to show would be the inconsistent choice: a
  /// tooltip already on screen stays put when its child scrolls out of sight,
  /// so the same state is legal a frame later.
  Rect _resolveTargetRect(RenderBox overlayBox) =>
      _resolveTarget(overlayBox).target;

  /// [_resolveTargetRect], plus whether the child is clipped away *entirely*.
  ///
  /// The two callers want different things from that fact. Showing clamps to
  /// the clip edge, since refusing would need a return value nobody asked for.
  /// Tracking hides: a tooltip that pointed at something now points at nothing,
  /// and hiding is already in this widget's vocabulary.
  ({Rect target, bool clippedAway}) _resolveTarget(RenderBox overlayBox) {
    final anchor = _frozenAnchor;
    if (anchor != null) {
      return (
        target: Rect.fromCenter(
          center: overlayBox.globalToLocal(anchor),
          width: 0,
          height: 0,
        ),
        clippedAway: false,
      );
    }

    final renderBox = context.findRenderObject() as RenderBox;
    // Not `localToGlobal(Offset.zero) & size`: that walks the ancestors'
    // transforms for the origin but appends the untransformed local size, so a
    // Transform.scale between the child and the Overlay yields a target of the
    // wrong extent.
    final rect = MatrixUtils.transformRect(
      renderBox.getTransformTo(overlayBox),
      Offset.zero & renderBox.size,
    );

    final clip = _ancestorClip(renderBox, overlayBox);
    if (clip == null) return (target: rect, clippedAway: false);

    final visible = rect.intersect(clip);
    if (!visible.isEmpty) return (target: visible, clippedAway: false);

    return (
      target: Rect.fromCenter(
        center: Offset(
          rect.center.dx.clamp(clip.left, clip.right),
          rect.center.dy.clamp(clip.top, clip.bottom),
        ),
        width: 0,
        height: 0,
      ),
      clippedAway: true,
    );
  }

  /// Re-aims the visible overlay whenever its child moves.
  ///
  /// The target is resolved once per build, so without this a tooltip stays
  /// where its child used to be — after a scroll, a resize, a layout animation,
  /// or an insertion above it. Subscribing to `ScrollNotification` would catch
  /// only the first of those.
  ///
  /// A post-frame callback does not schedule a frame of its own, so this idles
  /// until something else moves the child, and re-arms itself only while an
  /// overlay is up. The registry allows one visible tooltip at a time, which
  /// bounds the work to a single rect per frame.
  void _trackTarget() {
    final entry = _overlayEntry;
    if (entry == null || !mounted) return;

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final childBox = context.findRenderObject() as RenderBox?;
    if (overlayBox != null && childBox != null && childBox.hasSize) {
      final resolved = _resolveTarget(overlayBox);
      if (resolved.clippedAway) {
        // Nothing left to point at. Stop tracking; the fade-out removes the
        // entry, and _show() re-arms this if the tooltip returns.
        _hide();
        return;
      }
      if (resolved.target != _builtTargetRect) {
        _builtTargetRect = resolved.target;
        entry.markNeedsBuild();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _trackTarget());
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final textDirection = Directionality.of(context);
        final theme = widget.theme;

        // The delegate lays the tooltip out inside this Overlay, so the target
        // must be expressed in the Overlay's coordinate space — not the
        // window's. The two coincide only when the Overlay fills the window
        // from its origin.
        final overlayBox =
            Overlay.of(this.context).context.findRenderObject() as RenderBox;
        final targetRect = _resolveTargetRect(overlayBox);
        _builtTargetRect = targetRect;

        return CustomSingleChildLayout(
          delegate: JustTooltipPositionDelegate(
            targetRect: targetRect,
            direction: widget.direction,
            alignment: widget.alignment,
            gap: widget.offset,
            crossAxisOffset: widget.crossAxisOffset,
            screenMargin: widget.screenMargin,
            textDirection: textDirection,
            // Always track the resolved (post-flip) direction — the arrow uses
            // it to orient, and slide animations use it to enter from the
            // correct side.
            onDirectionResolved: (resolved) {
              if (_resolvedDirection != resolved) {
                _resolvedDirection = resolved;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _overlayEntry?.markNeedsBuild();
                });
              }
            },
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
            onEnter: (_) {
              _flushReconcile();
              _scheduler.onTooltipEnter(config: _scheduleConfig);
            },
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
    return TooltipTransitions.build(
      animation: _animation,
      spec: TooltipTransitionSpec(
        type: widget.animation,
        fadeBegin: widget.fadeBegin,
        scaleBegin: widget.scaleBegin,
        slideOffset: widget.slideOffset,
        rotationBegin: widget.rotationBegin,
        direction: _resolvedDirection ?? widget.direction,
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget child = _TooltipScope(state: this, child: widget.child);

    if (widget.enableHover) {
      child = MouseRegion(
        onEnter: (event) {
          _pointerInside = true;
          _anchorCandidate = event.position;
          _claimAncestors();
          _scheduleReconcile();
        },
        onHover: (event) => _anchorCandidate = event.position,
        onExit: (_) {
          _pointerInside = false;
          // The pointer's position must not outlive the pointer, or a later
          // programmatic show would anchor at a cursor that has gone.
          _anchorCandidate = null;
          _releaseAncestors();
          _scheduleReconcile();
        },
        child: child,
      );
    }

    if (widget.enableTap) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A touch fires no MouseRegion callbacks, so the tap-down is the only
        // place a tap-triggered tooltip can learn where the pointer is. It
        // always precedes onTap.
        onTapDown: (details) => _anchorCandidate = details.globalPosition,
        onTap: () =>
            _scheduler.onTap(isShown: _isShowing, config: _scheduleConfig),
        child: child,
      );
    }

    return child;
  }
}
