import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../workspace/study_workspace_controller.dart';
import 'premium_components.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, required this.workspace});

  final StudyWorkspaceController workspace;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late DateTime selectedDay;
  late DateTime focusedDay;
  CalendarFormat format = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    selectedDay = StudyWorkspaceController.dateOnly(DateTime.now());
    focusedDay = selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workspace,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final padding = width >= 1180
            ? 30.0
            : width >= 700
            ? 24.0
            : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlannerHero(
                      workspace: widget.workspace,
                      onAddTask: () => _showTaskSheet(selectedDay),
                      onAddGoal: _showGoalSheet,
                      onFocus: _openFocus,
                    ),
                    const SizedBox(height: 14),
                    if (width >= 960)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _CalendarPanel(
                              workspace: widget.workspace,
                              selectedDay: selectedDay,
                              focusedDay: focusedDay,
                              format: format,
                              onDaySelected: _selectDay,
                              onFormatChanged: (value) =>
                                  setState(() => format = value),
                              onPageChanged: (value) => focusedDay = value,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 5,
                            child: _AgendaPanel(
                              workspace: widget.workspace,
                              day: selectedDay,
                              onAdd: () => _showTaskSheet(selectedDay),
                              onFocus: _openFocus,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _CalendarPanel(
                        workspace: widget.workspace,
                        selectedDay: selectedDay,
                        focusedDay: focusedDay,
                        format: format,
                        onDaySelected: _selectDay,
                        onFormatChanged: (value) =>
                            setState(() => format = value),
                        onPageChanged: (value) => focusedDay = value,
                      ),
                      const SizedBox(height: 14),
                      _AgendaPanel(
                        workspace: widget.workspace,
                        day: selectedDay,
                        onAdd: () => _showTaskSheet(selectedDay),
                        onFocus: _openFocus,
                      ),
                    ],
                    const SizedBox(height: 28),
                    _SectionTitle(
                      eyebrow: 'OUTCOMES',
                      title: 'Active goals',
                      subtitle: 'Connect daily work to something larger than a checklist.',
                      action: 'New goal',
                      onAction: _showGoalSheet,
                    ),
                    const SizedBox(height: 13),
                    _GoalsGrid(
                      workspace: widget.workspace,
                      onAdd: _showGoalSheet,
                    ),
                    const SizedBox(height: 28),
                    const _SectionTitle(
                      eyebrow: 'INSIGHTS',
                      title: 'Your study rhythm',
                      subtitle:
                          'Seven days of focus time and completion momentum.',
                    ),
                    const SizedBox(height: 13),
                    _InsightsPanel(workspace: widget.workspace),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectDay(DateTime selected, DateTime focused) {
    setState(() {
      selectedDay = StudyWorkspaceController.dateOnly(selected);
      focusedDay = focused;
    });
  }

  Future<void> _showGoalSheet() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final minutes = TextEditingController();
    var due = DateTime.now().add(const Duration(days: 30));
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 24 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EyebrowLabel(icon: Icons.flag_rounded, text: 'New goal'),
                const SizedBox(height: 14),
                Text(
                  'What are you aiming for?',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    hintText: 'Finish GATE OS revision',
                    prefixIcon: Icon(Icons.track_changes_rounded),
                  ),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Why it matters (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target focus minutes (optional)',
                    hintText: '600',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _DateSelector(
                  label: 'Target date',
                  value: due,
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: due,
                    );
                    if (value != null) setSheetState(() => due = value);
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (title.text.trim().isEmpty) return;
                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Create goal'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (created == true) {
      await widget.workspace.addGoal(
        title: title.text,
        description: description.text,
        dueDate: due,
        targetMinutes: int.tryParse(minutes.text) ?? 0,
      );
    }
    title.dispose();
    description.dispose();
    minutes.dispose();
  }

  Future<void> _showTaskSheet(DateTime day) async {
    final title = TextEditingController();
    final minutes = TextEditingController(text: '30');
    var due = StudyWorkspaceController.dateOnly(day);
    var priority = StudyPriority.normal;
    String? goalId;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 24 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EyebrowLabel(
                  icon: Icons.check_circle_rounded,
                  text: 'New task',
                ),
                const SizedBox(height: 14),
                Text(
                  'Plan a concrete study block',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    hintText: 'Solve DBMS normalization PYQs',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 11),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 430;
                    final minuteField = TextField(
                      controller: minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                    );
                    final priorityField =
                        DropdownButtonFormField<StudyPriority>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: [
                            for (final value in StudyPriority.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_priorityLabel(value)),
                              ),
                          ],
                          onChanged: (value) => setSheetState(
                            () => priority = value ?? StudyPriority.normal,
                          ),
                        );
                    if (compact) {
                      return Column(
                        children: [
                          minuteField,
                          const SizedBox(height: 11),
                          priorityField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: minuteField),
                        const SizedBox(width: 10),
                        Expanded(child: priorityField),
                      ],
                    );
                  },
                ),
                if (widget.workspace.activeGoals.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  DropdownButtonFormField<String?>(
                    initialValue: goalId,
                    decoration: const InputDecoration(
                      labelText: 'Link to goal (optional)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No goal'),
                      ),
                      for (final goal in widget.workspace.activeGoals)
                        DropdownMenuItem<String?>(
                          value: goal.id,
                          child: Text(
                            goal.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setSheetState(() => goalId = value),
                  ),
                ],
                const SizedBox(height: 11),
                _DateSelector(
                  label: 'Scheduled for',
                  value: due,
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: due,
                    );
                    if (value != null) setSheetState(() => due = value);
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (title.text.trim().isEmpty) return;
                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Add to plan'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (created == true) {
      await widget.workspace.addTask(
        title: title.text,
        dueDate: due,
        goalId: goalId,
        estimatedMinutes: int.tryParse(minutes.text) ?? 30,
        priority: priority,
      );
    }
    title.dispose();
    minutes.dispose();
  }

  Future<void> _openFocus([StudyTask? task]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FocusDialog(workspace: widget.workspace, task: task),
    );
  }
}

class _PlannerHero extends StatelessWidget {
  const _PlannerHero({
    required this.workspace,
    required this.onAddTask,
    required this.onAddGoal,
    required this.onFocus,
  });

  final StudyWorkspaceController workspace;
  final VoidCallback onAddTask;
  final VoidCallback onAddGoal;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = workspace.tasksForDay(DateTime.now());
    final completed = tasks.where((item) => item.completed).length;
    final fraction = tasks.isEmpty ? 0.0 : completed / tasks.length;
    return GradientBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowLabel(
            icon: Icons.calendar_month_rounded,
            text: 'Planner',
          ),
          const SizedBox(height: 14),
          Text(
            'Plan less.\nFinish more.',
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w900, height: 0.96),
          ),
          const SizedBox(height: 9),
          Text(
            '${workspace.activeGoals.length} active goals • ${workspace.upcomingTasks.length} upcoming tasks',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              FilledButton.icon(
                onPressed: onFocus,
                icon: const Icon(Icons.timer_rounded),
                label: const Text('Start focus'),
              ),
              OutlinedButton.icon(
                onPressed: onAddTask,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Task'),
              ),
              TextButton.icon(
                onPressed: onAddGoal,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Goal'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                icon: Icons.donut_large_rounded,
                value: '${(fraction * 100).round()}%',
                label: 'today complete',
                accent: scheme.primary,
              ),
              _HeroMetric(
                icon: Icons.check_circle_outline_rounded,
                value: '$completed/${tasks.length}',
                label: 'tasks today',
                accent: scheme.secondary,
              ),
              _HeroMetric(
                icon: Icons.local_fire_department_rounded,
                value: '${workspace.studyStreak}',
                label: 'day streak',
                accent: scheme.tertiary,
              ),
              _HeroMetric(
                icon: Icons.schedule_rounded,
                value: '${workspace.minutesOn(DateTime.now())}',
                label: 'focus min today',
                accent: scheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.workspace,
    required this.selectedDay,
    required this.focusedDay,
    required this.format,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final StudyWorkspaceController workspace;
  final DateTime selectedDay;
  final DateTime focusedDay;
  final CalendarFormat format;
  final void Function(DateTime, DateTime) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      child: TableCalendar<Object>(
        firstDay: DateTime.now().subtract(const Duration(days: 730)),
        lastDay: DateTime.now().add(const Duration(days: 3650)),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) =>
            StudyWorkspaceController.sameDay(day, selectedDay),
        calendarFormat: format,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
          CalendarFormat.twoWeeks: '2 weeks',
          CalendarFormat.week: 'Week',
        },
        onFormatChanged: onFormatChanged,
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        eventLoader: (day) {
          final values = <Object>[...workspace.tasksForDay(day)];
          values.addAll(
            workspace.activeGoals.where(
              (goal) => StudyWorkspaceController.sameDay(goal.dueDate, day),
            ),
          );
          return values;
        },
        headerStyle: HeaderStyle(
          titleCentered: false,
          formatButtonVisible: true,
          formatButtonDecoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          formatButtonTextStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: scheme.onSurfaceVariant),
          weekendStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: scheme.secondary.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.secondary.withValues(alpha: 0.5)),
          ),
          todayTextStyle: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
          selectedDecoration: BoxDecoration(
            gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          markerDecoration: BoxDecoration(
            color: scheme.secondary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
      ),
    );
  }
}

class _AgendaPanel extends StatelessWidget {
  const _AgendaPanel({
    required this.workspace,
    required this.day,
    required this.onAdd,
    required this.onFocus,
  });

  final StudyWorkspaceController workspace;
  final DateTime day;
  final VoidCallback onAdd;
  final ValueChanged<StudyTask?> onFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = workspace.tasksForDay(day);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullDate(day),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${tasks.length} planned • ${workspace.minutesOn(day)} focus min',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Add task',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (tasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 42,
                      color: scheme.primary.withValues(alpha: 0.60),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Nothing scheduled',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Plan a study block'),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final task in tasks) ...[
              _TaskTile(
                task: task,
                workspace: workspace,
                onFocus: () => onFocus(task),
              ),
              if (task != tasks.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.workspace,
    required this.onFocus,
  });

  final StudyTask task;
  final StudyWorkspaceController workspace;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goal = task.goalId == null
        ? null
        : workspace.goals.where((item) => item.id == task.goalId).firstOrNull;
    return Material(
      color: task.completed
          ? scheme.surfaceContainerLow.withValues(alpha: 0.55)
          : scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
        child: Row(
          children: [
            Checkbox(
              value: task.completed,
              onChanged: (_) => workspace.toggleTask(task.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: task.completed
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.estimatedMinutes} min${goal == null ? '' : ' • ${goal.title}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!task.completed)
              IconButton(
                tooltip: 'Focus on this',
                visualDensity: VisualDensity.compact,
                onPressed: onFocus,
                icon: const Icon(Icons.timer_outlined),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') workspace.deleteTask(task.id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete task')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsGrid extends StatelessWidget {
  const _GoalsGrid({required this.workspace, required this.onAdd});

  final StudyWorkspaceController workspace;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final goals = workspace.activeGoals;
    if (goals.isEmpty) {
      return GlassPanel(
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 9,
            runSpacing: 7,
            children: [
              const Icon(Icons.add_circle_outline_rounded),
              Text(
                'Create your first goal',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1040
            ? 3
            : constraints.maxWidth > 650
            ? 2
            : 1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: columns == 1 ? 1.65 : 1.35,
          children: [
            for (final goal in goals)
              _GoalCard(goal: goal, workspace: workspace),
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.workspace});

  final StudyGoal goal;
  final StudyWorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = workspace.goalProgress(goal);
    final linked = workspace.tasks
        .where((item) => item.goalId == goal.id)
        .toList();
    final done = linked.where((item) => item.completed).length;
    final days = StudyWorkspaceController.dateOnly(goal.dueDate)
        .difference(StudyWorkspaceController.dateOnly(DateTime.now()))
        .inDays;
    return GlassPanel(
      glow: days >= 0 && days <= 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetricRing(
                value: progress,
                size: 58,
                strokeWidth: 6,
                center: Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'complete') workspace.toggleGoal(goal.id);
                  if (value == 'delete') workspace.deleteGoal(goal.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'complete',
                    child: Text('Mark complete'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete goal')),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            goal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              _MiniLabel(
                icon: Icons.event_rounded,
                text: days < 0
                    ? '${-days}d overdue'
                    : days == 0
                    ? 'Due today'
                    : '$days days left',
                color: days < 0 ? scheme.error : scheme.primary,
              ),
              _MiniLabel(
                icon: Icons.check_circle_outline_rounded,
                text: '$done/${linked.length} tasks',
                color: scheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.workspace});

  final StudyWorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    final now = StudyWorkspaceController.dateOnly(DateTime.now());
    final days = List<DateTime>.generate(
      7,
      (index) => now.subtract(Duration(days: 6 - index)),
    );
    final minutes = [for (final day in days) workspace.minutesOn(day)];
    final maxMinutes = minutes.fold<int>(
      30,
      (value, item) => item > value ? item : value,
    );
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 175,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < days.length; index++)
                  Expanded(
                    child: _DayBar(
                      day: days[index],
                      minutes: minutes[index],
                      maxMinutes: maxMinutes,
                      completion: workspace.completionForDay(days[index]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InsightChip(
                value: '${workspace.minutesThisWeek}',
                label: 'minutes this week',
              ),
              _InsightChip(
                value: '${workspace.studyStreak}',
                label: 'day streak',
              ),
              _InsightChip(
                value:
                    '${workspace.tasks.where((item) => item.completed).length}',
                label: 'tasks completed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.minutes,
    required this.maxMinutes,
    required this.completion,
  });

  final DateTime day;
  final int minutes;
  final int maxMinutes;
  final double completion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = minutes == 0 ? 5.0 : 18 + (minutes / maxMinutes) * 100;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          child: Text(
            minutes == 0 ? '' : '$minutes',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        Tooltip(
          message:
              '$minutes focus minutes • ${(completion * 100).round()}% tasks done',
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _weekday(day.weekday),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FocusDialog extends StatefulWidget {
  const _FocusDialog({required this.workspace, this.task});

  final StudyWorkspaceController workspace;
  final StudyTask? task;

  @override
  State<_FocusDialog> createState() => _FocusDialogState();
}

class _FocusDialogState extends State<_FocusDialog> {
  Timer? timer;
  int totalSeconds = 25 * 60;
  int remainingSeconds = 25 * 60;
  bool running = false;
  bool completed = false;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _setMinutes(int minutes) {
    if (running) return;
    setState(() {
      totalSeconds = minutes * 60;
      remainingSeconds = totalSeconds;
      completed = false;
    });
  }

  void _toggle() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    if (remainingSeconds <= 0) return;
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remainingSeconds <= 1) {
        timer?.cancel();
        setState(() {
          remainingSeconds = 0;
          running = false;
          completed = true;
        });
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  Future<void> _finish() async {
    timer?.cancel();
    final elapsed = totalSeconds - remainingSeconds;
    final minutes = (elapsed / 60).round();
    if (minutes > 0) {
      await widget.workspace.logSession(
        minutes: minutes,
        label: widget.task?.title ?? 'Focus session',
        taskId: widget.task?.id,
      );
    }
    if (completed && widget.task != null && !widget.task!.completed) {
      await widget.workspace.toggleTask(widget.task!.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = totalSeconds == 0 ? 0.0 : remainingSeconds / totalSeconds;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final size = MediaQuery.sizeOf(context);
    final ringSize = size.width < 380 ? 160.0 : 200.0;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: EyebrowLabel(
                      icon: Icons.center_focus_strong,
                      text: 'Focus',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close and save elapsed time',
                    onPressed: _finish,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.task?.title ?? 'Deep work',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              SizedBox.square(
                dimension: ringSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: scheme.onSurface.withValues(
                          alpha: 0.06,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(
                            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                ),
                          ),
                        ),
                        Text(
                          completed
                              ? 'session complete'
                              : running
                              ? 'stay with it'
                              : 'ready',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!running && remainingSeconds == totalSeconds)
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final value in [25, 40, 50, 90])
                      ChoiceChip(
                        label: Text('$value min'),
                        selected: totalSeconds == value * 60,
                        onSelected: (_) => _setMinutes(value),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                alignment: WrapAlignment.center,
                children: [
                  if (!completed)
                    FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(
                        running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(running ? 'Pause' : 'Start'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _finish,
                    icon: Icon(
                      completed ? Icons.check_rounded : Icons.stop_rounded,
                    ),
                    label: Text(completed ? 'Save' : 'Finish'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.event_rounded, color: scheme.primary),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      _fullDate(value),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              if (action != null && onAction != null) ...[
                const SizedBox(height: 5),
                TextButton(onPressed: onAction, child: Text(action!)),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            if (action != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        );
      },
    );
  }
}

String _priorityLabel(StudyPriority value) => switch (value) {
  StudyPriority.low => 'Low',
  StudyPriority.normal => 'Normal',
  StudyPriority.high => 'High',
};

String _weekday(int value) => switch (value) {
  DateTime.monday => 'M',
  DateTime.tuesday => 'T',
  DateTime.wednesday => 'W',
  DateTime.thursday => 'T',
  DateTime.friday => 'F',
  DateTime.saturday => 'S',
  _ => 'S',
};

String _fullDate(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
