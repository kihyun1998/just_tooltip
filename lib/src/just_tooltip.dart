import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
    this.tap,
    @Deprecated(
      'Use tap: TooltipTap.claim instead. '
      'This feature was deprecated after v0.4.4.',
    )
    this.enableTap = false,
    this.enableHover = true,
    this.enableFocus = false,
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
    this.semanticsTooltip,
    this.excludeFromSemantics = false,
    this.onShow,
    this.onHide,
    this.registry,
  }) : assert(
         message != null || tooltipBuilder != null,
         'Either message or tooltipBuilder must be provided.',
       ),
       assert(
         tap == null || !enableTap,
         'Pass tap or the deprecated enableTap, not both.',
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
  ///
  /// A tooltip already on screen is rebuilt whenever this widget updates, so
  /// the builder re-runs and its content follows.
  final WidgetBuilder? tooltipBuilder;

  /// The direction in which the tooltip appears relative to [child].
  ///
  /// If there is not enough space in this direction, the tooltip automatically
  /// flips to the opposite side.
  final TooltipDirection direction;

  /// What the tooltip is positioned against — the visible part of the [child]'s
  /// rect (default) or the pointer.
  ///
  /// With [TooltipAnchor.pointer] the child remains the hover region while the
  /// tooltip appears beside the cursor. Use it when the child is much wider
  /// than the area the pointer occupies — a table row, a wide card — where the
  /// child's visible centre is the scroll viewport's centre, not where the user
  /// is looking.
  ///
  /// The anchor is captured when the tooltip is shown and does not follow the
  /// pointer afterwards, so [interactive] tooltips stay reachable.
  ///
  /// A [TooltipAnchor.child] tooltip re-aims whenever its child moves — a
  /// scroll, a resize, a layout animation — and hides once the child is clipped
  /// out of sight. A [TooltipAnchor.pointer] one does not: its anchor is a
  /// point at the cursor, and a pointer inside the child proves the child shows.
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
  /// For [TooltipAlignment.start] and [TooltipAlignment.end], and their
  /// [TooltipAlignment.startTargetCenter] and [TooltipAlignment.endTargetCenter]
  /// variants, a positive value moves the tooltip toward center (inward from
  /// the aligned edge).
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

  /// How a tap on the child toggles the tooltip.
  ///
  /// When null, [enableTap] decides: `true` is [TooltipTap.claim], `false` is
  /// [TooltipTap.none]. Passing both is an assertion error.
  final TooltipTap? tap;

  /// Whether tapping the child toggles the tooltip, claiming the tap.
  @Deprecated(
    'Use tap: TooltipTap.claim instead. '
    'This feature was deprecated after v0.4.4.',
  )
  final bool enableTap;

  /// Whether hovering over the child shows the tooltip.
  final bool enableHover;

  /// Whether keyboard focus inside the child shows the tooltip.
  ///
  /// Only focus that arrives by a key press counts — Tab, an arrow key — so a
  /// click, a tap or a `requestFocus()` that focuses the [child] does not open
  /// its tooltip. Focus may move on into the tooltip's own content and keep it
  /// open. It shows and hides as a hover does: after [waitDuration], only the
  /// innermost nested tooltip, and only with content; losing focus hides it.
  /// A pointer hovering an enclosing tooltip's child elsewhere wins over a
  /// nested tooltip's focus.
  ///
  /// Escape dismisses a shown tooltip whatever this is set to.
  final bool enableFocus;

  /// Whether the tooltip stays visible when the cursor moves over it.
  ///
  /// When `true` (default), the user can hover over the tooltip content
  /// without it disappearing. This is useful for tooltips with selectable
  /// text or interactive content. The cursor may cross freely in either
  /// direction — onto the tooltip and back onto the child — without the
  /// tooltip hiding.
  ///
  /// When `false`, the tooltip will begin to hide as soon as the cursor
  /// leaves the child widget, even if it enters the tooltip area. The tooltip
  /// body is then transparent to the pointer: hovers and taps pass through it
  /// to whatever lies beneath, so a body laid over its own child does not take
  /// the pointer from it, and content inside the body cannot be clicked.
  ///
  /// `false` leaves WCAG 2.1 SC 1.4.13's *hoverable* requirement: the pointer
  /// cannot move onto the tooltip without it disappearing.
  final bool interactive;

  /// The delay before the tooltip appears after hovering.
  ///
  /// If `null` (default), the tooltip appears immediately on hover.
  final Duration? waitDuration;

  /// The duration the tooltip remains visible before automatically hiding.
  ///
  /// If `null` (default), the tooltip stays visible until the user moves
  /// the cursor away (hover) or taps again (tap).
  ///
  /// A value leaves WCAG 2.1 SC 1.4.13's *persistent* requirement: the
  /// tooltip disappears while its trigger is still there.
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
  /// A tooltip suppressed this way does not suppress *its* ancestors either:
  /// having nothing to draw, it cannot take an enclosing tooltip's place. So
  /// hovering an empty-message tooltip nested inside another shows the
  /// enclosing one, rather than nothing at all.
  ///
  /// [message] is data, so it may become empty — or stop being empty — while
  /// the pointer already rests on the child. The tooltip follows: it hides at
  /// once, or appears, without waiting for the pointer to leave and return.
  ///
  /// A tooltip that is already on screen when its [message] empties hides too,
  /// however it was opened — including by [JustTooltipController.show], which
  /// no pointer exit will ever undo.
  ///
  /// This has no effect when [tooltipBuilder] is used.
  final bool hideOnEmptyMessage;

  /// The text a screen reader hears for this tooltip, in place of [message].
  ///
  /// A screen reader hears the tooltip on the [child]'s own semantics node,
  /// without opening it, and showing the tooltip announces the text once
  /// (honoured by TalkBack on Android). The text is this value when non-null,
  /// otherwise [message]; a [tooltipBuilder] tooltip has no text of its own,
  /// so it is heard only through this value.
  ///
  /// The tooltip is heard only when it would show — a tooltip with nothing to
  /// draw is not heard either — and only when the text is non-empty. An empty
  /// bubble (`hideOnEmptyMessage: false`) is shown and not heard. This value
  /// never makes a tooltip show.
  ///
  /// Nested, only the innermost heard tooltip is heard: a tooltip is silent
  /// while any tooltip inside its [child] is heard.
  final String? semanticsTooltip;

  /// Whether a screen reader is kept from hearing this tooltip.
  ///
  /// Set it when the [child] already says what the tooltip says, so the text
  /// is not read twice, and on a tooltip a screen reader cannot reach — under
  /// [ExcludeSemantics], [Offstage] or a hidden [IndexedStack] child — which
  /// would still silence the tooltips around it. See [semanticsTooltip].
  final bool excludeFromSemantics;

  /// Called when the tooltip becomes visible.
  final VoidCallback? onShow;

  /// Called when the tooltip becomes hidden.
  final VoidCallback? onHide;

  /// The registry that enforces "one tooltip visible at a time".
  ///
  /// Defaults to an app-global shared registry, so showing any tooltip
  /// dismisses any other. Pass an explicit [TooltipRegistry] to scope a group
  /// of tooltips independently (or to isolate a test).
  ///
  /// Inside another tooltip's [tooltipBuilder] content the default is instead
  /// a registry that host gives its content: showing this tooltip dismisses
  /// the other tooltips in that content, not the host it is drawn in.
  final TooltipRegistry? registry;

  @override
  State<JustTooltip> createState() => _JustTooltipState();
}

/// Exposes a [JustTooltip]'s state to the tooltips nested inside its child, so
/// a descendant can suppress its ancestors while the pointer is inside it.
///
/// A `null` [state] is a scope with no tooltip: what lies below it has no
/// ancestor tooltips.
class _TooltipScope extends InheritedWidget {
  const _TooltipScope({
    required this.state,
    required this.contentRegistry,
    required super.child,
  });

  final _JustTooltipState? state;

  /// The registry of the tooltip content this scope sits in, or `null`
  /// outside any tooltip's content.
  final TooltipRegistry? contentRegistry;

  @override
  bool updateShouldNotify(_TooltipScope oldWidget) =>
      state != oldWidget.state || contentRegistry != oldWidget.contentRegistry;
}

class _JustTooltipState extends State<JustTooltip>
    with SingleTickerProviderStateMixin
    implements JustTooltipControllerTarget, DismissibleTooltip {
  TooltipRegistry get _registry =>
      widget.registry ?? _inheritedContentRegistry ?? _sharedRegistry;

  /// The registry of the tooltip content this tooltip sits in, if any.
  TooltipRegistry? _inheritedContentRegistry;

  /// The registry shared by the tooltips inside this tooltip's own content.
  final TooltipRegistry _contentRegistry = TooltipRegistry();

  /// The nearest enclosing [JustTooltip], if any. Walking this chain reaches
  /// every ancestor tooltip.
  _JustTooltipState? _ancestor;

  /// The descendant tooltips currently holding the pointer. Non-empty means
  /// this tooltip is nested-suppressed and must not show.
  final Set<_JustTooltipState> _suppressors = {};

  /// The descendant tooltips currently holding keyboard focus. They suppress
  /// this tooltip unless the pointer is inside its child.
  final Set<_JustTooltipState> _focusSuppressors = {};

  bool get _suppressed =>
      _suppressors.isNotEmpty ||
      (_focusSuppressors.isNotEmpty && !(widget.enableHover && _pointerInside));

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

  /// Whether the primary focus is within this tooltip — its child or its
  /// content.
  bool get _holdsFocus {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null || !mounted) return false;
    if (focused == context) return true;
    var inside = false;
    focused.visitAncestorElements((element) {
      inside = element == context;
      return !inside;
    });
    return inside;
  }

  /// Whether focus inside this tooltip arrived by a key press. Kept while
  /// focus moves around inside it; cleared once focus leaves.
  bool _keyboardFocusInside = false;

  /// Whether a trigger this tooltip listens to is inside its child.
  bool get _triggerInside =>
      (widget.enableHover && _pointerInside) ||
      (widget.enableFocus && _keyboardFocusInside);

  /// Whether Escape closed this tooltip while its trigger was inside. Cleared
  /// once no trigger is inside.
  bool _dismissed = false;

  /// The last show intent handed to the scheduler — [_triggerInside], gated by
  /// nesting suppression, content and [_dismissed]. Only its *transitions*
  /// reach the scheduler.
  bool _showIntent = false;

  bool _reconcileQueued = false;

  final OverlayPortalController _overlayController = OverlayPortalController();
  late AnimationController _animationController;
  CurvedAnimation? _curvedAnimation;
  late final TooltipVisibilityScheduler _scheduler;
  bool _isShowing = false;

  /// The actual direction after auto-flip, used to orient the arrow.
  TooltipDirection? _resolvedDirection;

  /// The arrow's cross-axis position for [TooltipAlignment.targetCenter].
  double? _arrowCenterOffset;

  /// Whether this tooltip has ever resolved a visible target while shown.
  ///
  /// Hiding on a clipped-away child is a *transition* — the thing we pointed at
  /// disappeared — not a state. A `controller.show()` against a child that was
  /// already out of sight asked for a tooltip explicitly; it anchors at the clip
  /// edge and waits for the child instead.
  bool _sawVisibleTarget = false;

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
    if (widget.enableFocus) FocusManager.instance.addListener(_onFocusChanged);
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
    _readScope();
  }

  /// Reads the enclosing tooltip and content registry, releases the old
  /// ancestor chain from this tooltip's suppression when it changed, and
  /// registers on the new chain as heard.
  void _readScope() {
    // A read, not a dependency: the enclosing tooltip's identity is stable, and
    // rebuilding this subtree when it changes would serve no purpose.
    final scope = context.getInheritedWidgetOfExactType<_TooltipScope>();
    if (scope?.state != _ancestor) _releaseAncestors();
    _ancestor = scope?.state;
    _inheritedContentRegistry = scope?.contentRegistry;
    _syncHeard();
  }

  /// Every enclosing tooltip, nearest first.
  Iterable<_JustTooltipState> get _ancestors sync* {
    for (var a = _ancestor; a != null; a = a._ancestor) {
      yield a;
    }
  }

  // ---------------------------------------------------------------------------
  // Nesting suppression — the innermost tooltip under the pointer wins
  // ---------------------------------------------------------------------------

  /// Whether this tooltip has anything to draw.
  ///
  /// The one fact that decides both whether this tooltip may show and whether
  /// it may suppress its ancestors. Keeping it derived — rather than judged
  /// once inside [_show] — is what lets a tooltip pick up content that arrives
  /// while the pointer already rests on it, and let go of an ancestor when its
  /// content leaves.
  bool get _hasContent => _hasContentOf(widget);

  static bool _hasContentOf(JustTooltip w) =>
      w.tooltipBuilder != null ||
      !w.hideOnEmptyMessage ||
      (w.message?.isNotEmpty ?? false);

  /// Brings the ancestors' view of this tooltip in line with the facts.
  ///
  /// Called synchronously from the pointer edges and from [didUpdateWidget].
  /// Deferring it to [_scheduleReconcile]'s microtask would let an ancestor
  /// reconcile before its descendant has claimed it — and an ancestor with no
  /// `waitDuration` would flash into view on its way to being suppressed.
  void _syncSuppression() {
    _claimAncestors(
      pointer: _pointerInside && _hasContent,
      focus: widget.enableFocus && _keyboardFocusInside && _hasContent,
    );
  }

  /// Suppresses every ancestor tooltip. Walks the whole chain rather than
  /// forwarding through the nearest ancestor: an intermediate tooltip with
  /// `enableHover: false` has no [MouseRegion] to forward with, and would
  /// break the chain.
  ///
  /// Only a tooltip that [_hasContent] may claim: one that will never draw
  /// would take the screen from an ancestor and leave nothing in its place,
  /// so the pointer would sit over a region where no tooltip appears at all.
  void _claimAncestors({required bool pointer, required bool focus}) {
    for (final a in _ancestors) {
      a._setSuppressor(a._suppressors, this, claimed: pointer);
      a._setSuppressor(a._focusSuppressors, this, claimed: focus);
    }
  }

  void _releaseAncestors() => _claimAncestors(pointer: false, focus: false);

  void _setSuppressor(
    Set<_JustTooltipState> suppressors,
    _JustTooltipState suppressor, {
    required bool claimed,
  }) {
    final changed = claimed
        ? suppressors.add(suppressor)
        : suppressors.remove(suppressor);
    if (changed) _scheduleReconcile();
  }

  // ---------------------------------------------------------------------------
  // Semantic tooltip — what a screen reader hears, innermost only
  // ---------------------------------------------------------------------------

  /// The descendant tooltips that are heard. Non-empty means this tooltip
  /// yields its text to them.
  final Set<_JustTooltipState> _heardDescendants = {};

  /// The text the child's semantics node carries: this tooltip's own text,
  /// or `null` while it is not heard or yields to a descendant.
  final ValueNotifier<String?> _heardText = ValueNotifier(null);

  /// This tooltip's own text for a screen reader, or `null` when it is not
  /// heard on its own terms.
  String? get _semanticText {
    final w = widget;
    if (w.excludeFromSemantics || !_hasContent) return null;
    final text =
        w.semanticsTooltip ?? (w.tooltipBuilder == null ? w.message : null);
    return (text?.isNotEmpty ?? false) ? text : null;
  }

  /// Brings the ancestors' view of whether this tooltip is heard, and the
  /// text on its own child, in line with the widget.
  void _syncHeard() {
    if (_semanticText != null) {
      for (final a in _ancestors) {
        a._addHeardDescendant(this);
      }
    } else {
      _releaseHeard();
    }
    _updateHeardText();
  }

  void _releaseHeard() {
    for (final a in _ancestors) {
      a._removeHeardDescendant(this);
    }
  }

  void _addHeardDescendant(_JustTooltipState descendant) {
    if (_heardDescendants.add(descendant)) _updateHeardText();
  }

  void _removeHeardDescendant(_JustTooltipState descendant) {
    if (_heardDescendants.remove(descendant)) _updateHeardText();
  }

  void _updateHeardText() {
    _heardText.value = _heardDescendants.isEmpty ? _semanticText : null;
  }

  // ---------------------------------------------------------------------------
  // Show intent — derived from trigger facts, not from their edges
  // ---------------------------------------------------------------------------

  /// Coalesces the reconcile to the end of the current pointer-event batch.
  ///
  /// Flutter dispatches every exit, then every enter, synchronously for one
  /// pointer move. Reading the *net* state afterwards makes show intent
  /// independent of that dispatch order — an ancestor released by a leaving
  /// descendant sees its own exit in the same batch and never flashes.
  void _scheduleReconcile() {
    if (_reconcileQueued) return;
    _reconcileQueued = true;
    scheduleMicrotask(_reconcileShowIntent);
  }

  /// Runs a queued reconcile now.
  ///
  /// The tooltip body's `onEnter` cancels the hover bridge that the child's
  /// `onExit` arms — and Flutter delivers both in one batch. Since the child's
  /// exit is deferred to a microtask, the cancel would otherwise run before
  /// there is anything to cancel, and the bridge would hide an interactive
  /// tooltip the cursor is sitting on.
  void _flushReconcile() {
    if (_reconcileQueued) _reconcileShowIntent();
  }

  void _reconcileShowIntent() {
    _reconcileQueued = false;
    if (!mounted) return;

    final triggered = _triggerInside;
    if (!triggered) _dismissed = false;
    final wants = triggered && !_suppressed && _hasContent && !_dismissed;
    _setPending(wants && !_isShowing);
    if (wants == _showIntent) return;
    _showIntent = wants;

    if (wants) {
      _scheduler.onChildEnter(isShown: _isShowing, config: _scheduleConfig);
    } else if (_suppressed || !_hasContent) {
      // Neither is a hover exit: both bypass the scheduler's hide policy (a
      // `showDuration` tooltip refuses to hide on child exit) and drop the
      // tooltip immediately. Losing content while shown would otherwise leave
      // the old message on screen for the rest of the `showDuration`.
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
    _syncHeard();
    // Content is data, so it can arrive or leave under a pointer that never
    // moves — and a still pointer sends no MouseRegion edge to re-derive from.
    if (_hasContentOf(oldWidget) != _hasContent) {
      _syncSuppression();
      if (!_hasContent && _isShowing) {
        // Not routed through _reconcileShowIntent: a tooltip shown by its
        // controller never had show intent, so that function returns early
        // and the tooltip would survive with nothing to draw. _show() refuses
        // to open without content; closing owes it the same rule, whoever
        // opened it.
        //
        // No _scheduler.reset() here, unlike the hide branch in
        // _reconcileShowIntent. That branch also owns a pending hover-show
        // timer; this one cannot. The only timer a programmatic show arms is
        // the auto-hide, and every show path re-arms it through
        // startAutoHide(), which cancels the previous one — so a stale timer
        // can only fire while nothing is showing, where _hide() ignores it.
        _hide();
      }
      _scheduleReconcile();
    }
    if (oldWidget.enableFocus != widget.enableFocus) {
      if (widget.enableFocus) {
        FocusManager.instance.addListener(_onFocusChanged);
      } else {
        FocusManager.instance.removeListener(_onFocusChanged);
        _keyboardFocusInside = false;
      }
    }
    if (oldWidget.enableFocus != widget.enableFocus ||
        oldWidget.enableHover != widget.enableHover) {
      _syncSuppression();
      _scheduleReconcile();
    }
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
  void activate() {
    super.activate();
    _readScope();
    _syncSuppression();
    _scheduleReconcile();
  }

  @override
  void deactivate() {
    _releaseHeard();
    // Immediately remove overlay when this widget is removed from the tree
    // (e.g., on route change).
    _hideImmediate();
    super.deactivate();
  }

  @override
  void dispose() {
    if (widget.enableFocus) {
      FocusManager.instance.removeListener(_onFocusChanged);
    }
    _setPending(false);
    _evicted.remove(this);
    _releaseAncestors();
    _releaseHeard();
    _heardText.dispose();
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
  void dismissTooltip() {
    // Re-derived when the tooltip that took its place hides.
    _showIntent = false;
    if (_isShowing) _evicted.add(this);
    _hide();
  }

  // ---------------------------------------------------------------------------
  // Show / hide logic
  // ---------------------------------------------------------------------------

  void _show() {
    if (_isShowing) return;
    // Still guarded here: a controller's showTooltip() reaches this without
    // passing a pointer edge.
    if (!_hasContent) return;

    _isShowing = true;
    _sawVisibleTarget = false;
    _frozenAnchor = widget.anchor == TooltipAnchor.pointer
        ? _anchorCandidate
        : null;
    // Register (and dismiss any other visible tooltip in the same registry).
    _registry.show(this);
    _trackShown();
    _setPending(false);
    _evicted.remove(this);

    _overlayController.show();
    _animationController.forward();
    final text = _semanticText;
    if (text != null) SemanticsService.tooltip(text);
    widget.onShow?.call();
  }

  void _hide() {
    if (!_isShowing) return;
    _animationController.reverse();
  }

  void _hideImmediate() {
    _scheduler.reset();
    _pointerInside = false;
    _showIntent = false;
    _dismissed = false;
    _isShowing = false;
    _sawVisibleTarget = false;
    _frozenAnchor = null;
    _resolvedDirection = null;
    _arrowCenterOffset = null;
    _registry.remove(this);
    _untrackShown();
    _setPending(false);
    _hideOverlay();
  }

  /// Takes the content off the [Overlay] — after the current frame when called
  /// during build or layout, and not at all if the tooltip has been shown again
  /// by then.
  void _hideOverlay() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isShowing) _hideOverlay();
      });
      return;
    }
    if (_overlayController.isShowing) _overlayController.hide();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _isShowing = false;
      _sawVisibleTarget = false;
      _frozenAnchor = null;
      _resolvedDirection = null;
      _arrowCenterOffset = null;
      _registry.remove(this);
      _untrackShown();
      _setPending(false);
      // Closed by something other than its trigger leaving — a tap, the
      // auto-hide, a controller: it stays closed until the trigger returns.
      if (_showIntent) {
        _showIntent = false;
        _dismissed = _triggerInside;
      }
      _hideOverlay();
      widget.onHide?.call();
      _reviveEvicted();
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
        _trackShown();
      }
      return;
    }
    _show();
  }

  // ---------------------------------------------------------------------------
  // Overlay
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
  ///
  /// It also reports whether the child is clipped away *entirely*. The two
  /// callers want different things from that fact. Showing clamps to
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

  /// Records whether [resolved] still shows the child, and hides the tooltip
  /// after the current frame once a child it pointed at is clipped away.
  void _noteTarget(({Rect target, bool clippedAway}) resolved) {
    if (!resolved.clippedAway) {
      _sawVisibleTarget = true;
      return;
    }
    if (!_sawVisibleTarget) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isShowing || !_sawVisibleTarget) return;
      final overlayBox =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (overlayBox == null) return;
      if (_resolveTarget(overlayBox).clippedAway) _hide();
    });
  }

  /// The tooltip as [OverlayPortal] draws it on the [Overlay], built in this
  /// widget's context during the [Overlay]'s layout.
  Widget _buildOverlayChild(BuildContext context) {
    final textDirection = Directionality.of(context);
    final theme = widget.theme;

    // The delegate lays the tooltip out inside this Overlay, so the target
    // must be expressed in the Overlay's coordinate space — not the
    // window's. The two coincide only when the Overlay fills the window
    // from its origin.
    final overlayBox =
        Overlay.of(this.context).context.findRenderObject() as RenderBox;
    final resolved = _resolveTarget(overlayBox);
    _noteTarget(resolved);
    final targetRect = resolved.target;

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
            _rebuildAfterLayout();
          }
        },
        onArrowCenterResolved: theme.showArrow
            ? (center) {
                if (_arrowCenterOffset != center) {
                  _arrowCenterOffset = center;
                  _rebuildAfterLayout();
                }
              }
            : null,
      ),
      child: IgnorePointer(
        ignoring: !widget.interactive,
        child: MouseRegion(
          onEnter: (_) {
            _flushReconcile();
            _scheduler.onTooltipEnter(config: _scheduleConfig);
          },
          onExit: (_) {
            // Focus still holds it: leaving the body is not leaving it.
            if (_keyboardFocusInside &&
                widget.enableFocus &&
                widget.showDuration == null) {
              return;
            }
            _scheduler.onTooltipExit(
              isShown: _isShowing,
              config: _scheduleConfig,
            );
          },
          child: _buildAnimatedChild(
            child: JustTooltipOverlay(
              direction: _resolvedDirection ?? widget.direction,
              alignment: resolveTooltipAlignment(
                widget.alignment,
                direction: widget.direction,
                textDirection: textDirection,
              ),
              theme: theme,
              message: widget.message,
              tooltipBuilder: widget.tooltipBuilder,
              arrowCenterOverride: _arrowCenterOffset,
            ),
          ),
        ),
      ),
    );
  }

  /// Rebuilds after the current frame, picking up a value the position delegate
  /// resolved during layout.
  void _rebuildAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
  // Focus trigger and dismissal
  // ---------------------------------------------------------------------------

  void _onFocusChanged() {
    final inside = _holdsFocus;
    final byKey =
        inside &&
        (_keyboardFocusInside ||
            HardwareKeyboard.instance.logicalKeysPressed.any(
              _traversalKeys.contains,
            ));
    if (byKey == _keyboardFocusInside) return;
    _keyboardFocusInside = byKey;
    _syncSuppression();
    _scheduleReconcile();
  }

  /// The keys that move focus: a focus change while one is down arrived by
  /// the keyboard.
  static final Set<LogicalKeyboardKey> _traversalKeys = {
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  /// Every shown tooltip, in the order it was shown.
  static final List<_JustTooltipState> _shown = [];

  /// Tooltips whose show is scheduled but not yet on screen.
  static final Set<_JustTooltipState> _pending = {};

  /// Tooltips the registry hid for another one while their trigger may still
  /// be inside.
  static final Set<_JustTooltipState> _evicted = {};

  /// The shown tooltip whose child or content holds focus, left by this
  /// Escape press to the focus path.
  static _JustTooltipState? _deferred;

  static bool _listening = false;

  /// Listens to the keyboard while a tooltip is shown or about to be.
  static void _syncKeyHandler() {
    final wanted = _shown.isNotEmpty || _pending.isNotEmpty;
    if (wanted == _listening) return;
    _listening = wanted;
    if (wanted) {
      HardwareKeyboard.instance.addHandler(_handleKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_handleKey);
    }
  }

  void _trackShown() {
    _shown
      ..remove(this)
      ..add(this);
    _syncKeyHandler();
  }

  void _untrackShown() {
    if (_shown.remove(this)) _syncKeyHandler();
  }

  void _setPending(bool pending) {
    final changed = pending ? _pending.add(this) : _pending.remove(this);
    if (changed) _syncKeyHandler();
  }

  /// Re-derives the tooltips the registry hid for this one.
  void _reviveEvicted() {
    final others = _evicted.where((tooltip) => tooltip != this).toList();
    _evicted.removeAll(others);
    for (final tooltip in others) {
      if (tooltip.mounted) tooltip._scheduleReconcile();
    }
  }

  /// The tooltip Escape closes: the most recently shown one that is not
  /// already hiding.
  static _JustTooltipState? get _dismissTarget {
    for (final tooltip in _shown.reversed) {
      if (tooltip._isShowing &&
          tooltip._animationController.status != AnimationStatus.reverse) {
        return tooltip;
      }
    }
    return null;
  }

  /// Handles Escape: closes the target, or leaves one that holds focus to
  /// [_DismissTooltipAction] and closes it after the press if that action
  /// did not run; with nothing shown, cancels pending shows.
  static bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    final target = _dismissTarget;
    if (target == null) {
      for (final tooltip in _pending.toList()) {
        tooltip._dismissByUser();
      }
      return false;
    }
    if (target._holdsFocus) {
      _deferred = target;
      scheduleMicrotask(_closeDeferred);
      return false;
    }
    target._dismissByUser();
    return true;
  }

  static void _closeDeferred() {
    final target = _deferred;
    _deferred = null;
    if (target != null && target.mounted) target._dismissByUser();
  }

  void _dismissByUser() {
    _dismissed = _triggerInside;
    _showIntent = false;
    _setPending(false);
    _scheduler.reset();
    _hide();
  }

  late final _DismissTooltipAction _dismissAction = _DismissTooltipAction(this);

  // ---------------------------------------------------------------------------
  // Tap trigger
  // ---------------------------------------------------------------------------

  TooltipTap get _tap =>
      widget.tap ?? (widget.enableTap ? TooltipTap.claim : TooltipTap.none);

  /// Tooltips that reported a tap since the last [_resolveTapBatch].
  static final Set<_JustTooltipState> _tapBatch = {};

  /// Queues this tooltip's toggle for the end of the current pointer event.
  void _toggleFromTap() {
    if (_tapBatch.isEmpty) scheduleMicrotask(_resolveTapBatch);
    _tapBatch.add(this);
  }

  /// Toggles every queued tooltip that is not an ancestor of another queued
  /// tooltip with content — the innermost one takes the tap.
  static void _resolveTapBatch() {
    final batch = _tapBatch.toList();
    _tapBatch.clear();
    final ancestors = <_JustTooltipState>{};
    for (final tooltip in batch) {
      if (!tooltip.mounted || !tooltip._hasContent) continue;
      ancestors.addAll(tooltip._ancestors);
    }
    for (final tooltip in batch) {
      if (!tooltip.mounted || ancestors.contains(tooltip)) continue;
      tooltip._scheduler.onTap(
        isShown: tooltip._isShowing,
        config: tooltip._scheduleConfig,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget child = _SemanticTooltip(
      text: _heardText,
      child: _TooltipScope(
        state: this,
        contentRegistry: _inheritedContentRegistry,
        child: widget.child,
      ),
    );

    if (widget.enableHover) {
      child = MouseRegion(
        onEnter: (event) {
          _pointerInside = true;
          _anchorCandidate = event.position;
          _syncSuppression();
          _scheduleReconcile();
        },
        onHover: (event) => _anchorCandidate = event.position,
        onExit: (_) {
          _pointerInside = false;
          // The pointer's position must not outlive the pointer, or a later
          // programmatic show would anchor at a cursor that has gone.
          _anchorCandidate = null;
          _syncSuppression();
          _scheduleReconcile();
        },
        child: child,
      );
    }

    switch (_tap) {
      case TooltipTap.none:
        break;
      case TooltipTap.claim:
        child = GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A touch fires no MouseRegion callbacks, so the tap-down is the
          // only place a tap-triggered tooltip can learn where the pointer is.
          // It always precedes onTap.
          onTapDown: (details) => _anchorCandidate = details.globalPosition,
          onTap: _toggleFromTap,
          child: child,
        );
      case TooltipTap.observe:
        final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
        child = RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            _ObservedTapRecognizer:
                GestureRecognizerFactoryWithHandlers<_ObservedTapRecognizer>(
                  () => _ObservedTapRecognizer(debugOwner: this),
                  (recognizer) => recognizer
                    ..gestureSettings = gestureSettings
                    ..onTap = (downPosition) {
                      _anchorCandidate = downPosition;
                      _toggleFromTap();
                    },
                ),
          },
          child: child,
        );
    }

    final Widget portal = OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayChildBuilder: (context, _) {
        final Widget overlay = _TooltipScope(
          state: null,
          contentRegistry: _contentRegistry,
          child: _buildOverlayChild(context),
        );
        return SelectionContainer.maybeOf(context) == null
            ? overlay
            : SelectionContainer.disabled(child: overlay);
      },
      child: child,
    );
    return Actions(actions: {DismissIntent: _dismissAction}, child: portal);
  }
}

/// The [TooltipTap.observe] recognizer: a member of the gesture arena that
/// never wins it.
///
/// It reports a tap when its pointer is released while it is still in the
/// arena, and gives the arena up at that moment, so the remaining members
/// decide as if it had never joined. A gesture that wins before the release —
/// a long press, a drag — rejects it first, and no tap is reported.
class _ObservedTapRecognizer extends PrimaryPointerGestureRecognizer {
  _ObservedTapRecognizer({super.debugOwner});

  /// Called with the pointer's down position, in global coordinates.
  void Function(Offset downPosition)? onTap;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kPrimaryButton && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Takes only the first pointer of a press.
    if (state != GestureRecognizerState.ready) return;
    super.addAllowedPointer(event);
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      final downPosition = initialPosition!.global;
      resolve(GestureDisposition.rejected);
      onTap?.call(downPosition);
    } else if (event is PointerCancelEvent ||
        (event is PointerMoveEvent && event.buttons != kPrimaryButton)) {
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  String get debugDescription => 'observed tap';
}

/// Puts a tooltip's [text] on the semantics node its child belongs to, without
/// making a node of its own. The text is read each time semantics are
/// assembled, and a change to it marks them for an update.
class _SemanticTooltip extends SingleChildRenderObjectWidget {
  const _SemanticTooltip({required this.text, required super.child});

  /// Taken once, when the render object is created.
  final ValueListenable<String?> text;

  @override
  _RenderSemanticTooltip createRenderObject(BuildContext context) =>
      _RenderSemanticTooltip(text, Directionality.maybeOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSemanticTooltip renderObject,
  ) {
    renderObject.textDirection = Directionality.maybeOf(context);
  }
}

class _RenderSemanticTooltip extends RenderProxyBox {
  _RenderSemanticTooltip(this._text, this._textDirection);

  final ValueListenable<String?> _text;

  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _text.addListener(markNeedsSemanticsUpdate);
  }

  @override
  void detach() {
    _text.removeListener(markNeedsSemanticsUpdate);
    super.detach();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final text = _text.value;
    if (text == null) return;
    config.tooltip = text;
    config.textDirection = _textDirection;
  }
}

/// The Escape key's [DismissIntent] on the focus path inside a tooltip:
/// closes the tooltip [_JustTooltipState._handleKey] left to it this press,
/// and otherwise hands the intent to the enclosing [DismissIntent] action.
class _DismissTooltipAction extends ContextAction<DismissIntent> {
  _DismissTooltipAction(this.state);

  final _JustTooltipState state;

  /// The nearest [DismissIntent] action above this tooltip, found without
  /// registering a dependency.
  Action<Intent>? get _enclosing {
    Action<Intent>? found;
    state.context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Actions) found = widget.actions[DismissIntent];
      return found == null;
    });
    return found;
  }

  @override
  bool isEnabled(DismissIntent intent, [BuildContext? context]) {
    if (_JustTooltipState._deferred != null) return true;
    final enclosing = _enclosing;
    if (enclosing is ContextAction<Intent>) {
      return enclosing.isEnabled(intent, context);
    }
    return enclosing?.isEnabled(intent) ?? false;
  }

  @override
  bool consumesKey(DismissIntent intent) =>
      _JustTooltipState._deferred != null ||
      (_enclosing?.consumesKey(intent) ?? false);

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    final target = _JustTooltipState._deferred;
    if (target != null) {
      _JustTooltipState._deferred = null;
      target._dismissByUser();
      return null;
    }
    final enclosing = _enclosing;
    if (enclosing is ContextAction<Intent>) {
      return enclosing.invoke(intent, context);
    }
    return enclosing?.invoke(intent);
  }
}
