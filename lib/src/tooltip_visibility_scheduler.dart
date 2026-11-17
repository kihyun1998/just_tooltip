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
/// Emits [onShow]/[onHide]/[onClose]/[onWaitElapsed] *requests*; the caller
/// reconciles them against the real visibility. Holds no visibility state —
/// the current `isShown`, and whether the pointer rests on the tooltip body
/// (`pointerOnBody`), are passed into each event that needs them. Its only
/// retained state is its timers, all cancelled by [dispose].
class TooltipVisibilityScheduler {
  TooltipVisibilityScheduler({
    required this.onShow,
    required this.onHide,
    required this.onWaitElapsed,
    VoidCallback? onClose,
  }) : onClose = onClose ?? onHide;

  final VoidCallback onShow;

  /// A hide the trigger leaving asks for: a child or body exit without the
  /// Hover Bridge, or the bridge running out.
  final VoidCallback onHide;

  /// A hide the trigger leaving did not cause: a tap on a shown tooltip, or
  /// the auto-hide. Defaults to [onHide].
  final VoidCallback onClose;

  /// A hover show has waited out `waitDuration`. The caller answers with
  /// [showAfterWait], passing the config and facts of this moment.
  final VoidCallback onWaitElapsed;

  /// Grace window after the cursor leaves the target before hiding, so the
  /// cursor can cross the gap onto interactive tooltip content (the Hover
  /// Bridge). See GLOSSARY.md.
  static const Duration _hoverBridgeDelay = Duration(milliseconds: 100);

  Timer? _hoverShowTimer;
  Timer? _hoverHideTimer;
  Timer? _autoHideTimer;

  void onChildEnter({
    required bool isShown,
    required bool pointerOnBody,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    // The pointer is home; there is nothing left to bridge to. A bridge armed
    // by leaving the tooltip body would otherwise fire while the cursor rests
    // on the child, and the fade-out it starts can never be revived — no
    // further `onEnter` arrives from a pointer that never left.
    _hoverHideTimer?.cancel();
    final wait = config.waitDuration;
    // A shown tooltip — fading out counts — is turned back at once.
    if (wait != null && !isShown) {
      _hoverShowTimer = Timer(wait, onWaitElapsed);
    } else {
      _emitShow(config, pointerOnBody: pointerOnBody);
    }
  }

  /// The answer to [onWaitElapsed]: requests the show the wait held back
  /// and (re)starts the auto-hide countdown, both from [config] and
  /// [pointerOnBody] as they are now.
  void showAfterWait({
    required bool pointerOnBody,
    required TooltipScheduleConfig config,
  }) => _emitShow(config, pointerOnBody: pointerOnBody);

  /// Requests a show and (re)starts the auto-hide countdown.
  void _emitShow(TooltipScheduleConfig config, {required bool pointerOnBody}) {
    onShow();
    startAutoHide(config, pointerOnBody: pointerOnBody);
  }

  /// A show that happened outside this scheduler's own events — a controller
  /// show. Cancels a hover show still waiting out `waitDuration` and an armed
  /// Hover Bridge, and (re)starts the auto-hide countdown.
  void onProgrammaticShow({
    required bool pointerOnBody,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    startAutoHide(config, pointerOnBody: pointerOnBody);
  }

  /// (Re)starts the auto-hide countdown, cancelling the previous one. While
  /// [pointerOnBody] the countdown stays paused: [onTooltipExit] starts it.
  void startAutoHide(
    TooltipScheduleConfig config, {
    required bool pointerOnBody,
  }) {
    _autoHideTimer?.cancel();
    final show = config.showDuration;
    if (show != null && !pointerOnBody) {
      _autoHideTimer = Timer(show, onClose);
    }
  }

  /// A trigger leaving: the pointer leaving the child, keyboard focus
  /// leaving, or a trigger turned off. With [hoverOnBody] — a pointer that
  /// entered the tooltip body with `enableHover` on rests on it — it asks for
  /// no hide: the body's exit asks for it through [onTooltipExit].
  void onChildExit({
    required bool isShown,
    required bool hoverOnBody,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    // When auto-hide is active, leaving the child does not hide — the
    // showDuration countdown owns hiding.
    if (config.showDuration != null) return;
    if (hoverOnBody) return;
    _hideOnTriggerExit(config);
  }

  /// The hide a trigger exit asks for with no `showDuration`: the Hover
  /// Bridge when `interactive`, otherwise at once.
  void _hideOnTriggerExit(TooltipScheduleConfig config) {
    if (config.interactive) {
      _startHoverBridge();
    } else {
      onHide();
    }
  }

  /// `showDuration` changed on a shown tooltip that is not fading out.
  /// (Re)starts the auto-hide countdown from now, paused while
  /// [pointerOnBody], or cancels it when `showDuration` is now `null`.
  /// Cleared, with [exitLeftToCountdown] and the pointer off the body, the
  /// trigger exit the countdown held asks for its hide now, as [onChildExit]
  /// does; with the pointer on the body, [onTooltipExit] asks for it.
  void onShowDurationChange({
    required bool pointerOnBody,
    required bool exitLeftToCountdown,
    required TooltipScheduleConfig config,
  }) {
    startAutoHide(config, pointerOnBody: pointerOnBody);
    if (config.showDuration != null) return;
    if (exitLeftToCountdown && !pointerOnBody) _hideOnTriggerExit(config);
  }

  /// Delays the hide so the cursor can cross onto the tooltip (the Hover
  /// Bridge). See GLOSSARY.md.
  void _startHoverBridge() {
    _hoverHideTimer?.cancel();
    _hoverHideTimer = Timer(_hoverBridgeDelay, onHide);
  }

  void onTap({
    required bool isShown,
    required bool pointerOnBody,
    required TooltipScheduleConfig config,
  }) {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    if (isShown) {
      onClose();
    } else {
      _emitShow(config, pointerOnBody: pointerOnBody);
    }
  }

  /// The pointer entering the tooltip body. Pauses the auto-hide countdown,
  /// and with `enableHover` on cancels an armed Hover Bridge; with
  /// [turnBack], also requests a show, which turns a fade-out back.
  void onTooltipEnter({
    required bool turnBack,
    required TooltipScheduleConfig config,
  }) {
    if (!config.interactive) return;
    if (config.enableHover) _hoverHideTimer?.cancel();
    // Pause the auto-hide countdown while the cursor is on the tooltip.
    _autoHideTimer?.cancel();
    if (turnBack) onShow();
  }

  /// The pointer leaving the tooltip body. With `showDuration`, resumes the
  /// auto-hide countdown. Otherwise, with [exitLeftToCountdown] — a trigger
  /// exit left to a countdown `showDuration` no longer runs — it requests the
  /// hide that exit asks for, as [onChildExit] does. Otherwise it is a hover
  /// exit when `enableHover` is on or [enteredWithHover] says it was on when
  /// the pointer entered the body: with both `enableHover` and `interactive`
  /// on it arms the Hover Bridge, and with either off it requests the hide at
  /// once, as [onChildExit] does. Any other exit does nothing.
  void onTooltipExit({
    required bool isShown,
    required bool enteredWithHover,
    required bool exitLeftToCountdown,
    required TooltipScheduleConfig config,
  }) {
    if (config.showDuration != null) {
      // Resume the auto-hide countdown after leaving the tooltip.
      startAutoHide(config, pointerOnBody: false);
      return;
    }
    if (exitLeftToCountdown) {
      _hideOnTriggerExit(config);
      return;
    }
    if (!config.enableHover && !enteredWithHover) return;
    if (config.enableHover && config.interactive) {
      _startHoverBridge();
    } else {
      onHide();
    }
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
