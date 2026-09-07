import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/models/study_metadata.dart';

void main() {
  test('portable study metadata round-trips progress and shortcuts', () {
    final source = StudyMetadata(
      favorites: {'Semester 5/DBMS/Normalization.pdf'},
      pins: {'Semester 5/DBMS'},
      recentDestinations: const ['Semester 5/DBMS/Notes'],
      progress: {
        'Semester 5/DBMS/Normalization.pdf': StudyProgress(
          path: 'Semester 5/DBMS/Normalization.pdf',
          lastOpened: DateTime.fromMillisecondsSinceEpoch(123456),
          page: 42,
          pageCount: 120,
        ),
      },
    );

    final restored = StudyMetadata.fromJson(source.toJson());
    final progress = restored.progress['Semester 5/DBMS/Normalization.pdf'];

    expect(restored.favorites, source.favorites);
    expect(restored.pins, source.pins);
    expect(restored.recentDestinations, source.recentDestinations);
    expect(progress?.page, 42);
    expect(progress?.pageCount, 120);
    expect(progress?.fraction, closeTo(0.35, 0.001));
  });

  test('media progress is clamped for safe display', () {
    final progress = StudyProgress(
      path: 'lecture.mp4',
      lastOpened: DateTime(2026),
      position: const Duration(minutes: 90),
      duration: const Duration(minutes: 60),
    );

    expect(progress.fraction, 1);
  });
}
