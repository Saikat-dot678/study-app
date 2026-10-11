import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/models/library_entry.dart';
import 'package:study_app/models/study_metadata.dart';
import 'package:study_app/storage/storage_bridge.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/study_shell.dart';
import 'package:study_app/viewers/viewer_page.dart';
import 'package:study_app/workspace/study_workspace_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final size in const [
    Size(430, 780),
    Size(719, 760),
    Size(720, 760),
    Size(819, 760),
    Size(820, 760),
    Size(1119, 760),
    Size(1120, 760),
    Size(1600, 900),
  ]) {
    testWidgets('real shell is stable at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _library();
      addTearDown(controller.dispose);
      final workspace = StudyWorkspaceController.instance;
      workspace
        ..tasks = [
          StudyTask(
            id: 'today',
            title: 'Review database normalization',
            dueDate: StudyWorkspaceController.dateOnly(DateTime.now()),
            createdAt: DateTime.now(),
            estimatedMinutes: 40,
            priority: StudyPriority.high,
          ),
        ]
        ..goals = [
          StudyGoal(
            id: 'goal',
            title: 'Finish DBMS revision',
            dueDate: DateTime.now().add(const Duration(days: 10)),
            createdAt: DateTime.now(),
            targetMinutes: 300,
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudyShell(
            libraryController: controller,
            workspaceController: workspace,
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectNoFlutterException(tester, 'initial shell at ${size.width}x${size.height}');

      await _selectDestination(tester, 1, 'Library');
      expect(find.text('Your spaces, folders and materials'), findsOneWidget);
      _expectNoFlutterException(tester, 'Library at ${size.width}x${size.height}');

      await _selectDestination(
        tester,
        2,
        size.width >= 1120 ? 'Goals & Calendar' : 'Goals',
      );
      expect(find.text('Plan less.\nFinish more.'), findsOneWidget);
      _expectNoFlutterException(tester, 'Goals at ${size.width}x${size.height}');

      await _selectDestination(tester, 0, 'Home');
      expect(find.text('Review database normalization'), findsWidgets);
      _expectNoFlutterException(tester, 'Home return at ${size.width}x${size.height}');
    });
  }

  testWidgets('rapid mouse movement and live resize do not destabilize Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _library(materialCount: 250);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: StudyShell(
          libraryController: controller,
          workspaceController: StudyWorkspaceController.instance,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(300, 140));
    for (var i = 0; i < 80; i++) {
      await mouse.moveTo(Offset(285 + (i * 83) % 850, 130 + (i * 47) % 560));
      await tester.pump(const Duration(milliseconds: 2));
    }

    for (final size in const [
      Size(700, 720),
      Size(720, 720),
      Size(900, 650),
      Size(1119, 760),
      Size(1120, 760),
      Size(430, 780),
      Size(1280, 800),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      _expectNoFlutterException(
        tester,
        'after live resize to ${size.width}x${size.height}',
      );
    }
    await mouse.removePointer();
    _expectNoFlutterException(tester, 'after removing mouse pointer');
  });

  testWidgets('shell supports disconnected state and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LibraryController()
      ..initialized = true
      ..connected = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: StudyShell(
          libraryController: controller,
          workspaceController: StudyWorkspaceController.instance,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your library starts with a folder.'), findsOneWidget);
    _expectNoFlutterException(tester);

    tester.view.physicalSize = const Size(1120, 900);
    await tester.pumpAndSettle();
    expect(find.text('Your library starts with a folder.'), findsOneWidget);
    _expectNoFlutterException(tester);
  });

  testWidgets('reader handles an empty prepared path without a null crash', (
    tester,
  ) async {
    final controller = LibraryController(bridge: _EmptyPreparedPathStorage())
      ..initialized = true
      ..connected = true;
    addTearDown(controller.dispose);
    final entry = LibraryEntry(
      name: 'notes.md',
      path: 'Notes/notes.md',
      isDirectory: false,
      mime: 'text/markdown',
      size: 42,
      lastModified: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StudyViewerPage(controller: controller, entry: entry),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The material could not be prepared in the local reader cache.',
      ),
      findsOneWidget,
    );
    _expectNoFlutterException(tester);
  });
}

Future<void> _selectDestination(
  WidgetTester tester,
  int index,
  String fallbackLabel,
) async {
  final railFinder = find.byType(NavigationRail);
  if (railFinder.evaluate().isNotEmpty) {
    final rail = tester.widget<NavigationRail>(railFinder.first);
    rail.onDestinationSelected?.call(index);
    await tester.pumpAndSettle();
    return;
  }

  final barFinder = find.byType(NavigationBar);
  if (barFinder.evaluate().isNotEmpty) {
    final bar = tester.widget<NavigationBar>(barFinder.first);
    bar.onDestinationSelected?.call(index);
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(find.text(fallbackLabel).first);
  await tester.pumpAndSettle();
}

void _expectNoFlutterException(WidgetTester tester, [String? context]) {
  final error = tester.takeException();
  if (error case FlutterError flutterError) {
    final prefix = context == null ? '' : '$context\n';
    fail('$prefix${flutterError.toStringDeep()}');
  }
  expect(error, isNull, reason: context);
}

LibraryController _library({int materialCount = 40}) {
  final controller = LibraryController()
    ..initialized = true
    ..connected = true
    ..libraryName = 'Study Library';
  final spaces = List.generate(
    16,
    (index) => LibraryEntry(
      name: 'Space ${index + 1}',
      path: 'Space ${index + 1}',
      isDirectory: true,
      mime: null,
      size: 0,
      lastModified: DateTime(2026, 9, 1),
    ),
  );
  final materials = List.generate(materialCount, (index) {
    final space = spaces[index % spaces.length];
    return LibraryEntry(
      name: 'Topic ${index + 1}.pdf',
      path: '${space.path}/Unit ${index % 9}/Topic ${index + 1}.pdf',
      isDirectory: false,
      mime: 'application/pdf',
      size: 120000 + index,
      lastModified: DateTime(2026, 9, 1),
    );
  });
  controller
    ..entries = spaces
    ..allEntries = [...spaces, ...materials]
    ..metadata = StudyMetadata(
      favorites: materials.take(3).map((entry) => entry.path).toSet(),
      pins: spaces.take(3).map((entry) => entry.path).toSet(),
      progress: {
        for (var i = 0; i < materials.length.clamp(0, 12); i++)
          materials[i].path: StudyProgress(
            path: materials[i].path,
            lastOpened: DateTime.now().subtract(Duration(hours: i)),
            page: i + 2,
            pageCount: 100,
          ),
      },
    );
  return controller;
}

class _EmptyPreparedPathStorage extends StorageBridge {
  @override
  Future<String> prepareEntry(String path) async => '';
}
