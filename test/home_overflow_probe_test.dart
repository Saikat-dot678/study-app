import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/models/library_entry.dart';
import 'package:study_app/models/study_metadata.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/study_dashboard.dart';
import 'package:study_app/workspace/study_workspace_controller.dart';

void main() {
  testWidgets('narrow Home throws a FlutterError', (tester) async {
    final details = await _overflowDetails(tester);
    expect(details, isNotEmpty);
  });

  for (final marker in [
    '_HomeHeader',
    '_ActiveStudy',
    '_TodayPanel',
    '_QuickActions',
    '_SectionHeading',
    '_RecentGrid',
    '_RecentRow',
    '_SpacesStrip',
    '_SpaceRow',
    '_CreateSpace',
  ]) {
    testWidgets('overflow details contain $marker', (tester) async {
      final details = await _overflowDetails(tester);
      expect(details, contains(marker));
    });
  }
}

Future<String> _overflowDetails(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = _controller();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: StudyDashboard(
          controller: controller,
          workspace: StudyWorkspaceController.instance,
          openLibrary: (_) {},
          openGoals: () {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  final exception = tester.takeException();
  expect(exception, isA<FlutterError>());
  return (exception! as FlutterError).toStringDeep();
}

LibraryController _controller() {
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
