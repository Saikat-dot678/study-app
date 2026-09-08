import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A static, low-cost backdrop for the application shell.
///
/// The previous implementation animated several blurred full-screen layers on
/// every frame. This keeps a sense of depth without a ticker, backdrop filters,
/// or continuous repainting.
class NebulaBackdrop extends StatelessWidget {
  const NebulaBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              Color.lerp(scheme.surface, scheme.primary, dark ? 0.035 : 0.018)!,
              scheme.surface,
            ],
            stops: const [0, 0.52, 1],
          ),
        ),
      ),
    );
  }
}

/// The shared application surface.
///
/// The name is retained to avoid churn across feature pages, but this is an
/// opaque surface rather than a BackdropFilter. Native Material states provide
/// hover, focus, keyboard and touch feedback safely.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 18,
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
      side: BorderSide(
        color: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.72),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

class GradientBorderCard extends StatelessWidget {
  const GradientBorderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.72),
            scheme.outlineVariant.withValues(alpha: 0.34),
            scheme.tertiary.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius - 1),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
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
        color: scheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.75,
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
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          color: Theme.of(context).colorScheme.tertiary,
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
      final height = size.height * fraction;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + gap),
          size.height - height,
          barWidth,
          height,
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
