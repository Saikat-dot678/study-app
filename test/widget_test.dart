import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/main.dart';

void main() {
  testWidgets('Study app root can be constructed', (tester) async {
    const app = StudyApp();
    expect(app, isA<StudyApp>());
  });
}
