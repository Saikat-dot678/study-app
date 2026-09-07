import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'motion.dart';

class NebulaBackdrop extends StatefulWidget {
  const NebulaBackdrop({super.key});

  @override
  State<NebulaBackdrop> createState() => _NebulaBackdropState();
}

class _NebulaBackdropState extends State<NebulaBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const _NebulaFrame(progress: 0.25);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => _NebulaFrame(progress: controller.value),
    );
  }
}

class _NebulaFrame extends StatelessWidget {
  const _NebulaFrame({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final angle = progress * math.pi * 2;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: scheme.surface),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface,
                  Color.lerp(scheme.surface, scheme.primary, dark ? 0.055 : 0.035)!,
                  scheme.surface,
                ],
              ),
            ),
          ),
          _GlowOrb(
            alignment: Alignment(
              -0.82 + math.sin(angle) * 0.12,
              -0.72 + math.cos(angle * 0.8) * 0.10,
            ),
            size: 520,
            color: scheme.primary,
            opacity: dark ? 0.15 : 0.09,
          ),
          _GlowOrb(
            alignment: Alignment(
              0.88 + math.cos(angle * 0.7) * 0.08,
              -0.12 + math.sin(angle * 1.1) * 0.14,
            ),
            size: 430,
            color: scheme.secondary,
            opacity: dark ? 0.11 : 0.07,
          ),
          _GlowOrb(
            alignment: Alignment(
              -0.05 + math.sin(angle * 0.55) * 0.18,
              0.98 + math.cos(angle) * 0.08,
            ),
            size: 560,
            color: scheme.tertiary,
            opacity: dark ? 0.10 : 0.055,
          ),
          CustomPaint(
            painter: _GridPainter(
              color: scheme.onSurface.withValues(alpha: dark ? 0.022 : 0.018),
              offset: progress,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.size,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color, required this.offset});
  final Color color;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 48.0;
    final shift = offset * gap;
    for (double x = -gap + shift; x < size.width + gap; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -gap + shift; y < size.height + gap; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.offset != offset;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = 18,
    this.tint,
    this.borderColor,
    this.onTap,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = tint ??
        scheme.surfaceContainerLow.withValues(alpha: dark ? 0.67 : 0.80);
    final border = borderColor ??
        scheme.outlineVariant.withValues(alpha: dark ? 0.46 : 0.38);
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: dark ? 0.11 : 0.07),
                      blurRadius: 34,
                      spreadRadius: -8,
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            child: onTap == null
                ? Padding(padding: padding, child: child)
                : InkWell(
                    borderRadius: BorderRadius.circular(radius),
                    onTap: onTap,
                    child: Padding(padding: padding, child: child),
                  ),
          ),
        ),
      ),
    );
    return onTap == null ? panel : HoverLift(scale: 1.008, child: panel);
  }
}

class GradientBorderCard extends StatelessWidget {
  const GradientBorderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverLift(
      enabled: onTap != null,
      scale: 1.008,
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.64),
              scheme.secondary.withValues(alpha: 0.20),
              scheme.tertiary.withValues(alpha: 0.42),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Material(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.90),
            child: onTap == null
                ? Padding(padding: padding, child: child)
                : InkWell(
                    onTap: onTap,
                    child: Padding(padding: padding, child: child),
                  ),
          ),
        ),
      ),
    );
  }
}

class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.value,
    required this.center,
    this.size = 82,
    this.strokeWidth = 7,
  });

  final double value;
  final Widget center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1),
          track: scheme.onSurface.withValues(alpha: 0.08),
          begin: scheme.primary,
          end: scheme.secondary,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.track,
    required this.begin,
    required this.end,
    required this.strokeWidth,
  });

  final double value;
  final Color track;
  final Color begin;
  final Color end;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2, false, paint);
    if (value <= 0) return;
    paint.shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: math.pi * 1.5,
      colors: [begin, end, begin],
    ).createShader(rect);
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.track != track ||
      oldDelegate.begin != begin ||
      oldDelegate.end != end;
}

class TinySparkline extends StatelessWidget {
  const TinySparkline({super.key, required this.values, this.height = 40});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(1, math.max);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y = size.height - (values[index] / maxValue) * (size.height - 4) - 2;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0.25)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.values != values;
}
