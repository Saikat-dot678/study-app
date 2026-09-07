import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_app/workspace/study_workspace_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('goal task and annotation models round-trip cleanly', () {
    final goal = StudyGoal(
      id: 'g1',
      title: 'Finish DBMS revision',
      description: 'Normalization and transactions',
      dueDate: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 9, 8),
      targetMinutes: 600,
    );
    final task = StudyTask(
      id: 't1',
      title: 'Solve PYQs',
      dueDate: DateTime(2026, 9, 9),
      createdAt: DateTime(2026, 9, 8),
      goalId: goal.id,
      estimatedMinutes: 45,
      priority: StudyPriority.high,
    );
    final annotation = DocumentAnnotation(
      id: 'a1',
      path: 'Semester 5/DBMS/Normalization.pdf',
      page: 12,
      kind: DocumentAnnotationKind.highlight,
      createdAt: DateTime(2026, 9, 8),
      text: 'Third normal form',
      rects: const [
        DocumentRect(x: 10, y: 90, width: 80, height: 12),
      ],
    );

    final restoredGoal = StudyGoal.fromJson(goal.toJson());
    final restoredTask = StudyTask.fromJson(task.toJson());
    final restoredAnnotation = DocumentAnnotation.fromJson(annotation.toJson());

    expect(restoredGoal.title, goal.title);
    expect(restoredGoal.targetMinutes, 600);
    expect(restoredTask.goalId, 'g1');
    expect(restoredTask.priority, StudyPriority.high);
    expect(restoredAnnotation.page, 12);
    expect(restoredAnnotation.rects.single.width, 80);
  });

  test('workspace supports calendar tasks goals focus and annotations offline', () async {
    SharedPreferences.setMockInitialValues({});
    final workspace = StudyWorkspaceController.instance;
    await workspace.initialize();

    final today = DateTime(2026, 9, 8);
    await workspace.addGoal(
      title: 'Computational Number Theory revision',
      dueDate: DateTime(2026, 9, 30),
      targetMinutes: 300,
    );
    final goal = workspace.activeGoals.last;
    await workspace.addTask(
      title: 'Review lecture notes',
      dueDate: today,
      goalId: goal.id,
      estimatedMinutes: 40,
      priority: StudyPriority.high,
    );
    final task = workspace.tasksForDay(today).last;
    await workspace.toggleTask(task.id);
    await workspace.logSession(
      minutes: 40,
      label: task.title,
      taskId: task.id,
    );
    await workspace.addPageNote(
      path: 'CNT.pdf',
      page: 7,
      note: 'Revisit Euler theorem proof',
    );
    await workspace.addHighlight(
      path: 'CNT.pdf',
      page: 8,
      text: 'Euler phi',
      rects: const [DocumentRect(x: 12, y: 80, width: 50, height: 10)],
    );

    expect(workspace.tasksForDay(today).single.completed, isTrue);
    expect(workspace.goalProgress(goal), 1);
    expect(workspace.annotationsFor('CNT.pdf').length, 2);
    expect(workspace.annotationsFor('CNT.pdf', page: 8).single.text, 'Euler phi');
  });
}
