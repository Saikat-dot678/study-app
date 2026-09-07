import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class ExtractedSection {
  const ExtractedSection({required this.title, required this.body});

  final String title;
  final String body;
}

class ExtractedDocument {
  const ExtractedDocument({required this.sections});

  final List<ExtractedSection> sections;

  bool get isEmpty => sections.every((section) => section.body.trim().isEmpty);
}

Future<ExtractedDocument> extractPortableDocument(
  String filePath,
  String extension,
) => Isolate.run(() => _extractPortableDocument(filePath, extension));

Future<ExtractedDocument> _extractPortableDocument(
  String filePath,
  String extension,
) async {
  const previewLimit = 128 * 1024 * 1024;
  if (await File(filePath).length() > previewLimit) {
    throw StateError(
      'This document is too large for a text preview. Open it in another app.',
    );
  }
  final ext = extension.toLowerCase();
  if (ext == 'csv' || ext == 'tsv' || ext == 'rtf') {
    final text = await File(filePath).readAsString();
    return ExtractedDocument(
      sections: [
        ExtractedSection(
          title: 'Document',
          body: ext == 'rtf' ? _cleanRtf(text) : text,
        ),
      ],
    );
  }

  final bytes = await File(filePath).readAsBytes();
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
    throw const FormatException('This document is not a readable archive.');
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  if (archive.files.fold<int>(0, (sum, file) => sum + file.size) >
      previewLimit) {
    throw StateError('This expanded document is too large for a text preview.');
  }

  return switch (ext) {
    'docx' => _extractDocx(archive),
    'pptx' => _extractPptx(archive),
    'xlsx' => _extractXlsx(archive),
    'odt' => _extractOdt(archive),
    'odp' => _extractOdp(archive),
    'ods' => _extractOds(archive),
    'epub' => _extractEpub(archive),
    _ => const ExtractedDocument(sections: []),
  };
}

ExtractedDocument _extractDocx(Archive archive) {
  final xml = _readEntry(archive, 'word/document.xml');
  if (xml == null) return const ExtractedDocument(sections: []);
  return ExtractedDocument(
    sections: [ExtractedSection(title: 'Document', body: _paragraphText(xml))],
  );
}

ExtractedDocument _extractPptx(Archive archive) {
  final slides =
      archive.files
          .where(
            (file) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(file.name),
          )
          .toList()
        ..sort((a, b) => _numberIn(a.name).compareTo(_numberIn(b.name)));

  return ExtractedDocument(
    sections: [
      for (var index = 0; index < slides.length; index++)
        ExtractedSection(
          title: 'Slide ${index + 1}',
          body: _paragraphText(_decode(slides[index])),
        ),
    ],
  );
}

ExtractedDocument _extractXlsx(Archive archive) {
  final shared = <String>[];
  final sharedXml = _readEntry(archive, 'xl/sharedStrings.xml');
  if (sharedXml != null) {
    try {
      final document = XmlDocument.parse(sharedXml);
      for (final si in document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'si',
      )) {
        shared.add(
          si.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join(),
        );
      }
    } catch (_) {}
  }

  final sheets =
      archive.files
          .where(
            (file) =>
                RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(file.name),
          )
          .toList()
        ..sort((a, b) => _numberIn(a.name).compareTo(_numberIn(b.name)));

  final sections = <ExtractedSection>[];
  for (var index = 0; index < sheets.length; index++) {
    final text = _decode(sheets[index]);
    final rows = <String>[];
    try {
      final document = XmlDocument.parse(text);
      final rowElements = document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'row',
      );
      for (final row in rowElements) {
        final values = <String>[];
        for (final cell in row.children.whereType<XmlElement>().where(
          (e) => e.name.local == 'c',
        )) {
          final type = cell.getAttribute('t');
          final valueNode = cell.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'v')
              .firstOrNull;
          final inline = cell.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join();
          var value = valueNode?.innerText ?? inline;
          if (type == 's') {
            final sharedIndex = int.tryParse(value);
            if (sharedIndex != null &&
                sharedIndex >= 0 &&
                sharedIndex < shared.length) {
              value = shared[sharedIndex];
            }
          }
          values.add(value);
        }
        if (values.any((value) => value.trim().isNotEmpty)) {
          rows.add(values.join('   •   '));
        }
      }
    } catch (_) {
      rows.add(_stripMarkup(text));
    }
    sections.add(
      ExtractedSection(title: 'Sheet ${index + 1}', body: rows.join('\n')),
    );
  }
  return ExtractedDocument(sections: sections);
}

ExtractedDocument _extractOdt(Archive archive) {
  final xml = _readEntry(archive, 'content.xml');
  if (xml == null) return const ExtractedDocument(sections: []);
  return ExtractedDocument(
    sections: [ExtractedSection(title: 'Document', body: _paragraphText(xml))],
  );
}

ExtractedDocument _extractOdp(Archive archive) {
  final xml = _readEntry(archive, 'content.xml');
  if (xml == null) return const ExtractedDocument(sections: []);
  try {
    final document = XmlDocument.parse(xml);
    final pages = document.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'page')
        .toList();
    if (pages.isNotEmpty) {
      return ExtractedDocument(
        sections: [
          for (var index = 0; index < pages.length; index++)
            ExtractedSection(
              title: 'Slide ${index + 1}',
              body: _textFromElement(pages[index]),
            ),
        ],
      );
    }
  } catch (_) {}
  return ExtractedDocument(
    sections: [ExtractedSection(title: 'Slides', body: _paragraphText(xml))],
  );
}

ExtractedDocument _extractOds(Archive archive) {
  final xml = _readEntry(archive, 'content.xml');
  if (xml == null) return const ExtractedDocument(sections: []);
  return ExtractedDocument(
    sections: [
      ExtractedSection(title: 'Spreadsheet', body: _paragraphText(xml)),
    ],
  );
}

ExtractedDocument _extractEpub(Archive archive) {
  var chapters = archive.files.where((file) {
    final name = file.name.toLowerCase();
    return !file.isDirectory &&
        (name.endsWith('.xhtml') ||
            name.endsWith('.html') ||
            name.endsWith('.htm')) &&
        !name.contains('nav.') &&
        !name.contains('toc.');
  }).toList()..sort((a, b) => a.name.compareTo(b.name));

  try {
    final container = _readEntry(archive, 'META-INF/container.xml');
    final packagePath = container == null
        ? null
        : XmlDocument.parse(container).descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'rootfile')
              .firstOrNull
              ?.getAttribute('full-path');
    final package = packagePath == null
        ? null
        : _readEntry(archive, packagePath);
    if (package != null) {
      final document = XmlDocument.parse(package);
      final manifest = <String, String>{};
      for (final element in document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'item',
      )) {
        final id = element.getAttribute('id');
        final href = element.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = p.posix.normalize(
            p.posix.join(
              p.posix.dirname(packagePath!),
              Uri.decodeComponent(href.split('#').first),
            ),
          );
        }
      }
      final byName = {for (final file in chapters) file.name: file};
      final ordered = <ArchiveFile>[];
      for (final element in document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'itemref',
      )) {
        final file = byName[manifest[element.getAttribute('idref')]];
        if (file != null) ordered.add(file);
      }
      if (ordered.isNotEmpty) chapters = ordered;
    }
  } catch (_) {
    // Damaged package: retain the readable filename-order fallback.
  }

  return ExtractedDocument(
    sections: [
      for (var index = 0; index < chapters.length; index++)
        ExtractedSection(
          title: _chapterTitle(_decode(chapters[index]), index + 1),
          body: _paragraphText(_decode(chapters[index])),
        ),
    ],
  );
}

String? _readEntry(Archive archive, String name) {
  for (final file in archive.files) {
    if (file.name == name) return _decode(file);
  }
  return null;
}

String _decode(ArchiveFile file) {
  final bytes = file.readBytes();
  if (bytes == null) return '';
  return utf8.decode(bytes, allowMalformed: true);
}

int _numberIn(String value) {
  final match = RegExp(r'(\d+)').allMatches(value).lastOrNull;
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

String _paragraphText(String source) {
  try {
    final document = XmlDocument.parse(source);
    final paragraphs = document.descendants.whereType<XmlElement>().where((
      element,
    ) {
      final name = element.name.local.toLowerCase();
      return name == 'p' ||
          name == 'h1' ||
          name == 'h2' ||
          name == 'h3' ||
          name == 'li' ||
          name == 'title';
    });
    final values = paragraphs
        .map(_textFromElement)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isNotEmpty) return values.join('\n\n');

    final textNodes = document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 't')
        .map((element) => element.innerText.trim())
        .where((value) => value.isNotEmpty);
    return textNodes.join(' ');
  } catch (_) {
    return _stripMarkup(source);
  }
}

String _textFromElement(XmlElement element) {
  final pieces = element.descendants
      .whereType<XmlText>()
      .map((node) => node.value.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((value) => value.isNotEmpty)
      .toList();
  return pieces.join(' ');
}

String _chapterTitle(String source, int fallback) {
  try {
    final document = XmlDocument.parse(source);
    for (final name in ['h1', 'h2', 'title']) {
      final values = document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local.toLowerCase() == name,
      );
      if (values.isNotEmpty) {
        final title = _textFromElement(values.first).trim();
        if (title.isNotEmpty) return title;
      }
    }
  } catch (_) {}
  return 'Chapter $fallback';
}

String _stripMarkup(String source) {
  return source
      .replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
      .trim();
}

String _cleanRtf(String source) {
  return source
      .replaceAll(RegExp(r'\\[a-z]+-?\d* ?'), '')
      .replaceAll(RegExp(r'[{}]'), '')
      .replaceAll(r'\par', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
