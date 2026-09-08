import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../models/study_metadata.dart';
import '../theme.dart';
import '../viewers/viewer_page.dart';
import '../workspace/study_workspace_controller.dart';
import 'actions.dart';
import 'library_widgets.dart';
import 'premium_components.dart';

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
    if (!controller.connected) return ConnectLibraryView(controller: controller);

    final today = StudyWorkspaceController.dateOnly(DateTime.now());
    final tasks = workspace.tasksForDay(today);
    final recent = controller.recentFiles.take(6).toList();
    final spaces = controller.rootSpaces.take(8).toList();
    final active = recent.firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 1100
            ? 34.0
            : constraints.maxWidth >= 680
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
                  child: _Centered(
                    child: _HomeHeader(controller: controller, workspace: workspace),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: _Centered(
                    child: _PrimaryComposition(
                      width: constraints.maxWidth,
                      active: active,
                      controller: controller,
                      tasks: tasks,
                      workspace: workspace,
                      onOpenActive: active == null
                          ? null
                          : () => openStudyViewer(context, controller, active),
                      onPlanner: openGoals,
                      onInbox: () => openLibrary('Inbox'),
                      onAdd: () => showAddSheet(context, controller, fromHome: true),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: _Centered(
                    child: _QuickActions(
                      onLibrary: () => openLibrary(null),
                      onPlanner: openGoals,
                      onInbox: () => openLibrary('Inbox'),
                      onAdd: () => showAddSheet(context, controller, fromHome: true),
                      inboxCount: controller.materialCountUnder('Inbox'),
                    ),
                  ),
                ),
              ),
              if (recent.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 30, horizontal, 10),
                  sliver: SliverToBoxAdapter(
                    child: _Centered(
                      child: _SectionHeading(
                        title: 'Recent',
                        detail: 'Materials you opened lately',
                        action: 'Library',
                        onAction: () => openLibrary(null),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  sliver: SliverToBoxAdapter(
                    child: _Centered(
                      child: _RecentGrid(
                        entries: recent,
                        controller: controller,
                        onOpen: (entry) => openStudyViewer(context, controller, entry),
                      ),
                    ),
                  ),
                ),
              ],
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 30, horizontal, 10),
                sliver: SliverToBoxAdapter(
                  child: _Centered(
                    child: _SectionHeading(
                      title: 'Study spaces',
                      detail: '${controller.materialCountUnder('')} materials',
                      action: 'Browse',
                      onAction: () => openLibrary(null),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 110),
                sliver: SliverToBoxAdapter(
                  child: _Centered(
                    child: _SpacesStrip(
                      controller: controller,
                      spaces: spaces,
                      onOpen: openLibrary,
                      onCreate: () => showCreateSpaceSheet(context, controller),
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

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: child,
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.controller, required this.workspace});
  final LibraryController controller;
  final StudyWorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StudyColors.of(context);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning.'
        : now.hour < 17
        ? 'Good afternoon.'
        : 'Good evening.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _longDate(now),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: palette.ambientAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(greeting, style: Theme.of(context).textTheme.headlineLarge),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 720)
          Row(
            children: [
              _HeaderStat(
                value: '${workspace.minutesThisWeek}',
                label: 'min this week',
                color: palette.research,
              ),
              const SizedBox(width: 20),
              _HeaderStat(
                value: '${workspace.studyStreak}',
                label: 'day streak',
                color: palette.project,
              ),
              const SizedBox(width: 20),
              _HeaderStat(
                value: '${controller.materialCountUnder('')}',
                label: 'materials',
                color: scheme.primary,
              ),
            ],
          ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PrimaryComposition extends StatelessWidget {
  const _PrimaryComposition({
    required this.width,
    required this.active,
    required this.controller,
    required this.tasks,
    required this.workspace,
    required this.onOpenActive,
    required this.onPlanner,
    required this.onInbox,
    required this.onAdd,
  });

  final double width;
  final LibraryEntry? active;
  final LibraryController controller;
  final List<StudyTask> tasks;
  final StudyWorkspaceController workspace;
  final VoidCallback? onOpenActive;
  final VoidCallback onPlanner;
  final VoidCallback onInbox;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final study = _ActiveStudy(
      entry: active,
      progress: active == null ? null : controller.progressFor(active!.path),
      onOpen: onOpenActive,
      onLibrary: onAdd,
    );
    final agenda = _TodayPanel(
      tasks: tasks,
      workspace: workspace,
      onOpen: onPlanner,
      onInbox: onInbox,
    );
    if (width < 880) {
      return Column(children: [study, const SizedBox(height: 14), agenda]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: study),
        const SizedBox(width: 14),
        Expanded(flex: 5, child: agenda),
      ],
    );
  }
}

class _ActiveStudy extends StatelessWidget {
  const _ActiveStudy({
    required this.entry,
    required this.progress,
    required this.onOpen,
    required this.onLibrary,
  });

  final LibraryEntry? entry;
  final StudyProgress? progress;
  final VoidCallback? onOpen;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StudyColors.of(context);
    final fraction = progress?.fraction ?? 0;
    final pageText = progress == null || progress!.pageCount <= 0
        ? null
        : 'Page ${progress!.page} of ${progress!.pageCount}';
    final title = entry?.name ?? 'Choose something to study';
    final path = entry?.path ?? 'Open your library or add material to begin.';
    final accent = entry == null ? palette.folder : _entryColor(context, entry!);

    return Container(
      constraints: const BoxConstraints(minHeight: 258),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(width: 7, child: ColoredBox(color: accent)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(31, 22, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTINUE STUDYING',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry != null) FileIcon(entry: entry!, large: true),
                    if (entry != null) const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            path,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (entry != null) ...[
                  if (pageText != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(fraction * 100).round()}%',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  if (pageText != null) const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: fraction, minHeight: 5),
                  ),
                  const SizedBox(height: 17),
                ],
                FilledButton.icon(
                  onPressed: onOpen ?? onLibrary,
                  icon: Icon(entry == null ? Icons.add_rounded : Icons.play_arrow_rounded),
                  label: Text(entry == null ? 'Add material' : 'Resume'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.tasks,
    required this.workspace,
    required this.onOpen,
    required this.onInbox,
  });

  final List<StudyTask> tasks;
  final StudyWorkspaceController workspace;
  final VoidCallback onOpen;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StudyColors.of(context);
    final pending = tasks.where((task) => !task.completed).take(4).toList();
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Today', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(onPressed: onOpen, child: const Text('Planner')),
            ],
          ),
          const SizedBox(height: 6),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                tasks.isEmpty
                    ? 'No study blocks scheduled.'
                    : 'Everything planned for today is complete.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < pending.length; i++) ...[
              _TaskLine(task: pending[i]),
              if (i != pending.length - 1) const Divider(height: 18),
            ],
          const Divider(height: 20),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 17, color: palette.research),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${workspace.minutesThisWeek} min focused',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: onInbox,
                icon: const Icon(Icons.inbox_outlined, size: 17),
                label: const Text('Inbox'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskLine extends StatelessWidget {
  const _TaskLine({required this.task});
  final StudyTask task;

  @override
  Widget build(BuildContext context) {
    final palette = StudyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = switch (task.priority) {
      StudyPriority.high => palette.danger,
      StudyPriority.normal => scheme.primary,
      StudyPriority.low => palette.research,
    };
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${task.estimatedMinutes} min • ${_relativeDate(task.dueDate)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onLibrary,
    required this.onPlanner,
    required this.onInbox,
    required this.onAdd,
    required this.inboxCount,
  });

  final VoidCallback onLibrary;
  final VoidCallback onPlanner;
  final VoidCallback onInbox;
  final VoidCallback onAdd;
  final int inboxCount;

  @override
  Widget build(BuildContext context) {
    final palette = StudyColors.of(context);
    final actions = [
      (Icons.folder_outlined, 'Library', 'Browse materials', palette.folder, onLibrary),
      (Icons.calendar_month_outlined, 'Planner', 'Plan study time', palette.exam, onPlanner),
      (Icons.inbox_outlined, 'Inbox', '$inboxCount waiting', palette.project, onInbox),
      (Icons.add_rounded, 'Add', 'Import material', palette.research, onAdd),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in actions)
                SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: _QuickAction(
                    icon: item.$1,
                    title: item.$2,
                    subtitle: item.$3,
                    color: item.$4,
                    onTap: item.$5,
                  ),
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              Expanded(
                child: _QuickAction(
                  icon: actions[i].$1,
                  title: actions[i].$2,
                  subtitle: actions[i].$3,
                  color: actions[i].$4,
                  onTap: actions[i].$5,
                ),
              ),
              if (i != actions.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String detail;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            detail,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    );
  }
}

class _RecentGrid extends StatelessWidget {
  const _RecentGrid({
    required this.entries,
    required this.controller,
    required this.onOpen,
  });
  final List<LibraryEntry> entries;
  final LibraryController controller;
  final ValueChanged<LibraryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: _RecentRow(
                  entry: entry,
                  progress: controller.progressFor(entry.path),
                  onTap: () => onOpen(entry),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry, required this.progress, required this.onTap});
  final LibraryEntry entry;
  final StudyProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = progress?.fraction ?? 0;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              FileIcon(entry: entry),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress != null && progress!.pageCount > 0
                          ? 'Page ${progress!.page} of ${progress!.pageCount}'
                          : fileMeta(entry),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (progress != null && progress!.pageCount > 0) ...[
                      const SizedBox(height: 7),
                      LinearProgressIndicator(value: fraction, minHeight: 3),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpacesStrip extends StatelessWidget {
  const _SpacesStrip({
    required this.controller,
    required this.spaces,
    required this.onOpen,
    required this.onCreate,
  });
  final LibraryController controller;
  final List<LibraryEntry> spaces;
  final ValueChanged<String?> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = StudyColors.of(context);
    final colors = [palette.folder, palette.exam, palette.research, palette.project];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < spaces.length; i++)
              SizedBox(
                width: width,
                child: _SpaceRow(
                  entry: spaces[i],
                  materials: controller.materialCountUnder(spaces[i].path),
                  folders: controller.directFolderCount(spaces[i].path),
                  color: colors[i % colors.length],
                  pinned: controller.isPinned(spaces[i].path),
                  onTap: () => onOpen(spaces[i].path),
                ),
              ),
            SizedBox(width: width, child: _CreateSpace(onTap: onCreate)),
          ],
        );
      },
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.entry,
    required this.materials,
    required this.folders,
    required this.color,
    required this.pinned,
    required this.onTap,
  });
  final LibraryEntry entry;
  final int materials;
  final int folders;
  final Color color;
  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (pinned) Icon(Icons.push_pin_rounded, size: 14, color: color),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$materials materials • $folders folders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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

class _CreateSpace extends StatelessWidget {
  const _CreateSpace({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('Create workspace')),
            ],
          ),
        ),
      ),
    );
  }
}

Color _entryColor(BuildContext context, LibraryEntry entry) {
  final palette = StudyColors.of(context);
  return switch (entry.kind) {
    LibraryKind.folder => palette.folder,
    LibraryKind.pdf => palette.pdf,
    LibraryKind.book => palette.exam,
    LibraryKind.slides => palette.slides,
    LibraryKind.spreadsheet => palette.sheet,
    LibraryKind.document => palette.document,
    LibraryKind.note => palette.note,
    LibraryKind.audio => palette.audio,
    LibraryKind.video => palette.video,
    LibraryKind.image => palette.image,
    LibraryKind.archive => palette.project,
    LibraryKind.other => palette.document,
  };
}

String _longDate(DateTime date) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _relativeDate(DateTime date) {
  final today = StudyWorkspaceController.dateOnly(DateTime.now());
  final value = StudyWorkspaceController.dateOnly(date);
  final delta = value.difference(today).inDays;
  if (delta == 0) return 'Today';
  if (delta == 1) return 'Tomorrow';
  if (delta < 0) return '${delta.abs()}d overdue';
  return 'In ${delta}d';
}
