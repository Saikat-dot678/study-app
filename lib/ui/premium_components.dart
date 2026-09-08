import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class NebulaBackdrop extends StatelessWidget {
  const NebulaBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StudyColors.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(scheme.surface, palette.ambientStart, 0.42)!,
              scheme.surface,
              Color.lerp(scheme.surface, palette.ambientEnd, 0.30)!,
            ],
            stops: const [0, 0.52, 1],
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 14,
    this.blur = 0,
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
    final surface = tint ?? scheme.surfaceContainerLowest;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? scheme.outlineVariant),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBody = MediaQuery.textScalerOf(context).scale(14);
        final compact = constraints.maxWidth < 340 || scaledBody >= 18;
        final effectivePadding = compact
            ? EdgeInsets.fromLTRB(
                math.min(padding.left, 12),
                padding.top,
                math.min(padding.right, 12),
                padding.bottom,
              )
            : padding;
        final childWidget = Padding(padding: effectivePadding, child: child);

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: onTap == null
                ? childWidget
                : InkWell(
                    onTap: onTap,
                    overlayColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered)
                          ? scheme.primary.withValues(alpha: 0.035)
                          : null,
                    ),
                    child: childWidget,
                  ),
          ),
        );
      },
    );
  }
}

class GradientBorderCard extends StatelessWidget {
  const GradientBorderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 16,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StudyColors.of(context);
    return GlassPanel(
      padding: padding,
      radius: radius,
      borderColor: Color.lerp(scheme.outlineVariant, palette.ambientAccent, 0.46),
      onTap: onTap,
      child: child,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Icon(icon, size: 14, color: scheme.primary),
        const SizedBox(width: 5),
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
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
          track: scheme.surfaceContainerHigh,
          active: scheme.primary,
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
    required this.active,
    required this.strokeWidth,
  });

  final double value;
  final Color track;
  final Color active;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.max(0.0, (size.shortestSide - strokeWidth) / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final activePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      value != oldDelegate.value ||
      track != oldDelegate.track ||
      active != oldDelegate.active ||
      strokeWidth != oldDelegate.strokeWidth;
}

class TinySparkline extends StatelessWidget {
  const TinySparkline({super.key, required this.values, this.height = 42});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = StudyColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(values: values, color: palette.research),
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
    final maxValue = values.reduce(math.max);
    final denominator = maxValue <= 0 ? 1.0 : maxValue;
    final barWidth = size.width / (values.length * 1.65);
    final gap =
        (size.width - barWidth * values.length) /
        math.max(1, values.length - 1);
    final paint = Paint()..color = color.withValues(alpha: 0.22);
    final active = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final fraction = (values[i] / denominator).clamp(0.08, 1.0);
      final barHeight = size.height * fraction;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + gap),
          size.height - barHeight,
          barWidth,
          barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, i == values.length - 1 ? active : paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) =>
      color != oldDelegate.color || !_sameValues(values, oldDelegate.values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
