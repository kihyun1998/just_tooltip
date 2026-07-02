import 'package:meta/meta.dart';

/// The internal contract a tooltip implements so the [TooltipRegistry] can
/// dismiss it when another tooltip is shown.
@internal
abstract interface class DismissibleTooltip {
  void dismissTooltip();
}

/// Enforces the "one tooltip visible at a time" policy.
///
/// A [JustTooltip] registers on show and unregisters on hide/dispose. Showing
/// a tooltip dismisses every other registered tooltip first.
///
/// Defaults to an app-global shared instance. Pass an explicit
/// `TooltipRegistry()` to [JustTooltip.registry] to isolate a group (or a
/// test) from the shared one.
class TooltipRegistry {
  TooltipRegistry();

  final Set<DismissibleTooltip> _visible = {};

  /// Registers [entry], dismissing every other currently-registered tooltip.
  @internal
  void show(DismissibleTooltip entry) {
    for (final other in _visible.toList()) {
      if (!identical(other, entry)) {
        other.dismissTooltip();
      }
    }
    _visible.add(entry);
  }

  /// Unregisters [entry]. Called when a tooltip hides or is disposed.
  @internal
  void remove(DismissibleTooltip entry) {
    _visible.remove(entry);
  }
}
