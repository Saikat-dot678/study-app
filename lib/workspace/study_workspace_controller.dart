import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyPriority { low, normal, high }

enum DocumentAnnotationKind { highlight, note }

class StudyGoal {
  const StudyGoal({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    this.description = '',
    this.targetMinutes = 0,
    this.completed = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final DateTime createdAt;
  final int targetMinutes;
  final bool completed;

  StudyGoal copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    int? targetMinutes,
    bool? completed,
  }) {
    return StudyGoal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      completed: completed ?? this.completed,
    );
  }

  factory StudyGoal.fromJson(Map<String, dynamic> json) => StudyGoal(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Goal',
    description: json['description']?.toString() ?? '',
    dueDate:
        DateTime.tryParse(json['dueDate']?.toString() ?? '') ?? DateTime.now(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    targetMinutes: (json['targetMinutes'] as num?)?.toInt() ?? 0,
    completed: json['completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'dueDate': dueDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'targetMinutes': targetMinutes,
    'completed': completed,
  };
}

class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    this.goalId,
    this.estimatedMinutes = 30,
    this.priority = StudyPriority.normal,
    this.completed = false,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final DateTime createdAt;
  final String? goalId;
  final int estimatedMinutes;
  final StudyPriority priority;
  final bool completed;

  StudyTask copyWith({
    String? title,
    DateTime? dueDate,
    String? goalId,
    bool clearGoal = false,
    int? estimatedMinutes,
    StudyPriority? priority,
    bool? completed,
  }) {
    return StudyTask(
      id: id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      goalId: clearGoal ? null : (goalId ?? this.goalId),
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
    );
  }

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Task',
    dueDate:
        DateTime.tryParse(json['dueDate']?.toString() ?? '') ?? DateTime.now(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    goalId: json['goalId']?.toString(),
    estimatedMinutes: math.max(
      5,
      (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
    ),
    priority: StudyPriority.values.firstWhere(
      (value) => value.name == json['priority'],
      orElse: () => StudyPriority.normal,
    ),
    completed: json['completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dueDate': dueDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'goalId': goalId,
    'estimatedMinutes': estimatedMinutes,
    'priority': priority.name,
    'completed': completed,
  };
}

class StudySession {
  const StudySession({
    required this.id,
    required this.startedAt,
    required this.minutes,
    required this.label,
    this.taskId,
  });

  final String id;
  final DateTime startedAt;
  final int minutes;
  final String label;
  final String? taskId;

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id']?.toString() ?? '',
    startedAt:
        DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
        DateTime.now(),
    minutes: math.max(1, (json['minutes'] as num?)?.toInt() ?? 1),
    label: json['label']?.toString() ?? 'Focus session',
    taskId: json['taskId']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'minutes': minutes,
    'label': label,
    'taskId': taskId,
  };
}

class DocumentRect {
  const DocumentRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory DocumentRect.fromJson(Map<String, dynamic> json) => DocumentRect(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    width: (json['width'] as num?)?.toDouble() ?? 0,
    height: (json['height'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class DocumentAnnotation {
  const DocumentAnnotation({
    required this.id,
    required this.path,
    required this.page,
    required this.kind,
    required this.createdAt,
    this.text = '',
    this.note = '',
    this.colorValue = 0xFFFFD54F,
    this.rects = const [],
  });

  final String id;
  final String path;
  final int page;
  final DocumentAnnotationKind kind;
  final DateTime createdAt;
  final String text;
  final String note;
  final int colorValue;
  final List<DocumentRect> rects;

  DocumentAnnotation copyWith({String? note, int? colorValue}) {
    return DocumentAnnotation(
      id: id,
      path: path,
      page: page,
      kind: kind,
      createdAt: createdAt,
      text: text,
      note: note ?? this.note,
      colorValue: colorValue ?? this.colorValue,
      rects: rects,
    );
  }

  factory DocumentAnnotation.fromJson(Map<String, dynamic> json) {
    final rawRects = json['rects'] as List? ?? const [];
    return DocumentAnnotation(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      page: math.max(1, (json['page'] as num?)?.toInt() ?? 1),
      kind: DocumentAnnotationKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => DocumentAnnotationKind.note,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      text: json['text']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFD54F,
      rects: rawRects
          .whereType<Map>()
          .map((item) => DocumentRect.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'page': page,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'text': text,
    'note': note,
    'colorValue': colorValue,
    'rects': rects.map((item) => item.toJson()).toList(),
  };
}

class StudyWorkspaceController extends ChangeNotifier {
  StudyWorkspaceController._();

  static final StudyWorkspaceController instance = StudyWorkspaceController._();
  static const _plannerKey = 'study_workspace_planner_v1';
  static const _annotationKey = 'study_workspace_annotations_v1';

  SharedPreferences? _preferences;
  bool initialized = false;
  List<StudyGoal> goals = const [];
  List<StudyTask> tasks = const [];
  List<StudySession> sessions = const [];
  List<DocumentAnnotation> annotations = const [];
  int _sequence = 0;

  Future<void> initialize() async {
    if (initialized) return;
    _preferences = await SharedPreferences.getInstance();
    _loadPlanner();
    _loadAnnotations();
    initialized = true;
    notifyListeners();
  }

  void _loadPlanner() {
    final source = _preferences?.getString(_plannerKey);
    if (source == null || source.trim().isEmpty) return;
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      goals = (json['goals'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => StudyGoal.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList();
      tasks = (json['tasks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => StudyTask.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList();
      sessions = (json['sessions'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => StudySession.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList();
    } catch (_) {
      goals = const [];
      tasks = const [];
      sessions = const [];
    }
  }

  void _loadAnnotations() {
    final source = _preferences?.getString(_annotationKey);
    if (source == null || source.trim().isEmpty) return;
    try {
      final raw = jsonDecode(source) as List;
      annotations = raw
          .whereType<Map>()
          .map(
            (item) =>
                DocumentAnnotation.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty && item.path.isNotEmpty)
          .toList();
    } catch (_) {
      annotations = const [];
    }
  }

  String _id(String prefix) {
    _sequence = (_sequence + 1) % 100000;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_sequence.toRadixString(36)}';
  }

  Future<void> _persistPlanner() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    _preferences = prefs;
    await prefs.setString(
      _plannerKey,
      jsonEncode({
        'version': 1,
        'goals': goals.map((item) => item.toJson()).toList(),
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'sessions': sessions.take(1000).map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<void> _persistAnnotations() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    _preferences = prefs;
    final kept = annotations.length <= 5000
        ? annotations
        : annotations.sublist(annotations.length - 5000);
    await prefs.setString(
      _annotationKey,
      jsonEncode(kept.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> addGoal({
    required String title,
    required DateTime dueDate,
    String description = '',
    int targetMinutes = 0,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    goals = [
      ...goals,
      StudyGoal(
        id: _id('goal'),
        title: trimmed,
        description: description.trim(),
        dueDate: dateOnly(dueDate),
        createdAt: DateTime.now(),
        targetMinutes: math.max(0, targetMinutes),
      ),
    ];
    notifyListeners();
    await _persistPlanner();
  }

  Future<void> toggleGoal(String id) async {
    goals = [
      for (final item in goals)
        item.id == id ? item.copyWith(completed: !item.completed) : item,
    ];
    notifyListeners();
    await _persistPlanner();
  }

  Future<void> deleteGoal(String id) async {
    goals = goals.where((item) => item.id != id).toList();
    tasks = [
      for (final task in tasks)
        task.goalId == id ? task.copyWith(clearGoal: true) : task,
    ];
    notifyListeners();
    await _persistPlanner();
  }

  Future<void> addTask({
    required String title,
    required DateTime dueDate,
    String? goalId,
    int estimatedMinutes = 30,
    StudyPriority priority = StudyPriority.normal,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    tasks = [
      ...tasks,
      StudyTask(
        id: _id('task'),
        title: trimmed,
        dueDate: dateOnly(dueDate),
        createdAt: DateTime.now(),
        goalId: goalId,
        estimatedMinutes: math.max(5, estimatedMinutes),
        priority: priority,
      ),
    ];
    notifyListeners();
    await _persistPlanner();
  }

  Future<void> toggleTask(String id) async {
    tasks = [
      for (final item in tasks)
        item.id == id ? item.copyWith(completed: !item.completed) : item,
    ];
    notifyListeners();
    await _persistPlanner();
  }

  Future<void> deleteTask(String id) async {
    tasks = tasks.where((item) => item.id != id).toList();
    notifyListeners();
    await _persistPlanner();
  }

  Future<void> logSession({
    required int minutes,
    required String label,
    String? taskId,
  }) async {
    if (minutes <= 0) return;
    sessions = [
      ...sessions,
      StudySession(
        id: _id('session'),
        startedAt: DateTime.now(),
        minutes: minutes,
        label: label.trim().isEmpty ? 'Focus session' : label.trim(),
        taskId: taskId,
      ),
    ];
    notifyListeners();
    await _persistPlanner();
  }

  List<StudyTask> tasksForDay(DateTime day) {
    final target = dateOnly(day);
    final values = tasks
        .where((item) => sameDay(item.dueDate, target))
        .toList();
    values.sort(_taskSort);
    return values;
  }

  List<StudyTask> get upcomingTasks {
    final today = dateOnly(DateTime.now());
    final values = tasks
        .where((item) => !item.completed && !item.dueDate.isBefore(today))
        .toList();
    values.sort((a, b) {
      final date = a.dueDate.compareTo(b.dueDate);
      return date != 0 ? date : _taskSort(a, b);
    });
    return values;
  }

  List<StudyGoal> get activeGoals {
    final values = goals.where((item) => !item.completed).toList();
    values.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return values;
  }

  int completedTasksOn(DateTime day) =>
      tasksForDay(day).where((item) => item.completed).length;

  double completionForDay(DateTime day) {
    final values = tasksForDay(day);
    if (values.isEmpty) return 0;
    return values.where((item) => item.completed).length / values.length;
  }

  int minutesOn(DateTime day) {
    return sessions
        .where((item) => sameDay(item.startedAt, day))
        .fold(0, (sum, item) => sum + item.minutes);
  }

  int get minutesThisWeek {
    final now = dateOnly(DateTime.now());
    final monday = now.subtract(Duration(days: now.weekday - DateTime.monday));
    return sessions
        .where((item) => !dateOnly(item.startedAt).isBefore(monday))
        .fold(0, (sum, item) => sum + item.minutes);
  }

  int get studyStreak {
    var day = dateOnly(DateTime.now());
    bool active(DateTime value) =>
        minutesOn(value) > 0 || completedTasksOn(value) > 0;
    if (!active(day)) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (active(day) && streak < 3650) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double goalProgress(StudyGoal goal) {
    final linkedTasks = tasks.where((item) => item.goalId == goal.id).toList();
    if (linkedTasks.isNotEmpty) {
      return linkedTasks.where((item) => item.completed).length /
          linkedTasks.length;
    }
    if (goal.targetMinutes > 0) {
      final minutes = sessions
          .where((item) => item.startedAt.isAfter(goal.createdAt))
          .fold(0, (sum, item) => sum + item.minutes);
      return (minutes / goal.targetMinutes).clamp(0, 1);
    }
    return goal.completed ? 1 : 0;
  }

  Future<void> addHighlight({
    required String path,
    required int page,
    required String text,
    required List<DocumentRect> rects,
    int colorValue = 0xFFFFD54F,
  }) async {
    if (path.isEmpty || rects.isEmpty) return;
    annotations = [
      ...annotations,
      DocumentAnnotation(
        id: _id('highlight'),
        path: path,
        page: math.max(1, page),
        kind: DocumentAnnotationKind.highlight,
        createdAt: DateTime.now(),
        text: text.trim(),
        colorValue: colorValue,
        rects: rects,
      ),
    ];
    notifyListeners();
    await _persistAnnotations();
  }

  Future<void> addPageNote({
    required String path,
    required int page,
    required String note,
    String selectedText = '',
  }) async {
    final trimmed = note.trim();
    if (path.isEmpty || trimmed.isEmpty) return;
    annotations = [
      ...annotations,
      DocumentAnnotation(
        id: _id('note'),
        path: path,
        page: math.max(1, page),
        kind: DocumentAnnotationKind.note,
        createdAt: DateTime.now(),
        text: selectedText.trim(),
        note: trimmed,
      ),
    ];
    notifyListeners();
    await _persistAnnotations();
  }

  Future<void> updateAnnotationNote(String id, String note) async {
    annotations = [
      for (final item in annotations)
        item.id == id ? item.copyWith(note: note.trim()) : item,
    ];
    notifyListeners();
    await _persistAnnotations();
  }

  Future<void> deleteAnnotation(String id) async {
    annotations = annotations.where((item) => item.id != id).toList();
    notifyListeners();
    await _persistAnnotations();
  }

  List<DocumentAnnotation> annotationsFor(String path, {int? page}) {
    final values = annotations.where(
      (item) => item.path == path && (page == null || item.page == page),
    );
    final result = values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  int annotationCount(String path) =>
      annotations.where((item) => item.path == path).length;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _taskSort(StudyTask a, StudyTask b) {
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final priority = b.priority.index.compareTo(a.priority.index);
    return priority != 0 ? priority : a.createdAt.compareTo(b.createdAt);
  }
}
