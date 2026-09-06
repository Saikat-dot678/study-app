import 'package:flutter/foundation.dart';

import '../models/library_entry.dart';
import '../storage/storage_bridge.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({StorageBridge? bridge}) : _bridge = bridge ?? StorageBridge() {
    _bridge.onShareReceived = _onShareReceived;
  }

  final StorageBridge _bridge;

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
        await _refreshCurrentInternal();
        await _refreshAllInternal();
      }
      if (state.pendingShares > 0) {
        notice = '${state.pendingShares} shared item(s) are waiting for a library folder.';
      }
    });
    initialized = true;
    notifyListeners();
  }

  Future<void> connectLibrary() async {
    await _guard(() async {
      final state = await _bridge.pickLibraryFolder();
      connected = state.connected;
      libraryName = state.name;
      currentPath = '';
      if (connected) {
        await _refreshCurrentInternal();
        await _refreshAllInternal();
        notice = 'Library connected. Build any folder structure you want.';
      }
    });
  }

  Future<void> forgetLibrary() async {
    await _guard(() async {
      await _bridge.forgetLibrary();
      connected = false;
      libraryName = null;
      currentPath = '';
      entries = const [];
      allEntries = const [];
      notice = 'Folder connection removed. No files were deleted.';
    });
  }

  Future<void> refresh() => _guard(() async {
        await _refreshCurrentInternal();
        await _refreshAllInternal();
      });

  Future<void> openFolder(String path) async {
    currentPath = path;
    await _guard(_refreshCurrentInternal);
  }

  Future<void> goUp() async {
    if (currentPath.isEmpty) return;
    final slash = currentPath.lastIndexOf('/');
    currentPath = slash < 0 ? '' : currentPath.substring(0, slash);
    await _guard(_refreshCurrentInternal);
  }

  Future<void> openEntry(LibraryEntry entry) async {
    if (entry.isDirectory) {
      await openFolder(entry.path);
    } else {
      await openExternally(entry);
    }
  }

  Future<String> prepareForViewer(LibraryEntry entry) => _bridge.prepareEntry(entry.path);

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
  }) async {
    await _guard(() async {
      var target = basePath;
      final bucket = category?.trim() ?? '';
      if (bucket.isNotEmpty) {
        final candidate = _join(basePath, bucket);
        final exists = allEntries.any((entry) => entry.isDirectory && entry.path == candidate);
        if (!exists) {
          final created = await _bridge.createFolder(basePath, bucket);
          if (!created) {
            throw StateError('Could not create the $bucket folder here.');
          }
        }
        target = candidate;
      }

      final names = await _bridge.importFiles(target);
      if (names.isNotEmpty) {
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
      if (!ok) throw StateError('Could not create folder. A folder with that name may already exist.');
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
      final created = await _bridge.createFolder(parent, trimmed);
      if (!created) {
        throw StateError('A folder named $trimmed already exists here.');
      }
      final root = _join(parent, trimmed);
      for (final child in children) {
        final value = child.trim();
        if (value.isNotEmpty) await _bridge.createFolder(root, value);
      }
      notice = children.isEmpty ? '$trimmed created.' : '$trimmed workspace created.';
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
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> moveEntry(LibraryEntry entry, String destination) async {
    await moveEntries([entry], destination);
  }

  Future<void> moveEntries(List<LibraryEntry> values, String destination) async {
    if (values.isEmpty) return;
    await _guard(() async {
      var moved = 0;
      for (final entry in values) {
        if (await _bridge.move(entry.path, destination)) moved++;
      }
      if (moved != values.length) {
        throw StateError('Moved $moved of ${values.length} items. Some items could not be moved.');
      }
      notice = moved == 1 ? 'Item moved.' : '$moved items moved.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
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
        if (await _bridge.delete(entry.path)) deleted++;
      }
      if (deleted != values.length) {
        throw StateError('Deleted $deleted of ${values.length} items. Some items could not be deleted.');
      }
      notice = deleted == 1 ? 'Item deleted.' : '$deleted items deleted.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
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
    final values = allEntries.where((item) => !item.isDirectory).toList();
    values.sort((a, b) {
      final left = a.lastModified?.millisecondsSinceEpoch ?? 0;
      final right = b.lastModified?.millisecondsSinceEpoch ?? 0;
      return right.compareTo(left);
    });
    return values.take(8).toList();
  }

  List<LibraryEntry> get currentFolders => entries.where((entry) => entry.isDirectory).toList();

  List<LibraryEntry> get currentMaterials => entries.where((entry) => !entry.isDirectory).toList();

  /// Root folders are treated as user-defined spaces. Inbox is a system landing
  /// zone and is intentionally shown separately on Home.
  List<LibraryEntry> get rootSpaces {
    final values = allEntries
        .where((entry) => entry.isDirectory && _parentOf(entry.path).isEmpty && entry.name != 'Inbox')
        .toList();
    values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  int countKind(LibraryKind kind) => allEntries.where((item) => item.kind == kind).length;

  int directFolderCount(String path) => allEntries
      .where((entry) => entry.isDirectory && _parentOf(entry.path) == path)
      .length;

  int directMaterialCount(String path) => allEntries
      .where((entry) => !entry.isDirectory && _parentOf(entry.path) == path)
      .length;

  int materialCountUnder(String path) {
    if (path.isEmpty) return allEntries.where((entry) => !entry.isDirectory).length;
    return allEntries
        .where((entry) => !entry.isDirectory && (entry.path.startsWith('$path/') || entry.path == path))
        .length;
  }

  List<String> get folderPaths {
    final values = allEntries
        .where((entry) => entry.isDirectory)
        .map((entry) => entry.path)
        .where((path) => !path.startsWith('.studyapp'))
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
  }

  Future<void> _onShareReceived(List<String> names) async {
    if (names.isNotEmpty) {
      notice = '${names.length} shared item(s) added to Inbox.';
    }
    if (connected) {
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    }
    notifyListeners();
  }

  String _join(String parent, String child) => parent.isEmpty ? child : '$parent/$child';

  String _parentOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  Future<void> _guard(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
