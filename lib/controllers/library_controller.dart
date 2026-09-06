import 'package:flutter/foundation.dart';

import '../models/library_entry.dart';
import '../models/library_metadata.dart';
import '../storage/storage_bridge.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({StorageBridge? bridge})
    : _bridge = bridge ?? StorageBridge() {
    _bridge.onShareReceived = _onShareReceived;
  }

  final StorageBridge _bridge;
  LibraryMetadata metadata = LibraryMetadata();
  bool _metadataWritable = true;
  bool _disposed = false;
  Future<void> _operations = Future.value();
  Future<void> _metadataWrites = Future.value();
  final Map<String, int> _folderCounts = {},
      _fileCounts = {},
      _totalCounts = {};

  bool initialized = false;
  bool busy = false;
  bool connected = false;
  bool gridMode = false;
  String? libraryName;
  String currentPath = '';
  String? notice;
  String? error;
  List<LibraryEntry> entries = const [];
  List<LibraryEntry> allEntries = const [];

  Future<void> initialize() async {
    await _guard(() async {
      final state = await _bridge.getState();
      connected = state.connected;
      libraryName = state.name;
      if (connected) {
        await _loadMetadata();
        await _refreshCurrentInternal();
        await _refreshAllInternal();
      }
      if (state.pendingShares > 0) {
        notice =
            '${state.pendingShares} shared item(s) are waiting for a library folder.';
      }
    });
    initialized = true;
    notifyListeners();
  }

  Future<void> connectLibrary() async {
    await _guard(() async {
      await _metadataWrites;
      final state = await _bridge.pickLibraryFolder();
      connected = state.connected;
      libraryName = state.name;
      currentPath = '';
      if (connected) {
        await _loadMetadata();
        await _refreshCurrentInternal();
        await _refreshAllInternal();
        if (_metadataWritable) {
          notice = 'Library connected. Build any folder structure you want.';
        }
      }
    });
  }

  Future<void> forgetLibrary() async {
    await _guard(() async {
      await _metadataWrites;
      await _bridge.forgetLibrary();
      connected = false;
      libraryName = null;
      currentPath = '';
      entries = const [];
      allEntries = const [];
      metadata = LibraryMetadata();
      notice = 'Folder connection removed. No files were deleted.';
    });
  }

  Future<void> refresh() => _guard(() async {
    await _refreshCurrentInternal();
    await _refreshAllInternal();
  });

  Future<void> openFolder(String path) async {
    await _guard(() async {
      final values = await _bridge.listEntries(path);
      currentPath = path;
      entries = values;
    });
  }

  Future<void> goUp() async {
    if (currentPath.isEmpty) return;
    final slash = currentPath.lastIndexOf('/');
    await openFolder(slash < 0 ? '' : currentPath.substring(0, slash));
  }

  Future<void> openEntry(LibraryEntry entry) async {
    if (entry.isDirectory) {
      await openFolder(entry.path);
    } else {
      await openExternally(entry);
    }
  }

  Future<String> prepareForViewer(LibraryEntry entry) =>
      _bridge.prepareEntry(entry.path);

  Future<String> contentUri(LibraryEntry entry) => _bridge.entryUri(entry.path);

  Future<void> openExternally(LibraryEntry entry) async {
    await _guard(() => _bridge.open(entry.path));
  }

  Future<void> shareEntry(LibraryEntry entry) async {
    try {
      await _bridge.share(entry.path);
      if (_bridge.isDesktop) {
        notice = 'File path copied to clipboard.';
        notifyListeners();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<void> importFiles({String? destination}) async {
    await importOrganized(basePath: destination ?? currentPath);
  }

  /// Imports files into [basePath]. If [category] is supplied, Study creates
  /// or reuses that child folder first. This keeps classification local to the
  /// current study context rather than forcing global Books/Slides/etc roots.
  Future<void> importOrganized({
    required String basePath,
    String? category,
    List<String>? sourcePaths,
  }) async {
    await _guard(() async {
      var target = basePath;
      final bucket = category == null
          ? ''
          : StorageBridge.validateName(category);
      if (bucket.isNotEmpty) {
        final candidate = _join(basePath, bucket);
        final children = await _bridge.listEntries(basePath);
        final exists = children.any(
          (entry) => entry.isDirectory && entry.path == candidate,
        );
        if (!exists) {
          final created = await _bridge.createFolder(basePath, bucket);
          if (!created) {
            throw StateError('Could not create the $bucket folder here.');
          }
        }
        target = candidate;
      }

      final names = sourcePaths == null
          ? await _bridge.importFiles(target)
          : await _bridge.importPaths(sourcePaths, target);
      if (names.isNotEmpty) {
        metadata.rememberDestination(target);
        await _saveMetadata();
        final place = target.isEmpty ? 'Library root' : target;
        notice = 'Imported ${names.length} item(s) into $place.';
      }
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> createFolder(String name) => createFolderAt(currentPath, name);

  Future<void> createFolderAt(String parent, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _guard(() async {
      final ok = await _bridge.createFolder(parent, trimmed);
      if (!ok) {
        throw StateError(
          'Could not create folder. A folder with that name may already exist.',
        );
      }
      notice = 'Folder created.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  /// Creates a reusable study structure anywhere in the tree. Templates are
  /// intentionally shallow; users can keep nesting without an artificial cap.
  Future<void> createStructure({
    required String parent,
    required String name,
    List<String> children = const [],
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _guard(() async {
      StorageBridge.validateName(trimmed);
      for (final child in children) {
        StorageBridge.validateName(child);
      }
      final created = await _bridge.createFolder(parent, trimmed);
      if (!created) {
        throw StateError('A folder named $trimmed already exists here.');
      }
      final root = _join(parent, trimmed);
      for (final child in children) {
        final value = child.trim();
        if (value.isNotEmpty && !await _bridge.createFolder(root, value)) {
          throw StateError(
            '$trimmed was created, but $value could not be added. Check folder permissions.',
          );
        }
      }
      notice = children.isEmpty
          ? '$trimmed created.'
          : '$trimmed workspace created.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> createNote(String title, String body) {
    return createNoteAt(currentPath, title, body);
  }

  Future<void> createNoteAt(String target, String title, String body) async {
    await _guard(() async {
      final ok = await _bridge.createNote(target, title.trim(), body);
      if (!ok) throw StateError('Could not save note.');
      notice = 'Note saved locally.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> renameEntry(LibraryEntry entry, String newName) async {
    await _guard(() async {
      final ok = await _bridge.rename(entry.path, newName.trim());
      if (!ok) throw StateError('Could not rename item.');
      metadata.relocate(
        entry.path,
        _join(_parentOf(entry.path), newName.trim()),
      );
      await _saveMetadata();
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> moveEntry(LibraryEntry entry, String destination) async {
    await moveEntries([entry], destination);
  }

  Future<void> moveEntries(
    List<LibraryEntry> values,
    String destination,
  ) async {
    if (values.isEmpty) return;
    await _guard(() async {
      var moved = 0;
      final failures = <String>[];
      for (final entry in values) {
        try {
          if (await _bridge.move(entry.path, destination)) {
            moved++;
            metadata.relocate(entry.path, _join(destination, entry.name));
          } else {
            failures.add(entry.name);
          }
        } catch (_) {
          failures.add(entry.name);
        }
      }
      if (moved > 0) metadata.rememberDestination(destination);
      await _saveMetadata();
      notice = moved == 1 ? 'Item moved.' : '$moved items moved.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
      if (failures.isNotEmpty) {
        throw StateError(
          'Moved $moved of ${values.length}. Check destination conflicts or permissions for: ${failures.join(', ')}.',
        );
      }
    });
  }

  Future<void> deleteEntry(LibraryEntry entry) async {
    await deleteEntries([entry]);
  }

  Future<void> deleteEntries(List<LibraryEntry> values) async {
    if (values.isEmpty) return;
    await _guard(() async {
      var deleted = 0;
      for (final entry in values) {
        try {
          if (await _bridge.delete(entry.path)) {
            deleted++;
            metadata.relocate(entry.path, null);
          }
        } catch (_) {
          /* Continue other selected items, then report the count. */
        }
      }
      await _saveMetadata();
      notice = deleted == 1 ? 'Item deleted.' : '$deleted items deleted.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
      if (deleted != values.length) {
        throw StateError(
          'Deleted $deleted of ${values.length} items. Some items could not be deleted.',
        );
      }
    });
  }

  void setGridMode(bool value) {
    gridMode = value;
    notifyListeners();
  }

  void clearStatus() {
    notice = null;
    error = null;
    notifyListeners();
  }

  List<LibraryEntry> get recentFiles {
    final values = allEntries
        .where(
          (item) => !item.isDirectory && metadata.opened.containsKey(item.path),
        )
        .toList();
    values.sort((a, b) {
      final left = metadata.opened[a.path] ?? 0;
      final right = metadata.opened[b.path] ?? 0;
      return right.compareTo(left);
    });
    return values.take(8).toList();
  }

  List<LibraryEntry> get currentFolders =>
      entries.where((entry) => entry.isDirectory).toList();

  List<LibraryEntry> get currentMaterials =>
      entries.where((entry) => !entry.isDirectory).toList();

  /// Root folders are treated as user-defined spaces. Inbox is a system landing
  /// zone and is intentionally shown separately on Home.
  List<LibraryEntry> get rootSpaces {
    final values = allEntries
        .where(
          (entry) =>
              entry.isDirectory &&
              _parentOf(entry.path).isEmpty &&
              entry.name != 'Inbox',
        )
        .toList();
    values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  int countKind(LibraryKind kind) =>
      allEntries.where((item) => item.kind == kind).length;

  int directFolderCount(String path) => _folderCounts[path] ?? 0;

  int directMaterialCount(String path) => _fileCounts[path] ?? 0;

  int materialCountUnder(String path) {
    return _totalCounts[path] ?? 0;
  }

  List<String> get folderPaths {
    final values = allEntries
        .where((entry) => entry.isDirectory)
        .map((entry) => entry.path)
        .where((path) => path != '.studyapp' && !path.startsWith('.studyapp/'))
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['', ...values];
  }

  Future<void> _refreshCurrentInternal() async {
    if (!connected) return;
    entries = await _bridge.listEntries(currentPath);
    entries = [...entries]
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  Future<void> _refreshAllInternal() async {
    if (!connected) return;
    allEntries = await _bridge.search('');
    _folderCounts.clear();
    _fileCounts.clear();
    _totalCounts.clear();
    for (final entry in allEntries) {
      final counts = entry.isDirectory ? _folderCounts : _fileCounts;
      final parent = _parentOf(entry.path);
      counts[parent] = (counts[parent] ?? 0) + 1;
      if (!entry.isDirectory) {
        var path = parent;
        while (true) {
          _totalCounts[path] = (_totalCounts[path] ?? 0) + 1;
          if (path.isEmpty) break;
          path = _parentOf(path);
        }
      }
    }
  }

  Future<void> _onShareReceived(List<String> names) async {
    if (names.isNotEmpty) {
      notice = '${names.length} shared item(s) added to Inbox.';
    }
    // Do not await: Android may still be completing the folder picker callback.
    if (connected) refresh();
  }

  String _join(String parent, String child) =>
      parent.isEmpty ? child : '$parent/$child';

  String _parentOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  Future<void> _guard(Future<void> Function() action) {
    final operation = _operations.then((_) => _run(action));
    _operations = operation;
    return operation;
  }

  Future<void> moveOrganized(
    List<LibraryEntry> values,
    String destination,
    String category,
  ) async {
    var target = destination;
    if (category.isNotEmpty) {
      final name = StorageBridge.validateName(category);
      target = _join(destination, name);
      if (!folderPaths.contains(target)) {
        await createFolderAt(destination, name);
        if (error != null) return;
      }
    }
    await moveEntries(values, target);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      try {
        await _refreshCurrentInternal();
        await _refreshAllInternal();
      } catch (_) {
        /* Keep the original failure. */
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool isStarred(LibraryEntry entry) => metadata.starred.contains(entry.path);
  List<LibraryEntry> get starredEntries => allEntries.where(isStarred).toList();
  List<String> get recentDestinations =>
      metadata.destinations.where(folderPaths.contains).toList();

  Future<void> toggleStar(LibraryEntry entry) async {
    if (!metadata.starred.add(entry.path)) metadata.starred.remove(entry.path);
    notifyListeners();
    await _saveMetadata();
  }

  Future<void> recordOpened(LibraryEntry entry) async {
    metadata.opened[entry.path] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _saveMetadata();
  }

  int positionFor(String path) => metadata.positions[path] ?? 0;
  Future<void> savePosition(String path, int value) async {
    metadata.positions[path] = value < 0 ? 0 : value;
    await _saveMetadata();
  }

  Future<void> _loadMetadata() async {
    metadata = LibraryMetadata();
    _metadataWritable = true;
    try {
      final snapshots = await _bridge.readMetadata();
      final valid = <LibraryMetadata>[];
      for (final source in snapshots) {
        try {
          valid.add(LibraryMetadata.decode(source));
        } catch (_) {
          /* Try the other snapshot. */
        }
      }
      valid.sort((a, b) => b.revision.compareTo(a.revision));
      if (valid.isNotEmpty) metadata = valid.first;
      if (snapshots.isNotEmpty && valid.isEmpty) {
        throw const FormatException('Metadata is unreadable');
      }
    } catch (_) {
      _metadataWritable = false;
      notice = 'Files are available. Saved favorites/history could not be read; existing metadata is preserved.';
    }
  }

  Future<void> _saveMetadata() {
    if (!_metadataWritable || !connected) return Future.value();
    metadata.revision++;
    final revision = metadata.revision;
    final json = metadata.encode();
    _metadataWrites = _metadataWrites.then((_) async {
      if (!_metadataWritable) return;
      try {
        await _bridge.writeMetadata(json, revision);
      } catch (_) {
        _metadataWritable = false;
        notice = 'Files are safe. Favorites/history could not be saved to this folder.';
        notifyListeners();
      }
    });
    return _metadataWrites;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _bridge.onShareReceived = null;
    super.dispose();
  }
}
