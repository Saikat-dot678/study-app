import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/viewers/document_extractor.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('study-doc-qa-');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<String> document(String extension, Map<String, String> entries) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    final file = File('${root.path}/lecture.$extension');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file.path;
  }

  test('DOCX extracts local paragraphs including Unicode', () async {
    final path = await document('docx', {
      'word/document.xml': '<w:document xmlns:w="w"><w:body><w:p><w:r><w:t>Normalization α</w:t></w:r></w:p></w:body></w:document>',
    });
    final result = await extractPortableDocument(path, 'docx');
    expect(result.sections.single.body, contains('Normalization α'));
  });

  test('PPTX preserves numerical slide order', () async {
    String slide(String text) =>
        '<p:sld xmlns:p="p" xmlns:a="a"><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:sld>';
    final path = await document('pptx', {
      'ppt/slides/slide10.xml': slide('Transactions'),
      'ppt/slides/slide2.xml': slide('ER Model'),
    });
    final result = await extractPortableDocument(path, 'pptx');
    expect(result.sections.first.body, contains('ER Model'));
    expect(result.sections.last.body, contains('Transactions'));
  });

  test('XLSX resolves shared strings and numeric cells offline', () async {
    final path = await document('xlsx', {
      'xl/sharedStrings.xml': '<sst><si><t>Credits</t></si></sst>',
      'xl/worksheets/sheet1.xml': '<worksheet><sheetData><row><c t="s"><v>0</v></c><c><v>4</v></c></row></sheetData></worksheet>',
    });
    final result = await extractPortableDocument(path, 'xlsx');
    expect(result.sections.single.body, contains('Credits'));
    expect(result.sections.single.body, contains('4'));
  });

  test('EPUB follows the package spine instead of alphabetical filenames', () async {
    final path = await document('epub', {
      'META-INF/container.xml': '<container><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
      'OPS/book.opf': '<package><manifest><item id="first" href="z.xhtml"/><item id="second" href="a.xhtml"/></manifest><spine><itemref idref="first"/><itemref idref="second"/></spine></package>',
      'OPS/a.xhtml': '<html><body><h1>Second chapter</h1><p>Transactions</p></body></html>',
      'OPS/z.xhtml': '<html><body><h1>First chapter</h1><p>Normalization</p></body></html>',
    });
    final result = await extractPortableDocument(path, 'epub');
    expect(result.sections.first.title, 'First chapter');
    expect(result.sections.last.title, 'Second chapter');
  });

  test('Malformed archive reports failure without touching original', () async {
    final file = await File('${root.path}/broken.docx').writeAsString('not a zip');
    await expectLater(
      extractPortableDocument(file.path, 'docx'),
      throwsA(isA<Exception>()),
    );
    expect(await file.readAsString(), 'not a zip');
  });
}
