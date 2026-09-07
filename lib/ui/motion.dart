import 'package:flutter/material.dart';

abstract final class StudyMotion {
  static const quick = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 240);
  static const emphasized = Duration(milliseconds: 380);
  static const curve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }
}

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 1.012,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool active = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) {
        if (active != value) setState(() => active = value);
      },
      onShowFocusHighlight: (value) {
        if (active != value) setState(() => active = value);
      },
      child: AnimatedScale(
        scale: enabled && active ? widget.scale : 1,
        duration: StudyMotion.duration(context, StudyMotion.quick),
        curve: StudyMotion.curve,
        child: AnimatedContainer(
          duration: StudyMotion.duration(context, StudyMotion.quick),
          curve: StudyMotion.curve,
          transform: Matrix4.translationValues(
            0,
            enabled && active ? -2 : 0,
            0,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (MediaQuery.disableAnimationsOf(context)) {
        if (mounted) setState(() => visible = true);
        return;
      }
      await Future<void>.delayed(
        Duration(milliseconds: (widget.index.clamp(0, 8)) * 42),
      );
      if (mounted) setState(() => visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.035),
      duration: StudyMotion.duration(context, StudyMotion.emphasized),
      curve: StudyMotion.curve,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: StudyMotion.duration(context, StudyMotion.emphasized),
        curve: StudyMotion.curve,
        child: widget.child,
      ),
    );
  }
}
