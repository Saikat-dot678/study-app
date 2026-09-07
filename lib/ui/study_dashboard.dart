import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import '../workspace/study_workspace_controller.dart';
import 'actions.dart';
import 'library_widgets.dart';
import 'motion.dart';
import 'premium_components.dart';

class StudyDashboard extends StatelessWidget {
  const StudyDashboard({
    super.key,
    required this.controller,
    required this.workspace,
    required this.openLibrary,
    required this.openSearch,
    required this.openGoals,
  });

  final LibraryController controller;
  final StudyWorkspaceController workspace;
  final ValueChanged<String?> openLibrary;
  final VoidCallback openSearch;
  final VoidCallback openGoals;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) {
      return ConnectLibraryView(controller: controller);
    }
    return AnimatedBuilder(
      animation: workspace,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final horizontal = width >= 1180 ? 30.0 : width >= 700 ? 24.0 : 16.0;
        final today = StudyWorkspaceController.dateOnly(DateTime.now());
        final todayTasks = workspace.tasksForDay(today);
        final nextTask = workspace.upcomingTasks.firstOrNull;
        final recent = controller.recentFiles.take(6).toList();
        final spaces = controller.rootSpaces.take(7).toList();
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 130),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredReveal(
                        child: _CommandStrip(
                          onSearch: openSearch,
                          onImport: () => showAddSheet(
                            context,
                            controller,
                            fromHome: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaggeredReveal(
                        index: 1,
                        child: _HeroBento(
                          controller: controller,
                          workspace: workspace,
                          nextTask: nextTask,
                          onGoals: openGoals,
                          onInbox: () => openLibrary('Inbox'),
                          onCreateSpace: () =>
                              showCreateSpaceSheet(context, controller),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ResponsiveBento(
                        children: [
                          StaggeredReveal(
                            index: 2,
                            child: _TodayCard(
                              workspace: workspace,
                              tasks: todayTasks,
                              onOpen: openGoals,
                            ),
                          ),
                          StaggeredReveal(
                            index: 3,
                            child: _MomentumCard(workspace: workspace),
                          ),
                          StaggeredReveal(
                            index: 4,
                            child: _GoalsCard(
                              workspace: workspace,
                              onOpen: openGoals,
                            ),
                          ),
                        ],
                      ),
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _SectionHeader(
                          eyebrow: 'RESUME',
                          title: 'Continue learning',
                          subtitle:
                              'Your recent material, exactly where you left it.',
                          action: 'Library',
                          onAction: () => openLibrary(null),
                        ),
                        const SizedBox(height: 13),
                        SizedBox(
                          height: 210,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recent.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final entry = recent[index];
                              return SizedBox(
                                width: width < 520 ? 280 : 320,
                                child: _ContinueCard(
                                  entry: entry,
                                  progress: controller.progressFor(entry.path)?.fraction ?? 0,
                                  onTap: () => openStudyViewer(
                                    context,
                                    controller,
                                    entry,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      _SectionHeader(
                        eyebrow: 'SPACES',
                        title: 'Your study universe',
                        subtitle:
                            'Semester, GATE, research, projects — one hierarchy, no artificial limits.',
                        action: 'Open library',
                        onAction: () => openLibrary(null),
                      ),
                      const SizedBox(height: 13),
                      _SpaceGrid(
                        controller: controller,
                        spaces: spaces,
                        onOpen: (path) => openLibrary(path),
                        onCreate: () => showCreateSpaceSheet(context, controller),
                      ),
                      const SizedBox(height: 30),
                      _LibraryPulse(controller: controller),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommandStrip extends StatelessWidget {
  const _CommandStrip({required this.onSearch, required this.onImport});
  final VoidCallback onSearch;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: GlassPanel(
            radius: 18,
            padding: EdgeInsets.zero,
            onTap: onSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Find anything in your study system…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 600)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'CTRL K',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'Add material',
          onPressed: onImport,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _HeroBento extends StatelessWidget {
  const _HeroBento({
    required this.controller,
    required this.workspace,
    required this.nextTask,
    required this.onGoals,
    required this.onInbox,
    required this.onCreateSpace,
  });

  final LibraryController controller;
  final StudyWorkspaceController workspace;
  final StudyTask? nextTask;
  final VoidCallback onGoals;
  final VoidCallback onInbox;
  final VoidCallback onCreateSpace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > 840;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final materialCount = controller.allEntries.where((e) => !e.isDirectory).length;
    final next = nextTask;
    return GradientBorderCard(
      padding: EdgeInsets.all(wide ? 28 : 21),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -70,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.secondary.withValues(alpha: 0.17),
                      scheme.secondary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const EyebrowLabel(
                    icon: Icons.bolt_rounded,
                    text: 'Study OS',
                  ),
                  const Spacer(),
                  Text(
                    '$materialCount materials • offline',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: wide ? 38 : 28),
              Text(
                '$greeting.\nMake today count.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: wide ? 48 : 34,
                  height: 0.96,
                  letterSpacing: -1.7,
                ),
              ),
              const SizedBox(height: 13),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  next == null
                      ? 'Your library, goals, focus sessions and reading progress now live in one calm workspace.'
                      : 'Next up: ${next.title} • ${_friendlyDate(next.dueDate)} • ${next.estimatedMinutes} min',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onGoals,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(next == null ? 'Plan today' : 'Open agenda'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onInbox,
                    icon: const Icon(Icons.inbox_rounded),
                    label: const Text('Inbox'),
                  ),
                  TextButton.icon(
                    onPressed: onCreateSpace,
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('New space'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResponsiveBento extends StatelessWidget {
  const _ResponsiveBento({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: children[0]),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: children[1]),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: children[2]),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.workspace,
    required this.tasks,
    required this.onOpen,
  });

  final StudyWorkspaceController workspace;
  final List<StudyTask> tasks;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = tasks.where((item) => item.completed).length;
    final fraction = tasks.isEmpty ? 0.0 : complete / tasks.length;
    final next = tasks.where((item) => !item.completed).firstOrNull;
    return GlassPanel(
      onTap: onOpen,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded, color: scheme.primary),
              const SizedBox(width: 9),
              const Text('Today', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, color: scheme.onSurfaceVariant, size: 18),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              MetricRing(
                value: fraction,
                center: Text(
                  '${(fraction * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tasks.isEmpty ? 'A clear day' : '$complete / ${tasks.length} done',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      next?.title ?? 'Add a task or goal when you are ready.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MomentumCard extends StatelessWidget {
  const _MomentumCard({required this.workspace});
  final StudyWorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final values = List<double>.generate(
      7,
      (index) => workspace
          .minutesOn(now.subtract(Duration(days: 6 - index)))
          .toDouble(),
    );
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: scheme.tertiary),
              const SizedBox(width: 8),
              const Text('Momentum', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${workspace.studyStreak}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            workspace.studyStreak == 1 ? 'day streak' : 'day streak',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TinySparkline(values: values),
          const SizedBox(height: 5),
          Text(
            '${workspace.minutesThisWeek} min this week',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.workspace, required this.onOpen});
  final StudyWorkspaceController workspace;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goals = workspace.activeGoals.take(3).toList();
    return GlassPanel(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_circle_rounded, color: scheme.secondary),
              const SizedBox(width: 8),
              const Text('Goals', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(
                '${workspace.activeGoals.length} active',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (goals.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No active goals yet.\nTurn an intention into a plan.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final goal in goals) ...[
              _GoalLine(goal: goal, progress: workspace.goalProgress(goal)),
              if (goal != goals.last) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.goal, required this.progress});
  final StudyGoal goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _compactDate(goal.dueDate),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.entry,
    required this.progress,
    required this.onTap,
  });
  final LibraryEntry entry;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      onTap: onTap,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FileIcon(entry: entry, large: true, heroTag: 'entry:${entry.path}'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: scheme.primary.withValues(alpha: 0.10),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress <= 0 ? 0.02 : progress,
              minHeight: 5,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceGrid extends StatelessWidget {
  const _SpaceGrid({
    required this.controller,
    required this.spaces,
    required this.onOpen,
    required this.onCreate,
  });
  final LibraryController controller;
  final List<LibraryEntry> spaces;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1160 ? 4 : width > 760 ? 3 : width > 430 ? 2 : 1;
    final cards = <Widget>[
      for (final space in spaces)
        _SpaceCard(
          entry: space,
          materials: controller.materialCountUnder(space.path),
          folders: controller.directFolderCount(space.path),
          onTap: () => onOpen(space.path),
        ),
      _NewSpaceCard(onTap: onCreate),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      childAspectRatio: columns == 1 ? 2.0 : 1.38,
      children: cards,
    );
  }
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({
    required this.entry,
    required this.materials,
    required this.folders,
    required this.onTap,
  });
  final LibraryEntry entry;
  final int materials;
  final int folders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.24),
                      scheme.secondary.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: Icon(Icons.folder_rounded, color: scheme.primary),
              ),
              const Spacer(),
              Icon(Icons.north_east_rounded, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
          const Spacer(),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '$folders folders • $materials materials',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSpaceCard extends StatelessWidget {
  const _NewSpaceCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverLift(
      child: Material(
        color: scheme.primary.withValues(alpha: 0.055),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.add_circle_outline_rounded, color: scheme.primary, size: 32),
                const Spacer(),
                const Text('Create a space', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Semester, exam, research or blank',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryPulse extends StatelessWidget {
  const _LibraryPulse({required this.controller});
  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final files = controller.allEntries.where((item) => !item.isDirectory).length;
    final favorites = controller.favoriteEntries.where((item) => !item.isDirectory).length;
    final annotations = StudyWorkspaceController.instance.annotations.length;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        spacing: 22,
        runSpacing: 13,
        children: [
          _PulseMetric(icon: Icons.layers_rounded, value: '$files', label: 'materials'),
          _PulseMetric(
            icon: Icons.folder_special_rounded,
            value: '${controller.rootSpaces.length}',
            label: 'spaces',
          ),
          _PulseMetric(icon: Icons.star_rounded, value: '$favorites', label: 'starred'),
          _PulseMetric(
            icon: Icons.draw_rounded,
            value: '$annotations',
            label: 'annotations',
          ),
          const _PulseMetric(icon: Icons.lock_rounded, value: '100%', label: 'offline'),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: scheme.primary, size: 18),
        const SizedBox(width: 7),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

String _friendlyDate(DateTime date) {
  final today = StudyWorkspaceController.dateOnly(DateTime.now());
  final target = StudyWorkspaceController.dateOnly(date);
  final days = target.difference(today).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7 && days > 1) return 'in $days days';
  return _compactDate(date);
}

String _compactDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
