import 'package:flutter/foundation.dart';

/// A controller for programmatically showing and hiding a [JustTooltip].
///
/// Attach this controller to a [JustTooltip] via [JustTooltip.controller],
/// then call [show], [hide], or [toggle] to control its visibility.
class JustTooltipController extends ChangeNotifier {
  bool _shouldShow = false;

  /// Whether the tooltip is currently requested to be shown.
  bool get shouldShow => _shouldShow;

  /// Shows the tooltip.
  void show() {
    if (!_shouldShow) {
      _shouldShow = true;
      notifyListeners();
    }
  }

  /// Hides the tooltip.
  void hide() {
    if (_shouldShow) {
      _shouldShow = false;
      notifyListeners();
    }
  }

  /// Toggles the tooltip visibility.
  void toggle() {
    _shouldShow = !_shouldShow;
    notifyListeners();
  }
}
