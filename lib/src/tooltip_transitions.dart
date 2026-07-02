import 'package:flutter/widgets.dart';

import 'enums.dart';

/// Immutable description of *how* a tooltip animates in and out.
///
/// Built by the widget from its animation parameters and passed, with an
/// already-curved [Animation], to [TooltipTransitions.build].
class TooltipTransitionSpec {
  const TooltipTransitionSpec({
    required this.type,
    this.fadeBegin = 0.0,
    this.scaleBegin = 0.0,
    this.slideOffset = 0.3,
    this.rotationBegin = -0.05,
    this.direction = TooltipDirection.top,
  });

  final TooltipAnimation type;
  final double fadeBegin;
  final double scaleBegin;
  final double slideOffset;
  final double rotationBegin;
  final TooltipDirection direction;
}

/// Pure transform from an [Animation] + [TooltipTransitionSpec] to a
/// transition-wrapped widget. Owns no animation lifecycle.
class TooltipTransitions {
  const TooltipTransitions._();

  static Widget build({
    required Animation<double> animation,
    required TooltipTransitionSpec spec,
    required Widget child,
  }) {
    switch (spec.type) {
      case TooltipAnimation.none:
        return child;
      case TooltipAnimation.fade:
        return _fade(animation, spec, child);
      case TooltipAnimation.scale:
        return _scale(animation, spec, child);
      case TooltipAnimation.slide:
        return SlideTransition(
          position: _slideOffset(animation, spec),
          child: child,
        );
      case TooltipAnimation.fadeScale:
        return _fade(animation, spec, _scale(animation, spec, child));
      case TooltipAnimation.fadeSlide:
        return _fade(
          animation,
          spec,
          SlideTransition(
            position: _slideOffset(animation, spec),
            child: child,
          ),
        );
      case TooltipAnimation.rotation:
        return _fade(
          animation,
          spec,
          RotationTransition(
            turns: Tween<double>(begin: spec.rotationBegin, end: 0.0)
                .animate(animation),
            child: child,
          ),
        );
    }
  }

  static Widget _fade(
    Animation<double> animation,
    TooltipTransitionSpec spec,
    Widget child,
  ) {
    if (spec.fadeBegin == 0.0) {
      return FadeTransition(opacity: animation, child: child);
    }
    return FadeTransition(
      opacity:
          Tween<double>(begin: spec.fadeBegin, end: 1.0).animate(animation),
      child: child,
    );
  }

  static Widget _scale(
    Animation<double> animation,
    TooltipTransitionSpec spec,
    Widget child,
  ) {
    if (spec.scaleBegin == 0.0) {
      return ScaleTransition(scale: animation, child: child);
    }
    return ScaleTransition(
      scale:
          Tween<double>(begin: spec.scaleBegin, end: 1.0).animate(animation),
      child: child,
    );
  }

  static Animation<Offset> _slideOffset(
    Animation<double> animation,
    TooltipTransitionSpec spec,
  ) {
    final d = spec.slideOffset;
    final Offset begin;
    switch (spec.direction) {
      case TooltipDirection.top:
        begin = Offset(0, -d);
      case TooltipDirection.bottom:
        begin = Offset(0, d);
      case TooltipDirection.left:
        begin = Offset(-d, 0);
      case TooltipDirection.right:
        begin = Offset(d, 0);
    }
    return Tween<Offset>(begin: begin, end: Offset.zero).animate(animation);
  }
}
