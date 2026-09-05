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
        notice = 'Library connected. Your files stay in this folder.';
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
      await _guard(() => _bridge.open(entry.path));
    }
  }

  Future<void> importFiles({String? destination}) async {
    await _guard(() async {
      final target = destination ?? currentPath;
      final names = await _bridge.importFiles(target);
      if (names.isNotEmpty) notice = 'Imported ${names.length} item(s).';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _guard(() async {
      final ok = await _bridge.createFolder(currentPath, trimmed);
      if (!ok) throw StateError('Could not create folder.');
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> createNote(String title, String body) async {
    final target = currentPath.isEmpty ? 'Notes' : currentPath;
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
    await _guard(() async {
      final ok = await _bridge.move(entry.path, destination);
      if (!ok) throw StateError('Could not move item.');
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  Future<void> deleteEntry(LibraryEntry entry) async {
    await _guard(() async {
      final ok = await _bridge.delete(entry.path);
      if (!ok) throw StateError('Could not delete item.');
      notice = '${entry.name} deleted.';
      await _refreshCurrentInternal();
      await _refreshAllInternal();
    });
  }

  void setGridMode(bool value) {
    gridMode = value;
    notifyListeners();
  }

  List<LibraryEntry> get recentFiles {
    final values = allEntries.where((item) => !item.isDirectory).toList();
    values.sort((a, b) {
      final left = a.lastModified?.millisecondsSinceEpoch ?? 0;
      final right = b.lastModified?.millisecondsSinceEpoch ?? 0;
      return right.compareTo(left);
    });
    return values.take(6).toList();
  }

  int countKind(LibraryKind kind) =>
      allEntries.where((item) => item.kind == kind).length;

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
