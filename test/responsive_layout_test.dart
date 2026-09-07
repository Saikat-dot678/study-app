import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/models/library_entry.dart';
import 'package:study_app/models/study_metadata.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/home_page.dart';
import 'package:study_app/ui/library_page.dart';

void main() {
  const sizes = [
    Size(360, 640),
    Size(412, 915),
    Size(800, 1000),
    Size(1366, 768),
    Size(1920, 1080),
  ];

  for (final size in sizes) {
    testWidgets(
      'home and library avoid layout errors at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = _populatedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: size.width <= 412
                    ? const TextScaler.linear(1.3)
                    : TextScaler.noScaling,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: HomePage(
                controller: controller,
                openLibrary: (_) {},
                openSearch: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: size.width <= 412
                    ? const TextScaler.linear(1.3)
                    : TextScaler.noScaling,
              ),
              child: child!,
            ),
            home: Scaffold(body: LibraryPage(controller: controller)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final libraryError = tester.takeException();
        if (libraryError case FlutterError error) {
          fail(error.toStringDeep());
        }
        expect(libraryError, isNull);
      },
    );
  }
}

LibraryController _populatedController() {
  final controller = LibraryController()
    ..initialized = true
    ..connected = true
    ..libraryName = 'Study Library';
  final entries = [
    LibraryEntry(
      name: 'Semester 5',
      path: 'Semester 5',
      isDirectory: true,
      mime: null,
      size: 0,
      lastModified: DateTime(2026),
    ),
    LibraryEntry(
      name: 'Normalization.pdf',
      path: 'Normalization.pdf',
      isDirectory: false,
      mime: 'application/pdf',
      size: 1200000,
      lastModified: DateTime(2026),
    ),
  ];
  controller
    ..entries = entries
    ..allEntries = [
      ...entries,
      LibraryEntry(
        name: 'DBMS',
        path: 'Semester 5/DBMS',
        isDirectory: true,
        mime: null,
        size: 0,
        lastModified: DateTime(2026),
      ),
    ]
    ..metadata = StudyMetadata(
      favorites: const {'Normalization.pdf'},
      pins: const {'Semester 5'},
      progress: {
        'Normalization.pdf': StudyProgress(
          path: 'Normalization.pdf',
          lastOpened: DateTime(2026, 9, 7),
          page: 42,
          pageCount: 120,
        ),
      },
    );
  return controller;
}
