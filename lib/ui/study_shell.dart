import 'dart:async';
import 'dart:ui';

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
  const StudyShell({super.key});

  @override
  State<StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<StudyShell> {
  late final LibraryController controller;
  final workspace = StudyWorkspaceController.instance;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    controller = LibraryController()..initialize();
    unawaited(workspace.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _selectPage(int value) {
    if (value < 0 || value > 4) return;
    setState(() => pageIndex = value);
  }

  void _openLibrary([String? path]) {
    if (path != null) unawaited(controller.openFolder(path));
    setState(() => pageIndex = 1);
  }

  void _openGoals() => setState(() => pageIndex = 2);
  void _openSearch() => setState(() => pageIndex = 3);

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
      controller: controller,
      workspace: workspace,
      openLibrary: _openLibrary,
      openSearch: _openSearch,
      openGoals: _openGoals,
    ),
    LibraryPage(controller: controller),
    GoalsPage(workspace: workspace),
    SearchPage(controller: controller, openLibrary: _openLibrary),
    SettingsPage(controller: controller),
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
              builder: (context, constraints) => constraints.maxWidth >= 1020
                  ? _desktop(context)
                  : _compact(context),
            ),
          ),
        );
      },
    );
  }

  Widget _desktop(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const NebulaBackdrop(),
          SafeArea(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 15, 0, 15),
                  child: _Sidebar(
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
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(31),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.74),
                            borderRadius: BorderRadius.circular(31),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.38),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x28000000),
                                blurRadius: 50,
                                offset: Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _DesktopTopBar(
                                title: _title(pageIndex),
                                subtitle: _subtitle(pageIndex),
                                connected: controller.connected,
                                busy: controller.busy,
                                onSearch: _openCommandCenter,
                                onRefresh: controller.refresh,
                                onAdd: controller.connected
                                    ? () => showAddSheet(
                                        context,
                                        controller,
                                        fromHome: pageIndex == 0,
                                      )
                                    : null,
                              ),
                              _statusArea(),
                              Expanded(child: _page()),
                            ],
                          ),
                        ),
                      ),
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

  Widget _compact(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 16,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: ColoredBox(color: scheme.surface.withValues(alpha: 0.70)),
          ),
        ),
        title: const _Brand(compact: true),
        actions: [
          if (controller.connected)
            IconButton(
              tooltip: 'Search',
              onPressed: _openCommandCenter,
              icon: const Icon(Icons.search_rounded),
            ),
          if (controller.connected)
            IconButton(
              tooltip: 'Add material',
              onPressed: () => showAddSheet(
                context,
                controller,
                fromHome: pageIndex == 0,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 7),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const NebulaBackdrop(),
          Column(
            children: [
              _statusArea(),
              Expanded(child: _page()),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 9),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.42),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 26,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: NavigationBar(
                height: 68,
                selectedIndex: pageIndex,
                onDestinationSelected: _selectPage,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_rounded),
                    selectedIcon: Icon(Icons.auto_awesome_mosaic_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder_rounded),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.flag_outlined),
                    selectedIcon: Icon(Icons.flag_rounded),
                    label: 'Goals',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.manage_search_rounded),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusArea() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: controller.error != null
                ? _StatusStrip(
                    key: const ValueKey('error'),
                    text: controller.error!,
                    error: true,
                    onDismiss: controller.clearStatus,
                  )
                : controller.notice != null
                ? _StatusStrip(
                    key: const ValueKey('notice'),
                    text: controller.notice!,
                    onDismiss: controller.clearStatus,
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          if (controller.busy) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _page() {
    final pages = _pages();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 330),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (reduceMotion) return child;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.018, 0.012),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(pageIndex), child: pages[pageIndex]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
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
    final nextTask = workspace.upcomingTasks.firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(31),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          width: 252,
          padding: const EdgeInsets.fromLTRB(15, 19, 15, 15),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: _Brand(),
              ),
              const SizedBox(height: 25),
              _NavItem(
                icon: Icons.auto_awesome_mosaic_rounded,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                icon: Icons.folder_rounded,
                label: 'Library',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _NavItem(
                icon: Icons.flag_rounded,
                label: 'Goals & Calendar',
                selected: selectedIndex == 2,
                badge: workspace.upcomingTasks.isEmpty
                    ? null
                    : '${workspace.upcomingTasks.length}',
                onTap: () => onSelected(2),
              ),
              _NavItem(
                icon: Icons.manage_search_rounded,
                label: 'Search',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
              _NavItem(
                icon: Icons.tune_rounded,
                label: 'Settings',
                selected: selectedIndex == 4,
                onTap: () => onSelected(4),
              ),
              if (controller.pinnedFolders.isNotEmpty) ...[
                const SizedBox(height: 13),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 8, 7),
                  child: Text(
                    'PINNED SPACES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                for (final folder in controller.pinnedFolders.take(4))
                  _NavItem(
                    icon: Icons.folder_special_rounded,
                    label: folder.name,
                    selected:
                        selectedIndex == 1 && controller.currentPath == folder.path,
                    onTap: () => onOpenFolder(folder.path),
                  ),
              ],
              const SizedBox(height: 13),
              if (controller.connected)
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add material'),
                ),
              const Spacer(),
              if (nextTask != null)
                GlassPanel(
                  radius: 18,
                  blur: 10,
                  padding: const EdgeInsets.all(13),
                  tint: scheme.primary.withValues(alpha: 0.07),
                  onTap: () => onSelected(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: scheme.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'NEXT UP',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextTask.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${nextTask.estimatedMinutes} min • ${_shortDate(nextTask.dueDate)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              if (nextTask != null) const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  'Alt+1–5 • Ctrl+K',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                      color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.busy,
    required this.onSearch,
    required this.onRefresh,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool busy;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 17, 19, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 240,
            child: Material(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onSearch,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 19),
                      SizedBox(width: 8),
                      Expanded(child: Text('Search or command')),
                      Text('⌘K', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (connected)
            IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: busy ? null : onRefresh,
              icon: const Icon(Icons.sync_rounded),
            ),
          if (connected) ...[
            const SizedBox(width: 7),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 39,
          height: compact ? 34 : 39,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.secondary, scheme.tertiary],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.24),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STUDY',
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            if (!compact)
              Text(
                'personal learning OS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
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
      margin: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      padding: const EdgeInsets.fromLTRB(12, 7, 5, 7),
      decoration: BoxDecoration(
        color: (error ? scheme.errorContainer : scheme.primaryContainer)
            .withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

String _title(int index) => switch (index) {
  0 => 'Study OS',
  1 => 'Library',
  2 => 'Goals & Calendar',
  3 => 'Search',
  _ => 'Settings',
};

String _subtitle(int index) => switch (index) {
  0 => 'Your learning momentum, materials and next move.',
  1 => 'Folders are the source of truth. Organize without limits.',
  2 => 'Plan outcomes, schedule tasks and protect focus time.',
  3 => 'Find material across every space in milliseconds.',
  _ => 'Local library, privacy and app preferences.',
};

String _shortDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${value.day} ${months[value.month - 1]}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
