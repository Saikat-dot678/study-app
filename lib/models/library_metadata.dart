import 'dart:convert';

/// Optional, portable references. Original files never depend on this index.
class LibraryMetadata {
  int revision = 0;
  final Set<String> starred = {};
  final Map<String, int> opened = {};
  final Map<String, int> positions = {};
  final List<String> destinations = [];

  static LibraryMetadata decode(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    if (map['version'] != 1) {
      throw const FormatException('Unknown metadata version');
    }
    final result = LibraryMetadata()
      ..revision = (map['revision'] as num).toInt();
    result.starred.addAll((map['starred'] as List).cast<String>());
    for (final item in (map['opened'] as Map).entries) {
      result.opened[item.key as String] = (item.value as num).toInt();
    }
    for (final item in (map['positions'] as Map).entries) {
      result.positions[item.key as String] = (item.value as num).toInt();
    }
    result.destinations.addAll((map['destinations'] as List).cast<String>());
    return result;
  }

  String encode() => jsonEncode({
    'version': 1,
    'revision': revision,
    'starred': starred.toList(),
    'opened': opened,
    'positions': positions,
    'destinations': destinations,
  });

  void rememberDestination(String path) {
    destinations.remove(path);
    destinations.insert(0, path);
    if (destinations.length > 8) {
      destinations.removeRange(8, destinations.length);
    }
  }

  void relocate(String source, String? target) {
    bool matches(String path) => path == source || path.startsWith('$source/');
    String mapped(String path) => '$target${path.substring(source.length)}';
    final stars = starred.where(matches).toList();
    starred.removeAll(stars);
    if (target != null) starred.addAll(stars.map(mapped));
    for (final map in [opened, positions]) {
      for (final path in map.keys.where(matches).toList()) {
        final value = map.remove(path)!;
        if (target != null) map[mapped(path)] = value;
      }
    }
    final recent = destinations.toList();
    destinations.clear();
    for (final path in recent) {
      if (!matches(path)) {
        destinations.add(path);
      } else if (target != null) {
        destinations.add(mapped(path));
      }
    }
  }
}
