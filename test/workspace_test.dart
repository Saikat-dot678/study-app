import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/models/library_entry.dart';
import 'package:study_app/models/library_metadata.dart';
import 'package:study_app/models/library_query.dart';
import 'package:study_app/storage/storage_bridge.dart';

LibraryEntry item(String path, {bool folder = false}) => LibraryEntry.fromMap({
  'name': path.split('/').last,
  'path': path,
  'isDirectory': folder,
});

class MemoryStorage extends StorageBridge {
  List<LibraryEntry> files = [
    item('Inbox', folder: true),
    item('Semester 5', folder: true),
    item('Semester 5/DBMS', folder: true),
    item('Semester 5/DBMS/Normalization.pdf'),
    item('Inbox/Lecture.mp4'),
  ];
  List<String> snapshots = [];
  String? failMove;
  Completer<void>? listing;
  @override
  Future<LibraryState> getState() async =>
      const LibraryState(connected: true, name: 'Test library');
  @override
  Future<List<String>> readMetadata() async => snapshots;
  @override
  Future<void> writeMetadata(String json, int revision) async {
    snapshots = [json];
  }

  @override
  Future<List<LibraryEntry>> search(String query) async => files.toList();
  @override
  Future<List<LibraryEntry>> listEntries(String path) async {
    await listing?.future;
    return files
        .where(
          (e) =>
              (e.path.contains('/')
                  ? e.path.substring(0, e.path.lastIndexOf('/'))
                  : '') ==
              path,
        )
        .toList();
  }

  @override
  Future<bool> createFolder(String parent, String name) async {
    final path = parent.isEmpty ? name : '$parent/$name';
    if (files.any((e) => e.path == path)) return false;
    files.add(item(path, folder: true));
    return true;
  }

  @override
  Future<bool> move(String source, String destination) async {
    if (source == failMove) throw StateError('Provider refused');
    final file = files.firstWhere((e) => e.path == source);
    files.remove(file);
    files.add(item('$destination/${file.name}', folder: file.isDirectory));
    return true;
  }

  @override
  Future<bool> delete(String path) async {
    files.removeWhere((e) => e.path == path);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Search combines words, extensions, kinds and stars', () {
    final entry = item('Semester 5/DBMS/Normalization.pdf');
    expect(
      LibraryQuery('normalization semester type:pdf').matches(entry),
      isTrue,
    );
    expect(LibraryQuery('type:video').matches(entry), isFalse);
    expect(LibraryQuery('is:starred DBMS').matches(entry), isFalse);
    expect(
      LibraryQuery('is:starred DBMS').matches(entry, starred: true),
      isTrue,
    );
  });
  test('Portable metadata remaps only the selected subtree', () {
    final metadata = LibraryMetadata()
      ..starred.addAll(['OS', 'OS/Notes/a.pdf', 'OS2/a.pdf'])
      ..opened['OS/Notes/a.pdf'] = 42;
    metadata.positions['OS/Notes/a.pdf'] = 12;
    metadata.rememberDestination('OS/Notes');
    metadata.relocate('OS', 'Semester/OS');
    final restored = LibraryMetadata.decode(metadata.encode());
    expect(
      restored.starred,
      containsAll(['Semester/OS', 'Semester/OS/Notes/a.pdf', 'OS2/a.pdf']),
    );
    expect(restored.positions['Semester/OS/Notes/a.pdf'], 12);
    restored.relocate('Semester', null);
    expect(restored.starred, {'OS2/a.pdf'});
    expect(restored.destinations, isEmpty);
  });
  test(
    'History follows opens and recovers from an interrupted snapshot',
    () async {
      final storage = MemoryStorage();
      final state = LibraryMetadata()
        ..revision = 7
        ..starred.add('Semester 5');
      storage.snapshots = [state.encode(), '{broken'];
      final controller = LibraryController(bridge: storage);
      await controller.initialize();
      expect(controller.starredEntries.single.path, 'Semester 5');
      expect(controller.recentFiles, isEmpty);
      await controller.recordOpened(storage.files.last);
      expect(controller.recentFiles.single.path, 'Inbox/Lecture.mp4');
      expect(controller.materialCountUnder('Semester 5'), 1);
      controller.dispose();
    },
  );
  test(
    'Partial bulk moves refresh the screen and preserve failed references',
    () async {
      final storage = MemoryStorage()
        ..failMove = 'Semester 5/DBMS/Normalization.pdf';
      final controller = LibraryController(bridge: storage);
      await controller.initialize();
      final files = storage.files.where((e) => !e.isDirectory).toList();
      for (final entry in files) {
        await controller.toggleStar(entry);
      }
      await controller.moveEntries(files, 'Semester 5');
      expect(controller.error, contains('Moved 1 of 2'));
      expect(
        controller.allEntries.any((e) => e.path == 'Inbox/Lecture.mp4'),
        isFalse,
      );
      expect(
        controller.metadata.starred,
        containsAll([
          'Semester 5/Lecture.mp4',
          'Semester 5/DBMS/Normalization.pdf',
        ]),
      );
      controller.dispose();
    },
  );
  test(
    'Rapid folder navigation cannot replace a newer path with stale entries',
    () async {
      final storage = MemoryStorage();
      final controller = LibraryController(bridge: storage);
      await controller.initialize();
      storage.listing = Completer<void>();
      final first = controller.openFolder('Semester 5');
      final second = controller.openFolder('Inbox');
      storage.listing!.complete();
      await Future.wait([first, second]);
      expect(controller.currentPath, 'Inbox');
      expect(controller.entries.single.path, 'Inbox/Lecture.mp4');
      controller.dispose();
    },
  );
  group('Desktop real filesystem', () {
    late Directory root;
    late StorageBridge storage;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('study-qa-');
      SharedPreferences.setMockInitialValues({
        'desktop_library_root': root.path,
      });
      storage = StorageBridge();
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });
    test(
      'Dropped files copy safely, keep originals and report partial failures',
      () async {
        final source = await File('${root.path}/source.txt')
            .writeAsString('lecture');
        await storage.createFolder('', 'Inbox');
        final imported = await storage.importPaths([
          source.path,
          source.path,
        ], 'Inbox');
        expect(imported, ['source.txt']);
        await storage.importPaths([source.path], 'Inbox');
        expect(
          await File('${root.path}/Inbox/source (2).txt').readAsString(),
          'lecture',
        );
        await expectLater(
          storage.importPaths([
            source.path,
            '${root.path}/missing.txt',
          ], 'Inbox'),
          throwsStateError,
        );
        expect(await source.readAsString(), 'lecture');
        expect(
          await File('${root.path}/Inbox/source (3).txt').readAsString(),
          'lecture',
        );
      },
    );
    test(
      'Deep folders, notes, conflicts, moves, rename and delete keep contents',
      () async {
        var parent = '';
        for (var i = 0; i < 30; i++) {
          expect(await storage.createFolder(parent, 'd'), isTrue);
          parent = parent.isEmpty ? 'd' : '$parent/d';
        }
        await storage.createNote(parent, 'Revision', '- [ ] Transactions');
        final note = (await storage.listEntries(parent)).single;
        expect(
          await File(await storage.prepareEntry(note.path)).readAsString(),
          contains('Transactions'),
        );
        expect(await storage.move(note.path, parent), isTrue);
        expect((await storage.listEntries(parent)).single.name, note.name);
        await storage.createFolder('', 'Filed');
        await storage.move(note.path, 'Filed');
        expect(await storage.rename('Filed/${note.name}', 'Exam.md'), isTrue);
        await storage.createNote('', 'Exam', 'original');
        await expectLater(storage.move('Exam.md', 'Filed'), throwsStateError);
        expect(
          await File(await storage.prepareEntry('Exam.md')).readAsString(),
          contains('original'),
        );
        expect(await storage.delete('Filed/Exam.md'), isTrue);
        expect(await storage.delete(''), isFalse);
        expect(await storage.delete('.studyapp'), isFalse);
        expect(await storage.rename('.studyapp', 'Metadata'), isFalse);
        expect(await storage.move('.studyapp', 'Filed'), isFalse);
        await expectLater(storage.delete('../outside'), throwsStateError);
        await expectLater(storage.createFolder('', '..'), throwsStateError);
      },
    );
    test(
      'Index includes more than 5000 entries and hides optional metadata',
      () async {
        // Empty fixtures exercise enumeration without loading any media bytes.
        for (var i = 0; i < 5100; i++) {
          await File('${root.path}/file$i.txt').writeAsString('');
        }
        await storage.writeMetadata(
          (LibraryMetadata()..revision = 1).encode(),
          1,
        );
        expect((await storage.search('')).length, 5100);
        expect((await storage.readMetadata()).length, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
    test(
      'Metadata snapshots remain readable after library is copied',
      () async {
        final metadata = LibraryMetadata()
          ..revision = 1
          ..starred.add('Semester/Notes.pdf');
        await storage.writeMetadata(metadata.encode(), 1);
        metadata.revision = 2;
        await storage.writeMetadata(metadata.encode(), 2);
        final snapshots = await storage.readMetadata();
        expect(snapshots.length, 2);
        expect(
          snapshots
              .map(LibraryMetadata.decode)
              .every((m) => m.starred.contains('Semester/Notes.pdf')),
          isTrue,
        );
        final copy = await Directory.systemTemp.createTemp('study-copy-qa-');
        try {
          await Directory('${copy.path}/.studyapp').create();
          for (var slot = 0; slot < 2; slot++) {
            await File('${root.path}/.studyapp/workspace-$slot.json')
                .copy('${copy.path}/.studyapp/workspace-$slot.json');
          }
          await Directory('${copy.path}/Semester').create();
          await File('${copy.path}/Semester/Notes.pdf')
              .writeAsString('portable fixture');
          SharedPreferences.setMockInitialValues({
            'desktop_library_root': copy.path,
          });
          final reconnected = LibraryController();
          await reconnected.initialize();
          expect(reconnected.starredEntries.single.path, 'Semester/Notes.pdf');
          reconnected.dispose();
        } finally {
          await copy.delete(recursive: true);
        }
      },
    );
  });
}
