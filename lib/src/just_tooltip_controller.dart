import 'package:meta/meta.dart';

/// The internal contract the widget State implements so a
/// [JustTooltipController] can drive it.
///
/// Not part of the public API — consumers use [JustTooltipController].
@internal
abstract interface class JustTooltipControllerTarget {
  void showTooltip();
  void hideTooltip();
  void toggleTooltip();
  bool get isTooltipShowing;
}

/// A controller for programmatically showing and hiding a [JustTooltip].
///
/// Attach this controller to a [JustTooltip] via [JustTooltip.controller],
/// then call [show], [hide], or [toggle] to control its visibility.
class JustTooltipController {
  JustTooltipControllerTarget? _target;

  /// A show/hide command issued before a tooltip attaches. Consumed and
  /// cleared on [attach]; meaningful only while no target is attached.
  bool _pendingShow = false;

  /// Whether the tooltip is currently showing.
  ///
  /// Reflects the attached tooltip's live state, or — before a tooltip
  /// attaches — the queued command.
  bool get isShowing => _target?.isTooltipShowing ?? _pendingShow;

  /// Shows the tooltip.
  void show() {
    final target = _target;
    if (target != null) {
      target.showTooltip();
    } else {
      _pendingShow = true;
    }
  }

  /// Hides the tooltip.
  void hide() {
    final target = _target;
    if (target != null) {
      target.hideTooltip();
    } else {
      _pendingShow = false;
    }
  }

  /// Toggles the tooltip visibility.
  void toggle() {
    final target = _target;
    if (target != null) {
      target.toggleTooltip();
    } else {
      _pendingShow = !_pendingShow;
    }
  }

  /// Binds this controller to a tooltip's State. Internal — called by
  /// [JustTooltip].
  ///
  /// Consumes and clears any queued show, returning `true` if one was pending
  /// so the caller can apply it once laid out.
  @internal
  bool attach(JustTooltipControllerTarget target) {
    assert(
      _target == null,
      'This JustTooltipController is already attached to a tooltip. '
      'A controller can drive only one JustTooltip at a time.',
    );
    _target = target;
    final pending = _pendingShow;
    _pendingShow = false;
    return pending;
  }

  /// Unbinds [target] from this controller. Internal — called by [JustTooltip]
  /// on dispose or controller swap. A detached controller reports
  /// `isShowing == false`.
  @internal
  void detach(JustTooltipControllerTarget target) {
    if (identical(_target, target)) {
      _target = null;
    }
  }
}
