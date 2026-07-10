import 'dart:async';

import 'package:flutter/foundation.dart';

/// Immutable timing/policy inputs for [TooltipVisibilityScheduler].
///
/// Passed per call so the scheduler holds no configuration state of its own.
class TooltipScheduleConfig {
  const TooltipScheduleConfig({
    this.enableHover = true,
    this.interactive = true,
    this.waitDuration,
    this.showDuration,
  });

  final bool enableHover;
  final bool interactive;
  final Duration? waitDuration;
  final Duration? showDuration;
}

/// Owns the timing of tooltip show/hide transitions.
///
/// Emits [onShow]/[onHide] *requests*; the caller reconciles them against the
/// real visibility. Holds no visibility state — the current `isShown` is passed
/// into each event. Its only retained state is its timers, all cancelled by
/// [dispose].
class TooltipVisibilityScheduler {
  TooltipVisibilityScheduler({required this.onShow, required this.onHide});

  final VoidCallback onShow;
  final VoidCallback onHide;

  /// Grace window after the cursor leaves the target before hiding, so the
  /// cursor can cross the gap onto interactive tooltip content (the Hover
  /// Bridge). See CONTEXT.md.
  static const Duration _hoverBridgeDelay = Duration(milliseconds: 100);

  Timer? _hoverShowTimer;
  Timer? _hoverHideTimer;
  Timer? _autoHideTimer;

  void onChildEnter({
    required bool isShown,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    // The pointer is home; there is nothing left to bridge to. A bridge armed
    // by leaving the tooltip body would otherwise fire while the cursor rests
    // on the child, and the fade-out it starts can never be revived — no
    // further `onEnter` arrives from a pointer that never left.
    _hoverHideTimer?.cancel();
    final wait = config.waitDuration;
    if (wait != null) {
      _hoverShowTimer = Timer(wait, () => _emitShow(config));
    } else {
      _emitShow(config);
    }
  }

  /// Requests a show and (re)starts the auto-hide countdown.
  void _emitShow(TooltipScheduleConfig config) {
    onShow();
    startAutoHide(config);
  }

  /// (Re)starts the auto-hide countdown for a show that happened outside this
  /// scheduler's own events (e.g. a programmatic controller show).
  void startAutoHide(TooltipScheduleConfig config) {
    _autoHideTimer?.cancel();
    final show = config.showDuration;
    if (show != null) {
      _autoHideTimer = Timer(show, onHide);
    }
  }

  void onChildExit({
    required bool isShown,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    // When auto-hide is active, leaving the child does not hide — the
    // showDuration countdown owns hiding.
    if (config.showDuration != null) return;
    if (config.interactive) {
      _startHoverBridge();
    } else {
      onHide();
    }
  }

  /// Delays the hide so the cursor can cross onto the tooltip (the Hover
  /// Bridge). See CONTEXT.md.
  void _startHoverBridge() {
    _hoverHideTimer?.cancel();
    _hoverHideTimer = Timer(_hoverBridgeDelay, onHide);
  }

  void onTap({
    required bool isShown,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    if (isShown) {
      onHide();
    } else {
      _emitShow(config);
    }
  }

  void onTooltipEnter({required TooltipScheduleConfig config}) {
    if (!config.interactive) return;
    _hoverHideTimer?.cancel();
    // Pause the auto-hide countdown while the cursor is on the tooltip.
    _autoHideTimer?.cancel();
  }

  void onTooltipExit({
    required bool isShown,
    required TooltipScheduleConfig config,
  }) {
    if (!config.interactive || !config.enableHover) return;
    if (config.showDuration != null) {
      // Resume the auto-hide countdown after leaving the tooltip.
      startAutoHide(config);
      return;
    }
    _startHoverBridge();
  }

  /// Cancels all pending timers. The scheduler remains usable afterward.
  void reset() => _cancelAll();

  /// Cancels all timers. The single leak-safety point.
  void dispose() => _cancelAll();

  void _cancelAll() {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    _autoHideTimer?.cancel();
  }
}
