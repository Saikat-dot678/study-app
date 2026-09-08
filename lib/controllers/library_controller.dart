import 'package:flutter/foundation.dart';

import '../models/library_entry.dart';
import '../models/study_metadata.dart';
import '../storage/storage_bridge.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({StorageBridge? bridge})
    : _bridge = bridge ?? StorageBridge() {
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
  StudyMetadata metadata = const StudyMetadata();
  int navigationDelta = 0;
  Future<void> _metadataWrite = Future.value();

  Future<void> initialize() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final state = await _bridge.getState();
      connected = state.connected;
      libraryName = state.name;
      if (state.pendingShares > 0) {
        notice =
            '${state.pendingShares} shared item(s) are waiting for a library folder.';
      }

      initialized = true;
      busy = false;
      notifyListeners();

      if (connected) {
        await _refreshCurrentInternal();
        allEntries = [...entries];
        await _loadMetadata();
        notifyListeners();

        await _refreshAllInternal();
        notifyListeners();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    } finally {
      initialized = true;
      busy = false;
      notifyListeners();
    }
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
        await _loadMetadata();
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
      metadata = const StudyMetadata();
      notice = 'Folder connection removed. No files were deleted.';
    });
  }

  Future<void> refresh() => _guard(() async {
    await _refreshCurrentInternal();
    await _refreshAllInternal();
  });

  Future<void> openFolder(String path) async {
    final oldDepth = _depthOf(currentPath);
    await _guard(() async {
      currentPath = path;
      navigationDelta = _depthOf(path).compareTo(oldDepth);
      await _refreshCurrentInternal();
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
  }) async {
    await _guard(() async {
      var target = basePath;
      final bucket = category?.trim() ?? '';
      if (bucket.isNotEmpty) {
        final candidate = _join(basePath, bucket);
        final exists = allEntries.any(
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

      final names = await _bridge.importFiles(target);
      if (names.isNotEmpty) {
        final place = target.isEmpty ? 'Library root' : target;
        notice = 'Imported ${names.length} item(s) into $place.';
        _rememberDestination(target);
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
      final created = await _bridge.createFolder(parent, trimmed);
      if (!created) {
        throw StateError('A folder named $trimmed already exists here.');
      }
      final root = _join(parent, trimmed);
      for (final child in children) {
        final value = child.trim();
        if (value.isNotEmpty) await _bridge.createFolder(root, value);
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
      for (final entry in values) {
        if (await _bridge.move(entry.path, destination)) moved++;
      }
      if (moved != values.length) {
        throw StateError(
          'Moved $moved of ${values.length} items. Some items could not be moved.',
        );
      }
      notice = moved == 1 ? 'Item moved.' : '$moved items moved.';
      _rememberDestination(destination);
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
        throw StateError(
          'Deleted $deleted of ${values.length} items. Some items could not be deleted.',
        );
      }
      notice = deleted == 1 ? 'Item deleted.' : '$deleted items deleted.';
      final removed = values.map((entry) => entry.path).toList();
      metadata = StudyMetadata(
        favorites: metadata.favorites
            .where(
              (path) => !removed.any(
                (item) => path == item || path.startsWith('$item/'),
              ),
            )
            .toSet(),
        pins: metadata.pins
            .where(
              (path) => !removed.any(
                (item) => path == item || path.startsWith('$item/'),
              ),
            )
            .toSet(),
        progress: Map.fromEntries(
          metadata.progress.entries.where(
            (entry) => !removed.any(
              (item) => entry.key == item || entry.key.startsWith('$item/'),
            ),
          ),
        ),
        recentDestinations: metadata.recentDestinations,
      );
      _persistMetadata();
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

  void showNotice(String value) {
    notice = value;
    notifyListeners();
  }

  List<LibraryEntry> get recentFiles {
    final byPath = {for (final entry in allEntries) entry.path: entry};
    final values =
        metadata.progress.values
            .where((item) => byPath[item.path]?.isDirectory == false)
            .toList()
          ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return values.take(10).map((item) => byPath[item.path]!).toList();
  }

  List<LibraryEntry> get favoriteEntries => allEntries
      .where((entry) => metadata.favorites.contains(entry.path))
      .toList();

  List<LibraryEntry> get pinnedFolders => allEntries
      .where((entry) => entry.isDirectory && metadata.pins.contains(entry.path))
      .toList();

  bool isFavorite(String path) => metadata.favorites.contains(path);

  bool isPinned(String path) => metadata.pins.contains(path);

  StudyProgress? progressFor(String path) => metadata.progress[path];

  Future<void> toggleFavorite(LibraryEntry entry) async {
    final next = {...metadata.favorites};
    final added = next.add(entry.path);
    if (!added) next.remove(entry.path);
    metadata = StudyMetadata(
      favorites: next,
      pins: metadata.pins,
      progress: metadata.progress,
      recentDestinations: metadata.recentDestinations,
    );
    notice = added ? 'Added to favorites.' : 'Removed from favorites.';
    notifyListeners();
    await _persistMetadata();
  }

  Future<void> togglePin(LibraryEntry entry) async {
    if (!entry.isDirectory) return;
    final next = {...metadata.pins};
    final added = next.add(entry.path);
    if (!added) next.remove(entry.path);
    metadata = StudyMetadata(
      favorites: metadata.favorites,
      pins: next,
      progress: metadata.progress,
      recentDestinations: metadata.recentDestinations,
    );
    notice = added ? 'Pinned to the sidebar.' : 'Unpinned from the sidebar.';
    notifyListeners();
    await _persistMetadata();
  }

  Future<void> recordOpened(LibraryEntry entry) async {
    final existing = metadata.progress[entry.path];
    final next = {...metadata.progress};
    next[entry.path] =
        (existing ??
                StudyProgress(path: entry.path, lastOpened: DateTime.now()))
            .copyWith(lastOpened: DateTime.now());
    metadata = StudyMetadata(
      favorites: metadata.favorites,
      pins: metadata.pins,
      progress: next,
      recentDestinations: metadata.recentDestinations,
    );
    notifyListeners();
    await _persistMetadata();
  }

  Future<void> saveProgress(
    LibraryEntry entry, {
    Duration? position,
    Duration? duration,
    int? page,
    int? pageCount,
  }) async {
    final existing =
        metadata.progress[entry.path] ??
        StudyProgress(path: entry.path, lastOpened: DateTime.now());
    final next = {...metadata.progress};
    next[entry.path] = existing.copyWith(
      lastOpened: DateTime.now(),
      position: position,
      duration: duration,
      page: page,
      pageCount: pageCount,
    );
    metadata = StudyMetadata(
      favorites: metadata.favorites,
      pins: metadata.pins,
      progress: next,
      recentDestinations: metadata.recentDestinations,
    );
    notifyListeners();
    await _persistMetadata();
  }

  List<LibraryEntry> searchEntries(String rawQuery, {LibraryKind? kind}) {
    final tokens = rawQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    LibraryKind? requestedKind = kind;
    var favoritesOnly = false;
    var pinnedOnly = false;
    final terms = <String>[];
    for (final token in tokens) {
      if (token.startsWith('type:')) {
        requestedKind = _kindFromQuery(token.substring(5)) ?? requestedKind;
      } else if (token == 'is:favorite' || token == 'is:starred') {
        favoritesOnly = true;
      } else if (token == 'is:pinned') {
        pinnedOnly = true;
      } else {
        terms.add(token);
      }
    }

    final scored = <(LibraryEntry, int)>[];
    for (final entry in allEntries) {
      if (requestedKind != null && entry.kind != requestedKind) continue;
      if (favoritesOnly && !isFavorite(entry.path)) continue;
      if (pinnedOnly && !isPinned(entry.path)) continue;
      var score = entry.isDirectory ? 5 : 0;
      var matches = true;
      for (final term in terms) {
        final value = _matchScore(entry, term);
        if (value == 0) {
          matches = false;
          break;
        }
        score += value;
      }
      if (!matches) continue;
      if (isFavorite(entry.path)) score += 16;
      if (isPinned(entry.path)) score += 12;
      final opened =
          progressFor(entry.path)?.lastOpened.millisecondsSinceEpoch ?? 0;
      if (opened >
          DateTime.now()
              .subtract(const Duration(days: 14))
              .millisecondsSinceEpoch) {
        score += 8;
      }
      scored.add((entry, score));
    }
    scored.sort((a, b) {
      final score = b.$2.compareTo(a.$2);
      return score != 0
          ? score
          : a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    });
    return scored.map((item) => item.$1).toList();
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

  int directFolderCount(String path) => allEntries
      .where((entry) => entry.isDirectory && _parentOf(entry.path) == path)
      .length;

  int directMaterialCount(String path) => allEntries
      .where((entry) => !entry.isDirectory && _parentOf(entry.path) == path)
      .length;

  int materialCountUnder(String path) {
    if (path.isEmpty) {
      return allEntries.where((entry) => !entry.isDirectory).length;
    }
    return allEntries
        .where(
          (entry) =>
              !entry.isDirectory &&
              (entry.path.startsWith('$path/') || entry.path == path),
        )
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

  Future<void> _loadMetadata() async {
    metadata = StudyMetadata.fromJson(await _bridge.readMetadata());
  }

  Future<void> _persistMetadata() {
    final snapshot = metadata.toJson();
    _metadataWrite = _metadataWrite
        .then((_) => _bridge.writeMetadata(snapshot))
        .catchError((Object error) {
          debugPrint('Could not persist Study metadata: $error');
        });
    return _metadataWrite;
  }

  void _rememberDestination(String path) {
    final next = [
      path,
      ...metadata.recentDestinations.where((item) => item != path),
    ].take(6).toList();
    metadata = StudyMetadata(
      favorites: metadata.favorites,
      pins: metadata.pins,
      progress: metadata.progress,
      recentDestinations: next,
    );
    _persistMetadata();
  }

  int _matchScore(LibraryEntry entry, String term) {
    final name = entry.name.toLowerCase();
    final path = entry.path.toLowerCase();
    if (name == term) return 120;
    if (name.startsWith(term)) return 80;
    if (name
        .split(RegExp(r'[^a-z0-9]+'))
        .any((word) => word.startsWith(term))) {
      return 58;
    }
    if (name.contains(term)) return 42;
    if (path.contains(term)) return 24;
    var cursor = 0;
    for (final codeUnit in path.codeUnits) {
      if (cursor < term.length && codeUnit == term.codeUnitAt(cursor)) cursor++;
    }
    return cursor == term.length ? 10 : 0;
  }

  LibraryKind? _kindFromQuery(String value) => switch (value) {
    'folder' || 'folders' => LibraryKind.folder,
    'pdf' || 'pdfs' => LibraryKind.pdf,
    'book' || 'books' || 'epub' => LibraryKind.book,
    'slide' || 'slides' || 'ppt' || 'pptx' => LibraryKind.slides,
    'sheet' || 'spreadsheet' || 'xlsx' => LibraryKind.spreadsheet,
    'doc' || 'document' || 'docx' => LibraryKind.document,
    'note' || 'notes' || 'md' => LibraryKind.note,
    'audio' => LibraryKind.audio,
    'video' => LibraryKind.video,
    'image' || 'images' => LibraryKind.image,
    _ => null,
  };

  int _depthOf(String path) => path.isEmpty ? 0 : path.split('/').length;

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

  String _join(String parent, String child) =>
      parent.isEmpty ? child : '$parent/$child';

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
