import 'library_entry.dart';

/// All words match across a path, in any order; filters remain optional.
class LibraryQuery {
  LibraryQuery(String query) {
    for (final token in query.toLowerCase().trim().split(RegExp(r'\s+'))) {
      if (token.startsWith('type:') && token.length > 5) {
        types.add(token.substring(5));
      } else if (token == 'is:starred') {
        starredOnly = true;
      } else if (token.isNotEmpty) {
        words.add(token);
      }
    }
  }
  final List<String> words = [];
  final List<String> types = [];
  bool starredOnly = false;

  bool matches(LibraryEntry entry, {bool starred = false}) {
    final text = entry.path.toLowerCase();
    return (!starredOnly || starred) &&
        words.every(text.contains) &&
        (types.isEmpty ||
            types.any(
              (type) => entry.extension == type || entry.kind.name == type,
            ));
  }
}
