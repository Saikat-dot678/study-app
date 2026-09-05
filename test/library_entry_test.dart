import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/models/library_entry.dart';

void main() {
  test('classifies common student file types', () {
    LibraryEntry entry(String name) => LibraryEntry(
          name: name,
          path: name,
          isDirectory: false,
          mime: null,
          size: 0,
          lastModified: null,
        );

    expect(entry('lecture.pdf').kind, LibraryKind.pdf);
    expect(entry('week-4.pptx').kind, LibraryKind.slides);
    expect(entry('voice.m4a').kind, LibraryKind.audio);
    expect(entry('todo.md').kind, LibraryKind.note);
    expect(entry('scan.jpg').kind, LibraryKind.image);
  });
}
