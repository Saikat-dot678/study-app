import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../models/study_metadata.dart';
import '../viewers/viewer_page.dart';
import '../workspace/study_workspace_controller.dart';
import 'actions.dart';
import 'library_widgets.dart';
import 'premium_components.dart';

/// Home is a starting point, not a report.
///
/// It answers three questions in order: what should I do now, where did I stop,
/// and where is my material? Every responsive branch has finite card geometry;
/// no flex child is placed on the unbounded axis of the scroll view.
class StudyDashboard extends StatelessWidget {
  const StudyDashboard({
    super.key,
    required this.controller,
    required this.workspace,
    required this.openLibrary,
    required this.openGoals,
  });

  final LibraryController controller;
  final StudyWorkspaceController workspace;
  final ValueChanged<String?> openLibrary;
  final VoidCallback openGoals;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) {
      return ConnectLibraryView(controller: controller);
    }

    final today = StudyWorkspaceController.dateOnly(DateTime.now());
    final tasks = workspace.tasksForDay(today);
    final recent = controller.recentFiles.take(8).toList();
    final spaces = controller.rootSpaces.take(12).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final horizontal = contentWidth >= 1100
            ? 32.0
            : contentWidth >= 680
            ? 24.0
            : 16.0;
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            key: const PageStorageKey('study-home-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: _HomeHeader(
                        materialCount: controller.materialCountUnder(''),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: _TodayComposition(
                        width: contentWidth,
                        tasks: tasks,
                        workspace: workspace,
                        onGoals: openGoals,
                        onInbox: () => openLibrary('Inbox'),
                        onAdd: () =>
                            showAddSheet(context, controller, fromHome: true),
                      ),
                    ),
                  ),
                ),
              ),
              if (recent.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 32, horizontal, 12),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: _SectionHeading(
                          label: 'Continue',
                          title: 'Pick up where you left off',
                          action: 'View library',
                          onAction: () => openLibrary(null),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 190,
                    child: ListView.separated(
                      key: const PageStorageKey('home-recent'),
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final entry = recent[index];
                        return SizedBox(
                          width: contentWidth < 520 ? 276 : 304,
                          child: _RecentMaterialCard(
                            entry: entry,
                            progress: controller.progressFor(entry.path),
                            onTap: () =>
                                openStudyViewer(context, controller, entry),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 32, horizontal, 12),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: _SectionHeading(
                        label: 'Library',
                        title: 'Study spaces',
                        action: 'Browse all',
                        onAction: () => openLibrary(null),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: _SpacesWrap(
                        controller: controller,
                        spaces: spaces,
                        onOpen: (path) => openLibrary(path),
                        onCreate: () =>
                            showCreateSpaceSheet(context, controller),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 30, horizontal, 120),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: _LibrarySummary(
                        controller: controller,
                        workspace: workspace,
                      ),
                    ),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.materialCount});

  final int materialCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _longDate(now).toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text('$greeting.', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 5),
        Text(
          '$materialCount local material${materialCount == 1 ? '' : 's'} ready when you are.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TodayComposition extends StatelessWidget {
  const _TodayComposition({
    required this.width,
    required this.tasks,
    required this.workspace,
    required this.onGoals,
    required this.onInbox,
    required this.onAdd,
  });

  final double width;
  final List<StudyTask> tasks;
  final StudyWorkspaceController workspace;
  final VoidCallback onGoals;
  final VoidCallback onInbox;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final next =
        tasks.where((item) => !item.completed).firstOrNull ??
        workspace.upcomingTasks.firstOrNull;
    final primary = _FocusBrief(
      next: next,
      onGoals: onGoals,
      onAdd: onAdd,
      onInbox: onInbox,
    );
    final agenda = _TodayAgenda(
      tasks: tasks,
      workspace: workspace,
      onOpen: onGoals,
    );

    if (width < 820) {
      return Column(children: [primary, const SizedBox(height: 12), agenda]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: primary),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: agenda),
      ],
    );
  }
}

class _FocusBrief extends StatelessWidget {
  const _FocusBrief({
    required this.next,
    required this.onGoals,
    required this.onAdd,
    required this.onInbox,
  });

  final StudyTask? next;
  final VoidCallback onGoals;
  final VoidCallback onAdd;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: scheme.onPrimary, size: 18),
              const SizedBox(width: 7),
              Text(
                'NEXT MOVE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            next?.title ?? 'Shape a focused day',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: scheme.onPrimary, height: 1.08),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Choose one outcome, protect the time, and keep your materials close.'
                : '${next!.estimatedMinutes} min  •  ${_relativeDate(next!.dueDate)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimary,
                  foregroundColor: scheme.primary,
                ),
                onPressed: onGoals,
                icon: Icon(
                  next == null
                      ? Icons.add_task_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(next == null ? 'Plan today' : 'Open agenda'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.onPrimary),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add material'),
              ),
              IconButton(
                tooltip: 'Open Inbox',
                style: IconButton.styleFrom(foregroundColor: scheme.onPrimary),
                onPressed: onInbox,
                icon: const Icon(Icons.inbox_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayAgenda extends StatelessWidget {
  const _TodayAgenda({
    required this.tasks,
    required this.workspace,
    required this.onOpen,
  });

  final List<StudyTask> tasks;
  final StudyWorkspaceController workspace;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = tasks.where((item) => item.completed).length;
    final fraction = tasks.isEmpty ? 0.0 : complete / tasks.length;
    final pending = tasks.where((item) => !item.completed).take(2).toList();
    return GlassPanel(
      onTap: onOpen,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Today',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                tasks.isEmpty ? 'Open' : '$complete/${tasks.length}',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            Text(
              tasks.isEmpty
                  ? 'Nothing scheduled. Use the space for deep work or plan a small next step.'
                  : 'Everything planned for today is complete.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            )
          else
            for (var i = 0; i < pending.length; i++) ...[
              _AgendaLine(task: pending[i]),
              if (i != pending.length - 1) const SizedBox(height: 11),
            ],
          const SizedBox(height: 15),
          Text(
            '${workspace.minutesThisWeek} focused min this week  •  ${workspace.studyStreak} day streak',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AgendaLine extends StatelessWidget {
  const _AgendaLine({required this.task});
  final StudyTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (task.priority) {
      StudyPriority.high => scheme.tertiary,
      StudyPriority.normal => scheme.primary,
      StudyPriority.low => scheme.secondary,
    };
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${task.estimatedMinutes}m',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.label,
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String label;
  final String title;
  final String action;
  final VoidCallback onAction;

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
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    );
  }
}

class _RecentMaterialCard extends StatelessWidget {
  const _RecentMaterialCard({
    required this.entry,
    required this.progress,
    required this.onTap,
  });

  final LibraryEntry entry;
  final StudyProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = progress?.fraction ?? 0;
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FileIcon(entry: entry),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHigh,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value > 0
                    ? '${(value * 100).round()}%'
                    : entry.extension.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpacesWrap extends StatelessWidget {
  const _SpacesWrap({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        const gap = 12.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final space in spaces)
              SizedBox(
                width: itemWidth,
                height: 142,
                child: _SpaceTile(
                  entry: space,
                  materials: controller.materialCountUnder(space.path),
                  folders: controller.directFolderCount(space.path),
                  pinned: controller.isPinned(space.path),
                  onTap: () => onOpen(space.path),
                ),
              ),
            SizedBox(
              width: itemWidth,
              height: 142,
              child: _NewSpaceTile(onTap: onCreate),
            ),
          ],
        );
      },
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({
    required this.entry,
    required this.materials,
    required this.folders,
    required this.pinned,
    required this.onTap,
  });

  final LibraryEntry entry;
  final int materials;
  final int folders;
  final bool pinned;
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
              Icon(Icons.folder_rounded, color: scheme.primary, size: 27),
              const Spacer(),
              if (pinned)
                Icon(Icons.push_pin_rounded, color: scheme.tertiary, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$materials material${materials == 1 ? '' : 's'}  •  $folders folder${folders == 1 ? '' : 's'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NewSpaceTile extends StatelessWidget {
  const _NewSpaceTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: scheme.primary),
              const Spacer(),
              Text(
                'New study space',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Start blank or from a structure',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({required this.controller, required this.workspace});

  final LibraryController controller;
  final StudyWorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    final files = controller.materialCountUnder('');
    final favorites = controller.favoriteEntries
        .where((entry) => !entry.isDirectory)
        .length;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Wrap(
          spacing: 26,
          runSpacing: 12,
          children: [
            _SummaryMetric(value: '$files', label: 'materials'),
            _SummaryMetric(
              value: '${controller.rootSpaces.length}',
              label: 'spaces',
            ),
            _SummaryMetric(value: '$favorites', label: 'starred'),
            _SummaryMetric(
              value: '${workspace.annotations.length}',
              label: 'annotations',
            ),
            const _SummaryMetric(value: 'Local', label: 'storage mode'),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

String _longDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _relativeDate(DateTime date) {
  final today = StudyWorkspaceController.dateOnly(DateTime.now());
  final target = StudyWorkspaceController.dateOnly(date);
  final days = target.difference(today).inDays;
  if (days == 0) return 'due today';
  if (days == 1) return 'due tomorrow';
  if (days > 1 && days < 7) return 'due in $days days';
  return 'due ${date.day}/${date.month}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
