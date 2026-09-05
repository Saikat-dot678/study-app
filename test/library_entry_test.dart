import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/models/library_entry.dart';

void main() {
  LibraryEntry entry(String name, {bool directory = false}) => LibraryEntry(
        name: name,
        path: name,
        isDirectory: directory,
        mime: null,
        size: 0,
        lastModified: null,
      );

  test('classifies common student file types', () {
    expect(entry('lecture.pdf').kind, LibraryKind.pdf);
    expect(entry('book.epub').kind, LibraryKind.book);
    expect(entry('week-4.pptx').kind, LibraryKind.slides);
    expect(entry('results.xlsx').kind, LibraryKind.spreadsheet);
    expect(entry('assignment.docx').kind, LibraryKind.document);
    expect(entry('voice.m4a').kind, LibraryKind.audio);
    expect(entry('class.mp4').kind, LibraryKind.video);
    expect(entry('todo.md').kind, LibraryKind.note);
    expect(entry('scan.jpg').kind, LibraryKind.image);
    expect(entry('archive.zip').kind, LibraryKind.archive);
    expect(entry('Semester 5', directory: true).kind, LibraryKind.folder);
  });

  test('marks formats supported by the in-app viewer', () {
    for (final name in [
      'lecture.pdf',
      'book.epub',
      'week-4.pptx',
      'results.xlsx',
      'assignment.docx',
      'voice.m4a',
      'class.mp4',
      'todo.md',
      'scan.jpg',
    ]) {
      expect(entry(name).canPreviewInApp, isTrue, reason: name);
    }

    expect(entry('legacy.ppt').canPreviewInApp, isFalse);
    expect(entry('legacy.doc').canPreviewInApp, isFalse);
    expect(entry('archive.zip').canPreviewInApp, isFalse);
  });
}
