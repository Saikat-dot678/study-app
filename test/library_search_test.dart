import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/models/library_entry.dart';
import 'package:study_app/storage/storage_bridge.dart';

void main() {
  late _FakeStorage storage;
  late LibraryController controller;

  setUp(() async {
    storage = _FakeStorage();
    controller = LibraryController(bridge: storage);
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test('ranked search supports fuzzy paths and type operators', () {
    final exact = controller.searchEntries('normalization');
    final typed = controller.searchEntries('type:pdf dbms');
    final fuzzy = controller.searchEntries('nrmlztn');

    expect(exact.first.name, 'Normalization.pdf');
    expect(typed, hasLength(1));
    expect(typed.single.kind, LibraryKind.pdf);
    expect(fuzzy.map((entry) => entry.name), contains('Normalization.pdf'));
  });

  test(
    'favorites, pins and reading progress persist through metadata bridge',
    () async {
      final folder = storage.entries.first;
      final file = storage.entries.last;

      await controller.togglePin(folder);
      await controller.toggleFavorite(file);
      await controller.saveProgress(file, page: 7, pageCount: 10);

      expect(controller.pinnedFolders.single.path, folder.path);
      expect(controller.favoriteEntries.single.path, file.path);
      expect(controller.progressFor(file.path)?.fraction, 0.7);
      expect(storage.metadata['pins'], contains(folder.path));
      expect(storage.metadata['favorites'], contains(file.path));
    },
  );
}

class _FakeStorage extends StorageBridge {
  final entries = <LibraryEntry>[
    LibraryEntry(
      name: 'DBMS',
      path: 'Semester 5/DBMS',
      isDirectory: true,
      mime: null,
      size: 0,
      lastModified: DateTime(2026),
    ),
    LibraryEntry(
      name: 'Operating Systems.txt',
      path: 'Semester 5/OS/Operating Systems.txt',
      isDirectory: false,
      mime: 'text/plain',
      size: 100,
      lastModified: DateTime(2026),
    ),
    LibraryEntry(
      name: 'Normalization.pdf',
      path: 'Semester 5/DBMS/Normalization.pdf',
      isDirectory: false,
      mime: 'application/pdf',
      size: 100,
      lastModified: DateTime(2026),
    ),
  ];

  Map<String, dynamic> metadata = {};

  @override
  Future<LibraryState> getState() async =>
      const LibraryState(connected: true, name: 'Test');

  @override
  Future<List<LibraryEntry>> listEntries(String path) async =>
      entries.where((entry) => entry.path.split('/').length == 1).toList();

  @override
  Future<List<LibraryEntry>> search(String query) async => entries;

  @override
  Future<Map<String, dynamic>> readMetadata() async => metadata;

  @override
  Future<void> writeMetadata(Map<String, dynamic> value) async {
    metadata = value;
  }
}
