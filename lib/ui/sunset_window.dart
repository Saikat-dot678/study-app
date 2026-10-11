import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../appearance/sunset_scene.dart';

/// A quiet, living landscape. Its animation repaints only the canvas.
class SunsetWindow extends StatefulWidget {
  const SunsetWindow({super.key, required this.scene, this.animate = true});

  final SunsetScene scene;
  final bool animate;

  @override
  State<SunsetWindow> createState() => _SunsetWindowState();
}

class _SunsetWindowState extends State<SunsetWindow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  );
  final ValueNotifier<Offset> _pointer = ValueNotifier(Offset.zero);
  late final Listenable _repaint = Listenable.merge([_clock, _pointer]);
  bool _foreground = true;
  bool _motionAllowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant SunsetWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    _motionAllowed =
        widget.animate &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motionAllowed) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      _pointer.value = Offset.zero;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${widget.scene.season.label} landscape, '
          '${widget.scene.phase.label}, ${widget.scene.weather.label}',
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 1.08,
            child: LayoutBuilder(
              builder: (context, constraints) => MouseRegion(
                onHover: (event) {
                  if (!_motionAllowed) return;
                  _pointer.value = Offset(
                    (event.localPosition.dx / constraints.maxWidth - .5).clamp(
                      -.5,
                      .5,
                    ),
                    (event.localPosition.dy / constraints.maxHeight - .5).clamp(
                      -.5,
                      .5,
                    ),
                  );
                },
                onExit: (_) => _pointer.value = Offset.zero,
                child: CustomPaint(
                  painter: _SunsetPainter(
                    scene: widget.scene,
                    clock: _clock,
                    pointer: _pointer,
                    repaint: _repaint,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dashboard's editorial welcome, paired with the live landscape.
class SunsetWelcome extends StatelessWidget {
  const SunsetWelcome({
    super.key,
    required this.scene,
    required this.onContinue,
    required this.onLibrary,
    this.continueLabel = 'Continue studying',
    this.weatherLabel,
    this.animate = true,
  });

  final SunsetScene scene;
  final VoidCallback onContinue;
  final VoidCallback onLibrary;
  final String continueLabel;
  final String? weatherLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final palette = scene.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A LITTLE SPACE. A WORLD OF POSSIBILITY.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                letterSpacing: 1.8,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Make room',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: wide ? 48 : 42,
                fontWeight: FontWeight.w400,
                letterSpacing: -2.2,
                height: 1.12,
                color: palette.ink,
              ),
            ),
            Text(
              'for wonder.',
              style: TextStyle(
                fontFamily: 'Editorial',
                fontStyle: FontStyle.italic,
                fontSize: wide ? 60 : 52,
                letterSpacing: -1.8,
                height: 1.15,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                'A softer place to settle in, follow your curiosity, '
                'and make a little progress.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  height: 1.7,
                  color: palette.muted,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 17,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: Text(continueLabel),
                ),
                TextButton.icon(
                  onPressed: onLibrary,
                  style: TextButton.styleFrom(foregroundColor: palette.ink),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Explore library'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  scene.dark
                      ? Icons.nights_stay_outlined
                      : Icons.wb_sunny_outlined,
                  size: 14,
                  color: palette.muted,
                ),
                Text(
                  '${scene.season.label} · ${scene.phase.label}',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
                if (weatherLabel != null && weatherLabel!.isNotEmpty)
                  Text(
                    '· $weatherLabel',
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
              ],
            ),
          ],
        );
        final artwork = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SunsetWindow(scene: scene, animate: animate),
        );
        return Padding(
          padding: EdgeInsets.symmetric(vertical: wide ? 26 : 18),
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 11, child: copy),
                    const SizedBox(width: 28),
                    Expanded(flex: 10, child: artwork),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: 12),
                    Center(child: artwork),
                  ],
                ),
        );
      },
    );
  }
}

class _SunsetPainter extends CustomPainter {
  _SunsetPainter({
    required this.scene,
    required this.clock,
    required this.pointer,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final SunsetScene scene;
  final Animation<double> clock;
  final ValueListenable<Offset> pointer;
  static const _cream = Color(0xffffeed3);
  static const _tau = math.pi * 2;

  Path _arch(Rect rect) => Path()
    ..moveTo(rect.left, rect.bottom)
    ..lineTo(rect.left, rect.top + rect.width / 2)
    ..arcTo(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.width),
      math.pi,
      math.pi,
      false,
    )
    ..lineTo(rect.right, rect.bottom)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Work in a stable coordinate system so both phones and desktops stay crisp.
    canvas.save();
    canvas.scale(size.width / 400, size.height / 370);
    final palette = scene.palette;
    final t = clock.value;
    final drift = math.sin(t * _tau);
    final gaze = pointer.value;
    const frame = Rect.fromLTWH(71, 23, 258, 302);
    final arch = _arch(frame);

    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.accent.withValues(alpha: .12),
          palette.accent.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(4, 20, 390, 340));
    canvas.drawOval(const Rect.fromLTWH(4, 20, 390, 340), halo);

    // A thin offset outline and little orbit marks frame the illustration.
    canvas.drawPath(
      _arch(const Rect.fromLTWH(61, 13, 278, 316)),
      Paint()
        ..color = palette.accent.withValues(alpha: .17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final ornament = Paint()
      ..color = palette.secondary.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.drawCircle(const Offset(345, 102), 8, ornament);
    canvas.drawLine(const Offset(345, 89), const Offset(345, 115), ornament);
    canvas.drawLine(const Offset(332, 102), const Offset(358, 102), ornament);
    canvas.drawCircle(const Offset(42, 272), 3, ornament);
    canvas.drawLine(const Offset(37, 288), const Offset(51, 288), ornament);
    canvas.drawShadow(arch, palette.ink.withValues(alpha: .14), 10, false);

    canvas.save();
    canvas.clipPath(arch);
    canvas.drawRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.sky,
          stops: const [0, .58, 1],
        ).createShader(frame),
    );

    if (scene.dark) _stars(canvas, t, gaze);
    _sun(canvas, t, gaze);
    _clouds(canvas, t, palette);
    _landscape(canvas, drift, gaze, palette);
    _weather(canvas, t, palette);
    _season(canvas, t, palette);

    // Soft edge shading gives the window a little depth without raster assets.
    canvas.drawRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x0d49334b), Color(0x00ffffff), Color(0x0d49334b)],
          stops: [0, .45, 1],
        ).createShader(frame),
    );
    canvas.restore();

    canvas.drawPath(
      arch,
      Paint()
        ..color = palette.ink.withValues(alpha: .10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // The stone sill anchors the scene in the page.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(61, 326, 278, 8),
        const Radius.circular(2),
      ),
      Paint()..color = Color.lerp(palette.elevated, palette.surface, .4)!,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(53, 336, 294, 5),
        const Radius.circular(2),
      ),
      Paint()..color = palette.elevated.withValues(alpha: .65),
    );
    canvas.drawOval(
      const Rect.fromLTWH(72, 345, 256, 11),
      Paint()..color = palette.ink.withValues(alpha: .04),
    );
    canvas.restore();
  }

  void _sun(Canvas canvas, double t, Offset gaze) {
    final high = scene.phase == DayPhase.day || scene.phase == DayPhase.night;
    final center = Offset(227 + gaze.dx * 9, (high ? 98 : 141) + gaze.dy * 7);
    final moon = scene.phase == DayPhase.night;
    final radius = moon ? 24.0 : 34.0;
    final glowRect = Rect.fromCircle(center: center, radius: radius * 2.5);
    canvas.drawCircle(
      center,
      radius * 2.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _cream.withValues(alpha: moon ? .18 : .32),
            _cream.withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _cream.withValues(alpha: .93),
    );
    if (moon) {
      canvas.drawCircle(
        center + const Offset(10, -7),
        22,
        Paint()
          ..color = Color.lerp(scene.palette.sky[0], scene.palette.sky[1], .3)!,
      );
    } else {
      final ring = radius + 8 + math.sin(t * _tau) * 1.5;
      canvas.drawCircle(
        center,
        ring,
        Paint()
          ..color = _cream.withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6,
      );
    }
  }

  void _stars(Canvas canvas, double t, Offset gaze) {
    for (var i = 0; i < 28; i++) {
      final x = 77.0 + ((i * 71) % 247) + gaze.dx * 4;
      final y = 38.0 + ((i * 37) % 143) + gaze.dy * 4;
      final breath = .3 + .25 * (.5 + .5 * math.sin(t * _tau + i));
      canvas.drawCircle(
        Offset(x, y),
        i % 5 == 0 ? 1.3 : .7,
        Paint()..color = _cream.withValues(alpha: breath),
      );
    }
  }

  void _clouds(Canvas canvas, double t, SunsetPalette palette) {
    final cloudy = scene.weather != SkyWeather.clear;
    final count = cloudy ? 6 : 2;
    final paint = Paint()
      ..color = Color.lerp(
        _cream,
        palette.sky[0],
        .45,
      )!.withValues(alpha: cloudy ? .42 : .30);
    for (var i = 0; i < count; i++) {
      final drift = math.sin(t * _tau + i * 1.7) * 17;
      final x = 70.0 + (i * 81 % 230) + drift;
      final y = 96.0 + (i * 37 % 107);
      final width = cloudy ? 82.0 : 57.0;
      final path = Path()
        ..moveTo(x - width / 2, y + 5)
        ..cubicTo(x - width / 2, y - 4, x - 18, y - 9, x - 9, y - 5)
        ..cubicTo(x - 3, y - 22, x + 24, y - 18, x + 25, y - 5)
        ..cubicTo(x + 45, y - 4, x + width / 2, y + 5, x + width / 2, y + 5)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _landscape(
    Canvas canvas,
    double drift,
    Offset gaze,
    SunsetPalette palette,
  ) {
    for (var layer = 0; layer < 3; layer++) {
      final y = 212.0 + layer * 31;
      final parallax = gaze.dx * (layer + 1) * 7 + drift * (layer + 1) * .7;
      final path = Path()
        ..moveTo(45, y + 28)
        ..cubicTo(
          102 + parallax,
          y - 31,
          148 + parallax,
          y - 39,
          207 + parallax,
          y - 6,
        )
        ..cubicTo(263 + parallax, y + 28, 300 + parallax, y - 33, 363, y - 11)
        ..lineTo(363, 341)
        ..lineTo(45, 341)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.hills[layer],
              Color.lerp(palette.hills[layer], palette.secondary, .15)!,
            ],
          ).createShader(Rect.fromLTWH(45, y - 30, 320, 160)),
      );
      if (scene.season == StudySeason.winter && layer == 0) {
        final snowcap = Path()
          ..moveTo(73 + parallax, y + 3)
          ..cubicTo(
            111 + parallax,
            y - 28,
            150 + parallax,
            y - 28,
            188 + parallax,
            y - 16,
          )
          ..cubicTo(
            168 + parallax,
            y - 11,
            155 + parallax,
            y - 18,
            136 + parallax,
            y - 8,
          )
          ..cubicTo(
            114 + parallax,
            y - 2,
            98 + parallax,
            y - 5,
            73 + parallax,
            y + 3,
          );
        canvas.drawPath(
          snowcap,
          Paint()..color = _cream.withValues(alpha: .65),
        );
      }
    }
    final contour = Paint()
      ..color = _cream.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    for (var i = 0; i < 4; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(109 + i * 17, 325)
          ..cubicTo(170 + i * 17, 291, 225 + i * 14, 306, 277 + i * 16, 284),
        contour,
      );
    }
    // Three distant birds follow a slow arc above the hills.
    if (scene.weather == SkyWeather.clear && !scene.dark) {
      final birdPaint = Paint()
        ..color = palette.hills.last.withValues(alpha: .48)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1;
      for (var i = 0; i < 3; i++) {
        final x = 124.0 + i * 17 + drift * 5;
        final y = 159.0 - i * 7 + drift * 1.5;
        canvas.drawPath(
          Path()
            ..moveTo(x - 5, y - 2)
            ..quadraticBezierTo(x - 2, y - 3, x, y)
            ..quadraticBezierTo(x + 2, y - 3, x + 5, y - 2),
          birdPaint,
        );
      }
    }
  }

  void _weather(Canvas canvas, double t, SunsetPalette palette) {
    final weather = scene.weather;
    if (weather == SkyWeather.rain || weather == SkyWeather.storm) {
      final paint = Paint()
        ..color = _cream.withValues(
          alpha: weather == SkyWeather.storm ? .38 : .28,
        )
        ..strokeWidth = .8
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < (weather == SkyWeather.storm ? 65 : 42); i++) {
        final x = 54.0 + (i * 53 % 289);
        final y = 20 + ((i * 67 + t * 340 * 12) % 340);
        canvas.drawLine(Offset(x, y), Offset(x - 3, y + 12), paint);
      }
    }
    if (weather == SkyWeather.snow) {
      for (var i = 0; i < 42; i++) {
        final x = 63.0 + (i * 61 % 277) + math.sin(t * _tau * 3 + i) * 9;
        final y = 14 + ((i * 43 + t * 320 * 2) % 320);
        canvas.drawCircle(
          Offset(x, y),
          i % 3 == 0 ? 2 : 1.2,
          Paint()..color = _cream.withValues(alpha: .4 + (i % 3) * .15),
        );
      }
    }
    if (weather == SkyWeather.fog ||
        weather == SkyWeather.rain ||
        weather == SkyWeather.storm) {
      for (var i = 0; i < 3; i++) {
        final x = 165 + math.sin(t * _tau + i) * 27;
        final rect = Rect.fromCenter(
          center: Offset(x, 213.0 + i * 36),
          width: 410,
          height: 42,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..shader = RadialGradient(
              colors: [
                _cream.withValues(alpha: weather == SkyWeather.fog ? .21 : .07),
                _cream.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      }
    }
  }

  void _season(Canvas canvas, double t, SunsetPalette palette) {
    if (scene.weather != SkyWeather.clear &&
        scene.weather != SkyWeather.clouds) {
      return;
    }
    final spring = scene.season == StudySeason.spring;
    final autumn = scene.season == StudySeason.autumn;
    if (!spring && !autumn) {
      if (scene.season != StudySeason.summer || !scene.dark) return;
      for (var i = 0; i < 9; i++) {
        final center = Offset(
          84.0 + i * 27 + math.sin(t * _tau + i) * 6,
          248.0 + (i * 23 % 62) + math.cos(t * _tau + i) * 6,
        );
        canvas.drawCircle(
          center,
          1.1,
          Paint()
            ..color = _cream.withValues(
              alpha: .35 + .2 * math.sin(t * _tau + i),
            ),
        );
      }
      return;
    }
    for (var i = 0; i < 10; i++) {
      final x = 73.0 + (i * 59 % 253) + math.sin(t * _tau * 2 + i) * 14;
      final y = 26 + ((i * 67 + t * 315) % 315);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(t * _tau + i) * 1.3);
      final color = spring ? const Color(0xffffdfd6) : const Color(0xffe5b17b);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: spring ? 5 : 7, height: 3),
        Paint()..color = color.withValues(alpha: scene.dark ? .4 : .67),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter oldDelegate) =>
      oldDelegate.scene.phase != scene.phase ||
      oldDelegate.scene.season != scene.season ||
      oldDelegate.scene.weather != scene.weather ||
      oldDelegate.scene.hour != scene.hour ||
      oldDelegate.clock != clock ||
      oldDelegate.pointer != pointer;
}
