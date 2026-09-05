enum LibraryKind {
  folder,
  pdf,
  book,
  slides,
  spreadsheet,
  document,
  note,
  audio,
  video,
  image,
  archive,
  other,
}

class LibraryEntry {
  const LibraryEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.mime,
    required this.size,
    required this.lastModified,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final String? mime;
  final int size;
  final DateTime? lastModified;

  factory LibraryEntry.fromMap(Map<String, dynamic> map) {
    final modified = map['lastModified'] as int?;
    return LibraryEntry(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      isDirectory: map['isDirectory'] as bool? ?? false,
      mime: map['mime'] as String?,
      size: (map['size'] as num?)?.toInt() ?? 0,
      lastModified: modified == null || modified <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modified),
    );
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  LibraryKind get kind {
    if (isDirectory) return LibraryKind.folder;
    if (extension == 'pdf') return LibraryKind.pdf;
    if ({'epub', 'mobi', 'azw', 'azw3'}.contains(extension)) {
      return LibraryKind.book;
    }
    if ({'ppt', 'pptx', 'odp', 'key'}.contains(extension)) {
      return LibraryKind.slides;
    }
    if ({'xls', 'xlsx', 'ods', 'csv', 'tsv'}.contains(extension)) {
      return LibraryKind.spreadsheet;
    }
    if ({'md', 'txt', 'markdown'}.contains(extension)) return LibraryKind.note;
    if ({'doc', 'docx', 'odt', 'rtf'}.contains(extension)) {
      return LibraryKind.document;
    }
    if ({'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'opus'}
        .contains(extension)) {
      return LibraryKind.audio;
    }
    if ({'mp4', 'mkv', 'mov', 'webm', 'avi', 'm4v'}.contains(extension)) {
      return LibraryKind.video;
    }
    if ({'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'bmp'}
        .contains(extension)) {
      return LibraryKind.image;
    }
    if ({'zip', 'rar', '7z', 'tar', 'gz'}.contains(extension)) {
      return LibraryKind.archive;
    }
    return LibraryKind.other;
  }

  bool get canPreviewInApp {
    if (isDirectory) return false;
    if ({
      LibraryKind.pdf,
      LibraryKind.note,
      LibraryKind.audio,
      LibraryKind.video,
      LibraryKind.image,
    }.contains(kind)) {
      return true;
    }
    if (kind == LibraryKind.book) return extension == 'epub';
    if (kind == LibraryKind.slides) return {'pptx', 'odp'}.contains(extension);
    if (kind == LibraryKind.document) {
      return {'docx', 'odt', 'rtf'}.contains(extension);
    }
    if (kind == LibraryKind.spreadsheet) {
      return {'xlsx', 'ods', 'csv', 'tsv'}.contains(extension);
    }
    return false;
  }
}
