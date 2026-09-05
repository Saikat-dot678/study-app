import 'dart:io';

import 'package:flutter/services.dart';

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
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('study.app/storage');

  Future<void> Function(List<String> names)? onShareReceived;

  bool get supported => Platform.isAndroid;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'shareReceived') {
      final values = (call.arguments as List?)?.cast<String>() ?? const <String>[];
      await onShareReceived?.call(values);
    }
  }

  Future<LibraryState> getState() async {
    if (!supported) return const LibraryState(connected: false);
    final raw = await _channel.invokeMapMethod<String, dynamic>('getLibraryState');
    return LibraryState(
      connected: raw?['connected'] as bool? ?? false,
      name: raw?['name'] as String?,
      uri: raw?['uri'] as String?,
      pendingShares: (raw?['pendingShares'] as num?)?.toInt() ?? 0,
    );
  }

  Future<LibraryState> pickLibraryFolder() async {
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
    if (supported) await _channel.invokeMethod<void>('forgetLibrary');
  }

  Future<List<LibraryEntry>> listEntries(String path) async {
    if (!supported) return const [];
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
    final raw = await _channel.invokeListMethod<String>(
          'pickAndImportFiles',
          {'destination': destination},
        ) ??
        const [];
    return raw;
  }

  Future<bool> createFolder(String parent, String name) async {
    return await _channel.invokeMethod<bool>(
          'createFolder',
          {'parent': parent, 'name': name},
        ) ??
        false;
  }

  Future<bool> createNote(String parent, String title, String body) async {
    return await _channel.invokeMethod<bool>(
          'createNote',
          {'parent': parent, 'title': title, 'body': body},
        ) ??
        false;
  }

  Future<bool> rename(String path, String name) async {
    return await _channel.invokeMethod<bool>(
          'renameEntry',
          {'path': path, 'name': name},
        ) ??
        false;
  }

  Future<bool> move(String source, String destination) async {
    return await _channel.invokeMethod<bool>(
          'moveEntry',
          {'source': source, 'destination': destination},
        ) ??
        false;
  }

  Future<bool> delete(String path) async {
    return await _channel.invokeMethod<bool>('deleteEntry', {'path': path}) ?? false;
  }

  Future<void> open(String path) async {
    await _channel.invokeMethod<void>('openEntry', {'path': path});
  }
}
