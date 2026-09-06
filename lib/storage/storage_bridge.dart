import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_entry.dart';

class LibraryState {
  const LibraryState({
    required this.connected,
    this.name,
    this.uri,
    this.pendingShares = 0,
  });

  final bool connected;
  final String? name;
  final String? uri;
  final int pendingShares;
}

class StorageBridge {
  StorageBridge() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  static const _channel = MethodChannel('study.app/storage');
  static const _desktopRootKey = 'desktop_library_root';

  Future<void> Function(List<String> names)? onShareReceived;

  bool get supported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'shareReceived') {
      final values = (call.arguments as List?)?.cast<String>() ?? const <String>[];
      await onShareReceived?.call(values);
    }
  }

  Future<LibraryState> getState() async {
    if (!supported) return const LibraryState(connected: false);
    if (isDesktop) return _desktopState();
    final raw = await _channel.invokeMapMethod<String, dynamic>('getLibraryState');
    return LibraryState(
      connected: raw?['connected'] as bool? ?? false,
      name: raw?['name'] as String?,
      uri: raw?['uri'] as String?,
      pendingShares: (raw?['pendingShares'] as num?)?.toInt() ?? 0,
    );
  }

  Future<LibraryState> pickLibraryFolder() async {
    if (isDesktop) {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose your Study library folder',
      );
      if (selected == null || selected.trim().isEmpty) return _desktopState();
      final root = Directory(selected);
      if (!await root.exists()) await root.create(recursive: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_desktopRootKey, root.path);
      await _prepareDesktopRoot(root);
      return _desktopState();
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>('pickLibraryFolder');
    if (raw == null) return getState();
    return LibraryState(
      connected: raw['connected'] as bool? ?? false,
      name: raw['name'] as String?,
      uri: raw['uri'] as String?,
      pendingShares: (raw['pendingShares'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> forgetLibrary() async {
    if (isDesktop) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_desktopRootKey);
      return;
    }
    if (supported) await _channel.invokeMethod<void>('forgetLibrary');
  }

  Future<List<LibraryEntry>> listEntries(String path) async {
    if (!supported) return const [];
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null) return const [];
      final folder = Directory(_absolute(root, path));
      if (!await folder.exists()) return const [];
      final values = <LibraryEntry>[];
      await for (final entity in folder.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name == '.studyapp') continue;
        values.add(await _desktopEntry(entity, _joinRelative(path, name)));
      }
      return values;
    }
    final raw = await _channel.invokeListMethod<dynamic>(
          'listEntries',
          {'path': path},
        ) ??
        const [];
    return raw
        .map((item) => LibraryEntry.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<LibraryEntry>> search(String query) async {
    if (!supported) return const [];
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null) return const [];
      final normalized = query.trim().toLowerCase();
      final results = <LibraryEntry>[];
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (results.length >= 5000) break;
        final relative = p.relative(entity.path, from: root.path).replaceAll('\\', '/');
        if (relative == '.studyapp' || relative.startsWith('.studyapp/')) continue;
        final name = p.basename(entity.path);
        if (normalized.isEmpty ||
            name.toLowerCase().contains(normalized) ||
            relative.toLowerCase().contains(normalized)) {
          results.add(await _desktopEntry(entity, relative));
        }
      }
      return results;
    }
    final raw = await _channel.invokeListMethod<dynamic>(
          'searchEntries',
          {'query': query},
        ) ??
        const [];
    return raw
        .map((item) => LibraryEntry.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<String>> importFiles(String destination) async {
    if (!supported) return const [];
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null) throw StateError('Choose a library folder first.');
      final selected = await FilePicker.pickFiles(
        dialogTitle: 'Add materials to Study',
      );
      if (selected.isEmpty) return const [];
      final target = Directory(_absolute(root, destination));
      if (!await target.exists()) await target.create(recursive: true);
      final imported = <String>[];
      for (final picked in selected) {
        final sourcePath = picked.path;
        if (sourcePath == null || sourcePath.isEmpty) continue;
        final source = File(sourcePath);
        if (!await source.exists()) continue;
        final output = await _uniqueDestination(target, picked.name);
        await source.copy(output.path);
        imported.add(p.basename(output.path));
      }
      return imported;
    }
    final raw = await _channel.invokeListMethod<String>(
          'pickAndImportFiles',
          {'destination': destination},
        ) ??
        const [];
    return raw;
  }

  Future<bool> createFolder(String parent, String name) async {
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null) return false;
      final clean = _sanitizeName(name);
      if (clean.isEmpty) return false;
      final folder = Directory(p.join(_absolute(root, parent), clean));
      if (await folder.exists()) return false;
      await folder.create(recursive: true);
      return true;
    }
    return await _channel.invokeMethod<bool>(
          'createFolder',
          {'parent': parent, 'name': name},
        ) ??
        false;
  }

  Future<bool> createNote(String parent, String title, String body) async {
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null) return false;
      final folder = Directory(_absolute(root, parent));
      if (!await folder.exists()) await folder.create(recursive: true);
      var name = _sanitizeName(title).trim();
      if (name.isEmpty) name = 'Untitled note';
      if (!name.toLowerCase().endsWith('.md')) name = '$name.md';
      final target = await _uniqueDestination(folder, name);
      final heading = p.basenameWithoutExtension(target.path);
      await target.writeAsString('# $heading\n\n$body');
      return true;
    }
    return await _channel.invokeMethod<bool>(
          'createNote',
          {'parent': parent, 'title': title, 'body': body},
        ) ??
        false;
  }

  Future<bool> rename(String path, String name) async {
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null || path.isEmpty) return false;
      final clean = _sanitizeName(name);
      if (clean.isEmpty) return false;
      final source = _absolute(root, path);
      final target = p.join(p.dirname(source), clean);
      if (await FileSystemEntity.type(target) != FileSystemEntityType.notFound) return false;
      final type = await FileSystemEntity.type(source, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(source).rename(target);
        return true;
      }
      if (type == FileSystemEntityType.file) {
        await File(source).rename(target);
        return true;
      }
      return false;
    }
    return await _channel.invokeMethod<bool>(
          'renameEntry',
          {'path': path, 'name': name},
        ) ??
        false;
  }

  Future<bool> move(String source, String destination) async {
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null || source.isEmpty) return false;
      if (destination == source || destination.startsWith('$source/')) return false;
      final from = _absolute(root, source);
      final targetFolder = Directory(_absolute(root, destination));
      if (!await targetFolder.exists()) return false;
      final type = await FileSystemEntity.type(from, followLinks: false);
      if (type == FileSystemEntityType.notFound) return false;
      final name = p.basename(from);
      final target = await _uniqueEntityPath(targetFolder, name);
      if (type == FileSystemEntityType.directory) {
        await Directory(from).rename(target);
      } else if (type == FileSystemEntityType.file) {
        await File(from).rename(target);
      } else {
        return false;
      }
      return true;
    }
    return await _channel.invokeMethod<bool>(
          'moveEntry',
          {'source': source, 'destination': destination},
        ) ??
        false;
  }

  Future<bool> delete(String path) async {
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null || path.isEmpty) return false;
      final absolute = _absolute(root, path);
      final type = await FileSystemEntity.type(absolute, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(absolute).delete(recursive: true);
        return true;
      }
      if (type == FileSystemEntityType.file) {
        await File(absolute).delete();
        return true;
      }
      return false;
    }
    return await _channel.invokeMethod<bool>('deleteEntry', {'path': path}) ?? false;
  }

  Future<String> prepareEntry(String path) async {
    if (isDesktop) {
      final root = await _desktopRoot();
      if (root == null) throw StateError('Library folder is unavailable.');
      final absolute = _absolute(root, path);
      if (!await File(absolute).exists()) throw StateError('This file is unavailable.');
      return absolute;
    }
    final value = await _channel.invokeMethod<String>('prepareEntry', {'path': path});
    if (value == null || value.isEmpty) {
      throw StateError('Could not prepare this file for viewing.');
    }
    return value;
  }

  Future<String> entryUri(String path) async {
    if (isDesktop) {
      final absolute = await prepareEntry(path);
      return Uri.file(absolute).toString();
    }
    final value = await _channel.invokeMethod<String>('entryUri', {'path': path});
    if (value == null || value.isEmpty) {
      throw StateError('Could not access this file.');
    }
    return value;
  }

  Future<void> open(String path) async {
    if (isDesktop) {
      final absolute = await prepareEntry(path);
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', absolute], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [absolute]);
      } else {
        await Process.run('xdg-open', [absolute]);
      }
      return;
    }
    await _channel.invokeMethod<void>('openEntry', {'path': path});
  }

  Future<void> share(String path) async {
    if (isDesktop) {
      final absolute = await prepareEntry(path);
      await Clipboard.setData(ClipboardData(text: absolute));
      return;
    }
    await _channel.invokeMethod<void>('shareEntry', {'path': path});
  }

  Future<LibraryState> _desktopState() async {
    final root = await _desktopRoot();
    return LibraryState(
      connected: root != null,
      name: root == null ? null : p.basename(root.path),
      uri: root?.path,
    );
  }

  Future<Directory?> _desktopRoot() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_desktopRootKey);
    if (value == null || value.trim().isEmpty) return null;
    final root = Directory(value);
    return await root.exists() ? root : null;
  }

  Future<void> _prepareDesktopRoot(Directory root) async {
    // Inbox is the only reserved user-visible folder. Everything else is
    // intentionally user-defined so Semester/GATE/Project structures can live
    // naturally at the root without duplicate global type buckets.
    final inbox = Directory(p.join(root.path, 'Inbox'));
    if (!await inbox.exists()) await inbox.create(recursive: true);
    final appDir = Directory(p.join(root.path, '.studyapp'));
    if (!await appDir.exists()) await appDir.create(recursive: true);
    final marker = File(p.join(appDir.path, 'library.json'));
    if (!await marker.exists()) {
      await marker.writeAsString('{"schemaVersion":1,"app":"study_app"}');
    }
  }

  Future<LibraryEntry> _desktopEntry(FileSystemEntity entity, String relative) async {
    final stat = await entity.stat();
    return LibraryEntry.fromMap({
      'name': p.basename(entity.path),
      'path': relative.replaceAll('\\', '/'),
      'isDirectory': stat.type == FileSystemEntityType.directory,
      'mime': null,
      'size': stat.type == FileSystemEntityType.file ? stat.size : 0,
      'lastModified': stat.modified.millisecondsSinceEpoch,
    });
  }

  String _absolute(Directory root, String relative) {
    if (relative.trim().isEmpty) return root.path;
    return p.joinAll([root.path, ...relative.split('/').where((part) => part.isNotEmpty)]);
  }

  String _joinRelative(String parent, String child) => parent.isEmpty ? child : '$parent/$child';

  String _sanitizeName(String value) => value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();

  Future<File> _uniqueDestination(Directory folder, String desired) async {
    final target = await _uniqueEntityPath(folder, _sanitizeName(desired));
    return File(target);
  }

  Future<String> _uniqueEntityPath(Directory folder, String desired) async {
    final safe = desired.isEmpty ? 'Imported file' : desired;
    var candidate = p.join(folder.path, safe);
    if (await FileSystemEntity.type(candidate) == FileSystemEntityType.notFound) {
      return candidate;
    }
    final extension = p.extension(safe);
    final base = extension.isEmpty ? safe : p.basenameWithoutExtension(safe);
    var index = 2;
    while (true) {
      candidate = p.join(folder.path, '$base ($index)$extension');
      if (await FileSystemEntity.type(candidate) == FileSystemEntityType.notFound) {
        return candidate;
      }
      index++;
    }
  }
}
