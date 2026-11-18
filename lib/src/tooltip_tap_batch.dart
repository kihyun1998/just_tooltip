import 'dart:async';

import 'package:meta/meta.dart';

/// The internal contract a tooltip implements so [TooltipTapBatch] can give
/// a tap to the innermost tooltip.
@internal
abstract interface class TappableTooltip {
  bool get mounted;

  /// Whether the tooltip has anything to draw.
  bool get hasTooltipContent;

  /// Every enclosing tooltip, nearest first.
  Iterable<TappableTooltip> get tooltipAncestors;

  /// Toggles the tooltip for the tap it was given.
  void takeTap();
}

/// The taps reported during one pointer event, resolved so the innermost
/// tooltip takes the tap (ADR-0006). Shared by every tooltip in the process.
@internal
abstract final class TooltipTapBatch {
  /// Tooltips that reported a tap since the last [_resolve].
  static final Set<TappableTooltip> _batch = {};

  /// Queues [tooltip]'s toggle for the end of the current pointer event.
  static void tapped(TappableTooltip tooltip) {
    if (_batch.isEmpty) scheduleMicrotask(_resolve);
    _batch.add(tooltip);
  }

  /// Toggles every queued tooltip that is not an ancestor of another queued
  /// tooltip with content — the innermost one takes the tap.
  static void _resolve() {
    final batch = _batch.toList();
    _batch.clear();
    final ancestors = <TappableTooltip>{};
    for (final tooltip in batch) {
      if (!tooltip.mounted || !tooltip.hasTooltipContent) continue;
      ancestors.addAll(tooltip.tooltipAncestors);
    }
    for (final tooltip in batch) {
      if (!tooltip.mounted || ancestors.contains(tooltip)) continue;
      tooltip.takeTap();
    }
  }
}
