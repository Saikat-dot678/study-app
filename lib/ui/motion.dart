import 'package:flutter/material.dart';

abstract final class StudyMotion {
  static const quick = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 190);
  static const emphasized = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }
}

/// Compatibility wrapper for older feature widgets.
///
/// Hover animation used to call setState from focus/hover highlight callbacks
/// and alter hit-test geometry under the pointer. Material/InkWell already
/// supplies stable hover, focus and pressed feedback, so this wrapper no longer
/// owns mutable pointer state.
class HoverLift extends StatelessWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 1,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  Widget build(BuildContext context) => child;
}

/// Preserves the old composition API while avoiding dozens of independent
/// entrance animations whenever a page is rebuilt.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => child;
}
