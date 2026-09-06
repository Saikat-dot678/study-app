import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:study_app/controllers/library_controller.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/viewers/viewer_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native offline PDF, Markdown, image and audio readers open local fixtures',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('study-native-qa-');
      SharedPreferences.setMockInitialValues({
        'desktop_library_root': root.path,
      });
      await File('${root.path}/Revision.md')
          .writeAsString('# Revision\n\n- Transactions\n- Normalization');
      await File('${root.path}/Diagram.png').writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZkAAAAASUVORK5CYII=',
        ),
      );
      await File('${root.path}/Syllabus.pdf').writeAsBytes(_pdf());
      final wav = ByteData(44 + 16000);
      void text(int offset, String value) {
        for (var i = 0; i < value.length; i++) {
          wav.setUint8(offset + i, value.codeUnitAt(i));
        }
      }

      text(0, 'RIFF');
      wav.setUint32(4, 16036, Endian.little);
      text(8, 'WAVEfmt ');
      wav.setUint32(16, 16, Endian.little);
      wav.setUint16(20, 1, Endian.little);
      wav.setUint16(22, 1, Endian.little);
      wav.setUint32(24, 8000, Endian.little);
      wav.setUint32(28, 16000, Endian.little);
      wav.setUint16(32, 2, Endian.little);
      wav.setUint16(34, 16, Endian.little);
      text(36, 'data');
      wav.setUint32(40, 16000, Endian.little);
      await File('${root.path}/Lecture.wav')
          .writeAsBytes(wav.buffer.asUint8List());
      const videoFixture = String.fromEnvironment('STUDY_QA_VIDEO');
      if (videoFixture.isNotEmpty) {
        await File(videoFixture).copy('${root.path}/Lecture.mp4');
      }
      final controller = LibraryController();
      await controller.initialize();
      await controller.savePosition('Lecture.wav', 500);
      if (videoFixture.isNotEmpty) {
        await controller.savePosition('Lecture.mp4', 3000);
      }
      try {
        for (final name in [
          'Revision.md',
          'Diagram.png',
          'Syllabus.pdf',
          'Lecture.wav',
          if (videoFixture.isNotEmpty) 'Lecture.mp4',
        ]) {
          final entry = controller.allEntries.firstWhere((e) => e.name == name);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: StudyViewerPage(
                key: ValueKey(name),
                controller: controller,
                entry: entry,
              ),
            ),
          );
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 200));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          expect(
            find.textContaining('could not be prepared'),
            findsNothing,
            reason: name,
          );
          expect(
            find.textContaining('codec is not supported'),
            findsNothing,
            reason: name,
          );
          expect(find.text('Preparing locally…'), findsNothing, reason: name);
          if (name.endsWith('.md')) {
            expect(find.textContaining('Transactions'), findsWidgets);
          }
          if (name.endsWith('.wav')) {
            expect(find.byType(Slider), findsOneWidget);
            expect(
              tester.widget<Slider>(find.byType(Slider)).value,
              closeTo(500, 100),
            );
          }
          if (name.endsWith('.mp4')) {
            final video = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
            expect(video.controller.value.isInitialized, isTrue);
            expect(
              video.controller.value.position.inMilliseconds,
              greaterThanOrEqualTo(2900),
            );
          }
          expect(tester.takeException(), isNull, reason: name);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(controller.recentFiles.length, videoFixture.isEmpty ? 4 : 5);
      } finally {
        controller.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}

List<int> _pdf() {
  const content = 'BT /F1 18 Tf 30 100 Td (Study syllabus) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  var pdf = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = pdf.length;
  pdf += 'xref\n0 6\n0000000000 65535 f \n';
  for (final offset in offsets) {
    pdf += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  pdf += 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return ascii.encode(pdf);
}
