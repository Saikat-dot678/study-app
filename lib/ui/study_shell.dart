import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../workspace/study_workspace_controller.dart';
import 'actions.dart';
import 'command_center.dart';
import 'goals_page.dart';
import 'library_page.dart';
import 'premium_components.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'study_dashboard.dart';

class StudyShell extends StatefulWidget {
  const StudyShell({
    super.key,
    this.libraryController,
    this.workspaceController,
  });

  /// Optional dependencies make the complete adaptive shell testable without
  /// replacing the real storage architecture used by production.
  final LibraryController? libraryController;
  final StudyWorkspaceController? workspaceController;

  @override
  State<StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<StudyShell> {
  late final LibraryController controller;
  late final StudyWorkspaceController workspace;
  late final bool _ownsController;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.libraryController == null;
    controller = widget.libraryController ?? LibraryController();
    workspace = widget.workspaceController ?? StudyWorkspaceController.instance;
    if (!controller.initialized) {
      unawaited(controller.initialize());
    }
    unawaited(workspace.initialize());
  }

  @override
  void dispose() {
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  void _selectPage(int value) {
    if (value < 0 || value >= _destinations.length || value == pageIndex) {
      return;
    }
    setState(() => pageIndex = value);
  }

  void _openLibrary([String? path]) {
    if (path != null) unawaited(controller.openFolder(path));
    _selectPage(1);
  }

  void _openCommandCenter() => showCommandCenter(
    context,
    controller,
    navigate: (value) {
      final mapped = switch (value) {
        0 => 0,
        1 => 1,
        2 => 3,
        3 => 4,
        _ => value,
      };
      _selectPage(mapped);
    },
    openFolder: (path) => _openLibrary(path),
  );

  List<Widget> _pages() => [
    StudyDashboard(
      key: const PageStorageKey('home-page'),
      controller: controller,
      workspace: workspace,
      openLibrary: _openLibrary,
      openGoals: () => _selectPage(2),
    ),
    LibraryPage(
      key: const PageStorageKey('library-page'),
      controller: controller,
    ),
    GoalsPage(key: const PageStorageKey('goals-page'), workspace: workspace),
    SearchPage(
      key: const PageStorageKey('search-page'),
      controller: controller,
      openLibrary: _openLibrary,
    ),
    SettingsPage(
      key: const PageStorageKey('settings-page'),
      controller: controller,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, workspace]),
      builder: (context, _) {
        if (!controller.initialized) {
          return const Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                NebulaBackdrop(),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        }
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _openCommandCenter,
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _openCommandCenter,
            const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
                _selectPage(0),
            const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
                _selectPage(1),
            const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
                _selectPage(2),
            const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
                _selectPage(3),
            const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () =>
                _selectPage(4),
          },
          child: Focus(
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1120) {
                  return _desktop(expanded: true);
                }
                if (constraints.maxWidth >= 720) {
                  return _desktop(expanded: false);
                }
                return _mobile();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _desktop({required bool expanded}) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const NebulaBackdrop(),
          SafeArea(
            child: Row(
              children: [
                if (expanded)
                  _ExpandedSidebar(
                    selectedIndex: pageIndex,
                    controller: controller,
                    workspace: workspace,
                    onSelected: _selectPage,
                    onOpenFolder: _openLibrary,
                    onAdd: controller.connected
                        ? () => showAddSheet(
                            context,
                            controller,
                            fromHome: pageIndex == 0,
                          )
                        : null,
                  )
                else
                  _CompactRail(
                    selectedIndex: pageIndex,
                    onSelected: _selectPage,
                    onAdd: controller.connected
                        ? () => showAddSheet(
                            context,
                            controller,
                            fromHome: pageIndex == 0,
                          )
                        : null,
                  ),
                VerticalDivider(width: 1, color: scheme.outlineVariant),
                Expanded(
                  child: ColoredBox(
                    color: scheme.surface,
                    child: Column(
                      children: [
                        _DesktopTopBar(
                          controller: controller,
                          compact: !expanded,
                          onSearch: _openCommandCenter,
                          onAdd: controller.connected
                              ? () => showAddSheet(
                                  context,
                                  controller,
                                  fromHome: pageIndex == 0,
                                )
                              : null,
                        ),
                        _statusArea(),
                        Expanded(child: _pageStack()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile() {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const _StudyMark(size: 31),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _destinations[pageIndex].label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        actions: [
          if (controller.connected)
            IconButton(
              tooltip: 'Search and commands',
              onPressed: _openCommandCenter,
              icon: const Icon(Icons.search_rounded),
            ),
          if (controller.connected)
            IconButton(
              tooltip: 'Add material',
              onPressed: () =>
                  showAddSheet(context, controller, fromHome: pageIndex == 0),
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 5),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: scheme.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          _statusArea(),
          Expanded(child: _pageStack()),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: pageIndex,
          onDestinationSelected: _selectPage,
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.shortLabel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageStack() {
    return IndexedStack(index: pageIndex, children: _pages());
  }

  Widget _statusArea() {
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: controller.error != null
                ? _StatusStrip(
                    key: const ValueKey('error'),
                    text: controller.error ?? 'Something went wrong.',
                    error: true,
                    onDismiss: controller.clearStatus,
                  )
                : controller.notice != null
                ? _StatusStrip(
                    key: const ValueKey('notice'),
                    text: controller.notice ?? '',
                    onDismiss: controller.clearStatus,
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          if (controller.busy) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.selectedIndex,
    required this.controller,
    required this.workspace,
    required this.onSelected,
    required this.onOpenFolder,
    required this.onAdd,
  });

  final int selectedIndex;
  final LibraryController controller;
  final StudyWorkspaceController workspace;
  final ValueChanged<int> onSelected;
  final ValueChanged<String> onOpenFolder;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 244,
      child: Material(
        color: scheme.surfaceContainerLowest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 18, 17),
              child: _Brand(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 12),
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    _NavItem(
                      icon: selectedIndex == i
                          ? _destinations[i].selectedIcon
                          : _destinations[i].icon,
                      label: _destinations[i].label,
                      selected: selectedIndex == i,
                      badge: i == 2 && workspace.upcomingTasks.isNotEmpty
                          ? '${workspace.upcomingTasks.length}'
                          : null,
                      onTap: () => onSelected(i),
                    ),
                  if (controller.pinnedFolders.isNotEmpty) ...[
                    const SizedBox(height: 19),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
                      child: Text(
                        'PINNED SPACES',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    for (final folder in controller.pinnedFolders.take(6))
                      _NavItem(
                        icon: Icons.folder_outlined,
                        label: folder.name,
                        selected:
                            selectedIndex == 1 &&
                            controller.currentPath == folder.path,
                        onTap: () => onOpenFolder(folder.path),
                      ),
                  ],
                ],
              ),
            ),
            if (controller.connected)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add material'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 5, 18, 16),
              child: Row(
                children: [
                  Icon(
                    controller.connected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: controller.connected
                        ? scheme.secondary
                        : scheme.onSurfaceVariant,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      controller.connected
                          ? '${controller.libraryName ?? 'Library'} • local'
                          : 'No library connected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRail extends StatelessWidget {
  const _CompactRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      leading: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 13),
            child: _StudyMark(size: 36),
          ),
          if (onAdd != null)
            IconButton.filled(
              tooltip: 'Add material',
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.shortLabel),
          ),
      ],
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.controller,
    required this.compact,
    required this.onSearch,
    required this.onAdd,
  });

  final LibraryController controller;
  final bool compact;
  final VoidCallback onSearch;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 18, 13),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    controller.connected
                        ? Icons.lock_outline_rounded
                        : Icons.folder_off_outlined,
                    size: 18,
                    color: controller.connected
                        ? scheme.secondary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.connected
                          ? '${controller.libraryName ?? 'Study library'}${controller.currentPath.isEmpty ? '' : '  /  ${controller.currentPath}'}'
                          : 'Offline-first • choose a folder to begin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (!compact)
              SizedBox(
                width: 230,
                child: OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Row(
                    children: [
                      Expanded(child: Text('Search or command')),
                      Text('Ctrl K', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'Search and commands (Ctrl+K)',
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            if (controller.connected) ...[
              const SizedBox(width: 7),
              IconButton(
                tooltip: 'Refresh library',
                onPressed: controller.busy ? null : controller.refresh,
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
            if (!compact && controller.connected) ...[
              const SizedBox(width: 7),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge ?? '',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const _StudyMark(size: 37),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STUDY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                ),
              ),
              Text(
                'offline learning space',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyMark extends StatelessWidget {
  const _StudyMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.bookmark_rounded,
        size: size * 0.52,
        color: scheme.onPrimary,
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    super.key,
    required this.text,
    required this.onDismiss,
    this.error = false,
  });

  final String text;
  final VoidCallback onDismiss;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String shortLabel;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination(
    label: 'Home',
    shortLabel: 'Home',
    subtitle: 'Your next move, recent work, and study spaces.',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    label: 'Library',
    shortLabel: 'Library',
    subtitle: 'Your real folders and materials, without limits.',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
  ),
  _Destination(
    label: 'Goals & Calendar',
    shortLabel: 'Goals',
    subtitle: 'Plan outcomes, schedule work, and protect focus.',
    icon: Icons.flag_outlined,
    selectedIcon: Icons.flag_rounded,
  ),
  _Destination(
    label: 'Search',
    shortLabel: 'Search',
    subtitle: 'Find anything across every folder in your library.',
    icon: Icons.search_rounded,
    selectedIcon: Icons.manage_search_rounded,
  ),
  _Destination(
    label: 'Settings',
    shortLabel: 'Settings',
    subtitle: 'Local storage, portability, privacy, and preferences.',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];
