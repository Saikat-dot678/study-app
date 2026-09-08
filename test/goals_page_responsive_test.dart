import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_app/theme.dart';
import 'package:study_app/ui/goals_page.dart';
import 'package:study_app/workspace/study_workspace_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  for (final size in const [
    Size(360, 640),
    Size(412, 915),
    Size(800, 1000),
    Size(1366, 768),
  ]) {
    testWidgets('goals planner fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final workspace = StudyWorkspaceController.instance;
      await workspace.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: GoalsPage(workspace: workspace)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final error = tester.takeException();
      if (error case FlutterError flutterError) {
        fail(flutterError.toStringDeep());
      }
      expect(error, isNull);
    });
  }
}
