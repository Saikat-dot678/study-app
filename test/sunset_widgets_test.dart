import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_app/appearance/appearance_controller.dart';
import 'package:study_app/appearance/sunset_scene.dart';
import 'package:study_app/appearance/weather_service.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/sunset_settings.dart';
import 'package:study_app/ui/sunset_window.dart';

class _OfflineWeather implements WeatherSource {
  @override
  void cancel() {}
  @override
  void dispose() {}
  @override
  Future<List<WeatherCity>> search(String query) async => [];
  @override
  Future<LocalWeather> current(WeatherCity city, DateTime now) async =>
      throw const SocketException('Offline widget test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final manrope = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    final editorial = FontLoader('Editorial')
      ..addFont(rootBundle.load('assets/fonts/DMSerifDisplay-Italic.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([manrope.load(), editorial.load(), icons.load()]);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppearanceController controller() => AppearanceController(
    weatherSource: _OfflineWeather(),
    clock: () => DateTime(2026, 10, 12, 17),
  );

  Future<void> viewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(
    AppearanceController appearance,
    Widget Function(SunsetScene scene) child, {
    double scale = 1,
    bool disabled = true,
  }) => AppearanceScope(
    controller: appearance,
    child: ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.sunset(appearance.scene()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: disabled || appearance.reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child(appearance.scene()),
          ),
        ),
      ),
    ),
  );

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('welcome fits width $width at text scale $scale', (
        tester,
      ) async {
        await viewport(tester, Size(width, 1000));
        final appearance = controller();
        addTearDown(appearance.dispose);
        await tester.pumpWidget(
          host(
            appearance,
            (scene) => SunsetWelcome(
              scene: scene,
              onContinue: () {},
              onLibrary: () {},
              animate: false,
              weatherLabel: 'Kolkata · 24°C · Clear sky',
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Make room'), findsOneWidget);
        await tester.ensureVisible(find.byType(SunsetWindow));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings fit width $width at text scale $scale', (
        tester,
      ) async {
        await viewport(tester, Size(width, 1000));
        final appearance = controller();
        addTearDown(appearance.dispose);
        await tester.pumpWidget(
          host(
            appearance,
            (_) => SunsetSettings(appearance: appearance),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Try another atmosphere'));
        await tester.tap(find.text('Try another atmosphere'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Return to my day'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('welcome actions remain usable', (tester) async {
    await viewport(tester, const Size(390, 900));
    final appearance = controller();
    addTearDown(appearance.dispose);
    var continued = 0, library = 0;
    await tester.pumpWidget(
      host(
        appearance,
        (scene) => SunsetWelcome(
          scene: scene,
          animate: false,
          onContinue: () => continued++,
          onLibrary: () => library++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue studying'));
    await tester.tap(find.text('Explore library'));
    expect(continued, 1);
    expect(library, 1);
  });

  testWidgets('settings change season, reduce motion, and reset preview', (
    tester,
  ) async {
    await viewport(tester, const Size(390, 1000));
    final appearance = controller();
    addTearDown(appearance.dispose);
    await tester.pumpWidget(
      host(appearance, (_) => SunsetSettings(appearance: appearance)),
    );
    await tester.pumpAndSettle();

    final season = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(season);
    await tester.tap(season);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Winter').last);
    await tester.pumpAndSettle();
    expect(appearance.seasonOverride, StudySeason.winter);
    expect(appearance.scene().season, StudySeason.winter);

    await tester.ensureVisible(find.text('Reduce motion'));
    await tester.tap(find.text('Reduce motion'));
    await tester.pumpAndSettle();
    expect(appearance.reduceMotion, isTrue);
    await tester.tap(find.text('Reduce motion'));
    await tester.pumpAndSettle();
    expect(appearance.reduceMotion, isFalse);

    await tester.ensureVisible(find.text('Try another atmosphere'));
    await tester.tap(find.text('Try another atmosphere'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Slider));
    await tester.drag(find.byType(Slider), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(appearance.previewHour, isNotNull);

    final weather = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(weather);
    await tester.tap(weather);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snow').last);
    await tester.pumpAndSettle();
    expect(appearance.previewWeather, SkyWeather.snow);
    expect(appearance.scene().weather, SkyWeather.snow);

    await tester.ensureVisible(find.text('Return to my day'));
    await tester.tap(find.text('Return to my day'));
    await tester.pumpAndSettle();
    expect(appearance.previewing, isFalse);
    expect(appearance.previewHour, isNull);
    expect(appearance.previewWeather, isNull);
    expect(appearance.scene().hour, 17);
    expect(appearance.seasonOverride, StudySeason.winter);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'window suspends motion for accessibility, TickerMode, and lifecycle',
    (tester) async {
      const scene = SunsetScene(
        phase: DayPhase.golden,
        season: StudySeason.autumn,
      );
      Widget window({bool reduced = false, bool ticker = true}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: const SizedBox(
              width: 400,
              height: 370,
              child: SunsetWindow(scene: scene),
            ),
          ),
        ),
      );
      await tester.pumpWidget(window());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(window(reduced: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(window(ticker: false));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(window());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [
    (
      name: 'sunset-desktop-golden',
      size: const Size(1280, 680),
      scene: const SunsetScene(
        phase: DayPhase.golden,
        season: StudySeason.autumn,
      ),
    ),
    (
      name: 'sunset-phone-snowy-night',
      size: const Size(390, 930),
      scene: const SunsetScene(
        phase: DayPhase.night,
        season: StudySeason.winter,
        weather: SkyWeather.snow,
        hour: 22,
      ),
    ),
  ]) {
    testWidgets('capture ${sample.name}', (tester) async {
      await viewport(tester, sample.size);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.sunset(sample.scene),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(sample.size.width > 700 ? 64 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'study.',
                      style: TextStyle(
                        fontFamily: 'Editorial',
                        fontStyle: FontStyle.italic,
                        fontSize: 32,
                        color: sample.scene.palette.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SunsetWelcome(
                          scene: sample.scene,
                          animate: false,
                          onContinue: () {},
                          onLibrary: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('build/qa')..createSync(recursive: true);
        await File('${folder.path}/${sample.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
