import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/command_palette.dart';
import 'package:study_app/ui/filing_sheet.dart';
import 'package:study_app/ui/home_page.dart';
import 'package:study_app/ui/library_page.dart';
import 'package:study_app/ui/search_page.dart';
import 'package:study_app/ui/study_shell.dart';

import 'workspace_test.dart' show MemoryStorage, item;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    while (directory.parent.path != directory.path) {
      final fonts = Directory(
        '${directory.path}/bin/cache/artifacts/material_fonts',
      );
      if (fonts.existsSync()) {
        for (final pair in [
          ('Roboto', 'roboto-regular.ttf'),
          ('Ahem', 'roboto-regular.ttf'),
          ('MaterialIcons', 'materialicons-regular.otf'),
        ]) {
          final loader = FontLoader(pair.$1)
            ..addFont(
              File('${fonts.path}/${pair.$2}')
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        }
        break;
      }
      directory = directory.parent;
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('desktop_drop'),
          (_) async => true,
        );
  });
  final capture = GlobalKey();
  Future<void> render(
    WidgetTester tester,
    Widget page,
    Size size,
    double scale,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark.copyWith(
          textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          filledButtonTheme: FilledButtonThemeData(
            style: AppTheme.dark.filledButtonTheme.style!.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: ColoredBox(
                color: AppTheme.dark.colorScheme.surface,
                child: page,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '${page.runtimeType} $size scale $scale',
    );
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final image =
          await (capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Home, hierarchy and search fit phone through desktop with scaled text',
    (tester) async {
      final storage = MemoryStorage();
      final controller = LibraryController(bridge: storage);
      await controller.initialize();
      await controller.recordOpened(storage.files.last);
      await controller.toggleStar(storage.files[1]);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 768.0, 1280.0, 1920.0]) {
        for (final scale in [1.0, 1.8]) {
          final size = Size(width, width < 700 ? 800 : 900);
          for (final page in [
            HomePage(
              controller: controller,
              openLibrary: (_) {},
              openSearch: () {},
            ),
            LibraryPage(controller: controller),
            SearchPage(controller: controller, openLibrary: (_) {}),
          ]) {
            await render(tester, page, size, scale);
          }
        }
      }
      await render(
        tester,
        HomePage(
          controller: controller,
          openLibrary: (_) {},
          openSearch: () {},
        ),
        const Size(1280, 900),
        1,
      );
      await screenshot(tester, 'study-desk');
    },
  );

  testWidgets(
    'Material grids and complete shell respect narrow windows and text scaling',
    (tester) async {
      final storage = MemoryStorage();
      storage.files.addAll([
        item('GATE 2027', folder: true),
        item('Research', folder: true),
        item('Research/Mesh paper.pdf'),
      ]);
      final controller = LibraryController(bridge: storage);
      await controller.initialize();
      await controller.toggleStar(storage.files[1]);
      await controller.recordOpened(storage.files.last);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await controller.openFolder('Semester 5/DBMS');
      controller.gridMode = true;
      for (final width in [320.0, 768.0, 1280.0]) {
        await render(
          tester,
          LibraryPage(controller: controller),
          Size(width, 720),
          1.8,
        );
        await render(
          tester,
          StudyShell(controller: controller),
          Size(width, 720),
          1.8,
        );
      }
      for (final width in [390.0, 1280.0]) {
        await render(
          tester,
          StudyShell(controller: controller),
          Size(width, 900),
          1,
        );
        await screenshot(tester, 'workspace-${width.toInt()}');
      }
    },
  );

  testWidgets(
    'Desktop Ctrl and Shift selection, select all and context menu work',
    (tester) async {
      final storage = MemoryStorage()..files.add(item('Syllabus.pdf'));
      final controller = LibraryController(bridge: storage);
      await controller.initialize();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(
        tester,
        LibraryPage(controller: controller),
        const Size(1280, 900),
        1,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Inbox'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsWidgets);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Semester 5'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsWidgets);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Syllabus.pdf'), buttons: 2);
      await tester.pumpAndSettle();
      expect(find.text('Star'), findsOneWidget);
      await tester.tap(find.text('Star'));
      await tester.pumpAndSettle();
      expect(controller.metadata.starred, contains('Syllabus.pdf'));
    },
  );
  testWidgets('System back navigates to the parent folder before Home', (
    tester,
  ) async {
    final controller = LibraryController(bridge: MemoryStorage());
    await controller.initialize();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      StudyShell(controller: controller),
      const Size(390, 800),
      1,
    );
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await controller.openFolder('Semester 5/DBMS');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.currentPath, 'Semester 5');
  });

  testWidgets('Search stays lazy with 6000 files and accepts unordered words', (
    tester,
  ) async {
    final storage = MemoryStorage();
    storage.files.addAll(
      List.generate(6000, (i) => item('Semester 5/Notes/DBMS $i.pdf')),
    );
    final controller = LibraryController(bridge: storage);
    await controller.initialize();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      SearchPage(controller: controller, openLibrary: (_) {}),
      const Size(1280, 800),
      1,
    );
    expect(find.byType(ListTile).evaluate().length, lessThan(50));
    await tester.enterText(find.byType(TextField), '5999 semester type:pdf');
    await tester.pumpAndSettle();
    expect(find.text('DBMS 5999.pdf'), findsOneWidget);
    expect(find.text('1 result'), findsOneWidget);
  });

  testWidgets(
    'Bulk filing previews custom category and keyboard palette executes',
    (tester) async {
      final controller = LibraryController(bridge: MemoryStorage());
      await controller.initialize();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var searched = false;
      await render(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showFilingSheet(
                  context,
                  controller,
                  initialPath: 'Semester 5/DBMS',
                  moving: [item('Inbox/Lecture.mp4')],
                ),
                child: const Text('File batch'),
              ),
              TextButton(
                onPressed: () => showCommandPalette(
                  context,
                  controller,
                  openFolder: (_) {},
                  openSearch: () => searched = true,
                  openSettings: () {},
                ),
                child: const Text('Commands'),
              ),
            ],
          ),
        ),
        const Size(390, 800),
        1,
      );
      await tester.tap(find.text('File batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('To: Semester 5/DBMS/Notes'), findsOneWidget);
      await tester.tap(find.text('Move here'));
      await tester.pumpAndSettle();
      expect(
        controller.allEntries.any(
          (e) => e.path == 'Semester 5/DBMS/Notes/Lecture.mp4',
        ),
        isTrue,
      );
      await tester.tap(find.text('Commands'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Import material'))
            .selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Search library'))
            .selected,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'Search library');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(searched, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
