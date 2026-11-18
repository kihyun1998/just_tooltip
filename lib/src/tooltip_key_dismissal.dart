import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// The internal contract a tooltip implements so [TooltipKeyDismissal] can
/// close it on Escape.
@internal
abstract interface class KeyDismissibleTooltip {
  bool get mounted;

  bool get isTooltipShowing;

  bool get isTooltipFadingOut;

  /// Whether the primary focus is within the tooltip — its child or its
  /// content.
  bool get tooltipHoldsFocus;

  /// Closes the tooltip as the user does with Escape.
  void dismissTooltipByUser();
}

/// Escape's dismissal of shown and pending tooltips (ADR-0010), shared by
/// every tooltip in the process.
@internal
abstract final class TooltipKeyDismissal {
  /// Every shown tooltip, in the order it was shown.
  static final List<KeyDismissibleTooltip> _shown = [];

  /// Tooltips whose show is scheduled but not yet on screen.
  static final Set<KeyDismissibleTooltip> _pending = {};

  /// The shown tooltip whose child or content holds focus, left by this
  /// Escape press to the focus path.
  static KeyDismissibleTooltip? _deferred;

  /// Whether the Escape action closed [_deferred] during this press.
  static bool _closedByAction = false;

  static bool _listening = false;

  /// Records [tooltip] as the most recently shown one.
  static void shown(KeyDismissibleTooltip tooltip) {
    _shown
      ..remove(tooltip)
      ..add(tooltip);
    _syncKeyHandler();
  }

  /// Records that [tooltip] is no longer shown.
  static void hidden(KeyDismissibleTooltip tooltip) {
    if (_shown.remove(tooltip)) _syncKeyHandler();
  }

  /// Records whether [tooltip]'s show is scheduled but not yet on screen.
  static void pending(KeyDismissibleTooltip tooltip, bool pending) {
    final changed = pending ? _pending.add(tooltip) : _pending.remove(tooltip);
    if (changed) _syncKeyHandler();
  }

  /// Whether [tooltip]'s show is scheduled but not yet on screen.
  static bool isPending(KeyDismissibleTooltip tooltip) =>
      _pending.contains(tooltip);

  /// Whether this Escape press left a tooltip's close to the focus path.
  static bool get hasDeferred => _deferred != null;

  /// Whether this Escape press is a tooltip's to consume: it left a tooltip's
  /// close to the focus path, whether or not the Escape action has run.
  static bool get ownsPress => _deferred != null || _closedByAction;

  /// Closes the tooltip this Escape press left to the focus path, called by
  /// the Escape action that ran on it. Returns whether one was left.
  static bool closeDeferredByAction() {
    final target = _deferred;
    if (target == null) return false;
    _deferred = null;
    _closedByAction = true;
    target.dismissTooltipByUser();
    return true;
  }

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

  /// The tooltip Escape closes: the most recently shown one that is not
  /// already hiding.
  static KeyDismissibleTooltip? get _dismissTarget {
    for (final tooltip in _shown.reversed) {
      if (tooltip.isTooltipShowing && !tooltip.isTooltipFadingOut) {
        return tooltip;
      }
    }
    return null;
  }

  /// Handles Escape: closes the target, or leaves one that holds focus to
  /// the Escape action on the focus path and closes it after the press if
  /// that action did not run; with nothing shown, cancels pending shows.
  static bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    final target = _dismissTarget;
    if (target == null) {
      for (final tooltip in _pending.toList()) {
        tooltip.dismissTooltipByUser();
      }
      return false;
    }
    if (target.tooltipHoldsFocus) {
      _deferred = target;
      scheduleMicrotask(_closeDeferred);
      return false;
    }
    target.dismissTooltipByUser();
    return true;
  }

  static void _closeDeferred() {
    final target = _deferred;
    _deferred = null;
    _closedByAction = false;
    if (target != null && target.mounted) target.dismissTooltipByUser();
  }
}
