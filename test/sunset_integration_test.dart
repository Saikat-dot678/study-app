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
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/models/library_entry.dart';
import 'package:study_app/models/study_metadata.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/study_shell.dart';
import 'package:study_app/ui/sunset_settings.dart';
import 'package:study_app/ui/sunset_window.dart';
import 'package:study_app/workspace/study_workspace_controller.dart';

class _OfflineWeather implements WeatherSource {
  @override
  void cancel() {}
  @override
  void dispose() {}
  @override
  Future<List<WeatherCity>> search(String query) async => [];
  @override
  Future<LocalWeather> current(WeatherCity city, DateTime now) async =>
      throw const SocketException('Offline integration test');
}

LibraryController _library(bool connected) {
  final controller = LibraryController()
    ..initialized = true
    ..connected = connected
    ..libraryName = 'Study Library';
  if (!connected) return controller;
  final folders = [
    for (final name in ['Semester 5', 'Personal reading', 'Projects'])
      LibraryEntry(
        name: name,
        path: name,
        isDirectory: true,
        mime: null,
        size: 0,
        lastModified: DateTime(2026, 9, 1),
      ),
  ];
  final notes = [
    for (final name in [
      'Database normalization.pdf',
      'Linear algebra.pdf',
      'Design systems.pdf',
    ])
      LibraryEntry(
        name: name,
        path: 'Semester 5/$name',
        isDirectory: false,
        mime: 'application/pdf',
        size: 1200000,
        lastModified: DateTime(2026, 9, 1),
      ),
  ];
  controller
    ..entries = folders
    ..allEntries = [...folders, ...notes]
    ..metadata = StudyMetadata(
      favorites: {notes.first.path},
      pins: {folders.first.path},
      progress: {
        notes.first.path: StudyProgress(
          path: notes.first.path,
          lastOpened: DateTime(2026, 9, 20, 14),
          page: 18,
          pageCount: 64,
        ),
      },
    );
  return controller;
}

void _noException(WidgetTester tester) {
  final error = tester.takeException();
  if (error case FlutterError flutterError) fail(flutterError.toStringDeep());
  expect(error, isNull);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('build/qa')..createSync(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'Editorial': 'assets/fonts/DMSerifDisplay-Italic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    };
    await Future.wait([
      for (final font in fonts.entries)
        (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load(),
    ]);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final connected in [true, false]) {
    for (final viewport in [
      (size: const Size(320, 900), scale: 1.0),
      (size: const Size(390, 1000), scale: 1.8),
      (size: const Size(1280, 900), scale: 1.0),
    ]) {
      testWidgets(
        'scoped shell connected=$connected at ${viewport.size.width}, scale ${viewport.scale}',
        (tester) async {
          tester.view.physicalSize = viewport.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appearance = AppearanceController(
            weatherSource: _OfflineWeather(),
            clock: () => DateTime(2026, 10, 12, 17),
          );
          final library = _library(connected);
          addTearDown(appearance.dispose);
          addTearDown(library.dispose);
          final workspace = StudyWorkspaceController.instance;
          await workspace.initialize();
          workspace
            ..tasks = [
              StudyTask(
                id: 'revision',
                title: 'Review database normalization',
                dueDate: StudyWorkspaceController.dateOnly(DateTime.now()),
                createdAt: DateTime.now(),
                estimatedMinutes: 40,
                priority: StudyPriority.high,
              ),
            ]
            ..goals = [];
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            AppearanceScope(
              controller: appearance,
              child: ListenableBuilder(
                listenable: appearance,
                builder: (context, _) => MaterialApp(
                  theme: AppTheme.sunset(appearance.scene()),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(viewport.scale),
                    ),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: captureKey,
                    child: StudyShell(
                      libraryController: library,
                      workspaceController: workspace,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          _noException(tester);
          expect(find.byType(SunsetWindow), findsOneWidget);
          expect(
            find.text(
              connected ? 'Make room' : 'Your library starts with a folder.',
            ),
            findsOneWidget,
          );
          await _capture(
            tester,
            captureKey,
            'sunset-app-${connected ? 'connected' : 'disconnected'}-${viewport.size.width.toInt()}',
          );

          final stack = find.byWidgetPredicate(
            (widget) => widget is IndexedStack && widget.children.length == 5,
          );
          Future<void> tab(int index) async {
            final labels = [
              'Home',
              'Library',
              viewport.size.width >= 1120 ? 'Goals & Calendar' : 'Goals',
              'Search',
              'Settings',
            ];
            final navigation = viewport.size.width < 720
                ? find.descendant(
                    of: find.byType(NavigationBar),
                    matching: find.text(labels[index]),
                  )
                : find.text(labels[index]).first;
            await tester.tap(navigation);
            await tester.pumpAndSettle();
            expect(tester.widget<IndexedStack>(stack).index, index);
            _noException(tester);
          }

          await tab(1);
          if (connected) {
            expect(
              find.text('Your spaces, folders and materials'),
              findsOneWidget,
            );
          }
          await tab(2);
          expect(find.text('Plan less.\nFinish more.'), findsOneWidget);
          await tab(3);
          if (connected) {
            await tester.enterText(
              find.byType(TextField).first,
              'normalization',
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<TextField>(find.byType(TextField).first)
                  .controller!
                  .text,
              'normalization',
            );
          }
          await tab(4);
          expect(find.byType(SunsetSettings), findsOneWidget);
          appearance.setPreviewHour(22);
          appearance.setPreviewWeather(SkyWeather.snow);
          await tester.pumpAndSettle();
          expect(tester.widget<IndexedStack>(stack).index, 4);
          expect(
            Theme.of(tester.element(find.byType(SunsetSettings))).brightness,
            Brightness.dark,
          );
          _noException(tester);

          await tab(3);
          if (connected) {
            expect(
              tester
                  .widget<TextField>(find.byType(TextField).first)
                  .controller!
                  .text,
              'normalization',
            );
          }
          await tab(0);
          expect(
            tester
                .widget<SunsetWindow>(find.byType(SunsetWindow))
                .scene
                .weather,
            SkyWeather.snow,
          );
          expect(
            tester.widget<SunsetWindow>(find.byType(SunsetWindow)).scene.phase,
            DayPhase.night,
          );
          appearance.clearPreview();
          await tester.pumpAndSettle();
          expect(tester.widget<IndexedStack>(stack).index, 0);
          expect(
            tester.widget<SunsetWindow>(find.byType(SunsetWindow)).scene.phase,
            DayPhase.golden,
          );
          if (connected) {
            expect(
              library.metadata.favorites,
              contains('Semester 5/Database normalization.pdf'),
            );
            expect(
              library
                  .metadata
                  .progress['Semester 5/Database normalization.pdf']!
                  .page,
              18,
            );
          }
          _noException(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('hidden Home stops drawing and resumes when selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appearance = AppearanceController(weatherSource: _OfflineWeather());
    final library = _library(true);
    addTearDown(appearance.dispose);
    addTearDown(library.dispose);
    await tester.pumpWidget(
      AppearanceScope(
        controller: appearance,
        child: MaterialApp(
          theme: AppTheme.sunset(appearance.scene()),
          home: StudyShell(libraryController: library),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    final window = tester.element(
      find.byType(SunsetWindow, skipOffstage: false),
    );
    expect(TickerMode.valuesOf(window).enabled, isFalse);
    await tester.tap(find.text('Home').first);
    await tester.pump(const Duration(seconds: 1));
    expect(TickerMode.valuesOf(window).enabled, isTrue);
    expect(tester.binding.hasScheduledFrame, isTrue);
    _noException(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
