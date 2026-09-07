import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import 'actions.dart';
import 'command_center.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class StudyShell extends StatefulWidget {
  const StudyShell({super.key});

  @override
  State<StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<StudyShell> {
  late final LibraryController controller;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    controller = LibraryController()..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _openLibrary([String? path]) {
    if (path != null) controller.openFolder(path);
    setState(() => pageIndex = 1);
  }

  void _openSearch() => setState(() => pageIndex = 2);

  void _openCommandCenter() => showCommandCenter(
    context,
    controller,
    navigate: _selectPage,
    openFolder: (path) => _openLibrary(path),
  );

  void _selectPage(int value) => setState(() => pageIndex = value);

  List<Widget> _pages() => [
    HomePage(
      controller: controller,
      openLibrary: _openLibrary,
      openSearch: _openSearch,
    ),
    LibraryPage(controller: controller),
    SearchPage(controller: controller, openLibrary: _openLibrary),
    SettingsPage(controller: controller),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
          },
          child: Focus(
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 980) {
                  return _buildDesktop(context);
                }
                return _buildCompact(context);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackdrop(),
          SafeArea(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                  child: _DesktopSidebar(
                    selectedIndex: pageIndex,
                    controller: controller,
                    onSelected: _selectPage,
                    onOpenFolder: (path) => _openLibrary(path),
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
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.42,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              _DesktopTopBar(
                                section: _sectionName(pageIndex),
                                subtitle: _sectionSubtitle(pageIndex),
                                connected: controller.connected,
                                busy: controller.busy,
                                onSearch: _openCommandCenter,
                                onRefresh: controller.refresh,
                                onAdd: () => showAddSheet(
                                  context,
                                  controller,
                                  fromHome: pageIndex == 0,
                                ),
                              ),
                              _statusArea(),
                              Expanded(child: _animatedPage()),
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

  Widget _buildCompact(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 18,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: ColoredBox(color: scheme.surface.withValues(alpha: 0.76)),
          ),
        ),
        title: const _Brand(compact: true),
        actions: [
          if (controller.connected)
            IconButton(
              tooltip: 'Search everything',
              onPressed: _openSearch,
              icon: const Icon(Icons.search_rounded),
            ),
          if (controller.connected)
            IconButton(
              tooltip: 'Refresh library',
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.sync_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const _AmbientBackdrop(),
          Column(
            children: [
              _statusArea(),
              Expanded(child: _animatedPage()),
            ],
          ),
        ],
      ),
      floatingActionButton: controller.connected && pageIndex <= 1
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                onPressed: () =>
                    showAddSheet(context, controller, fromHome: pageIndex == 0),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.42),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: pageIndex,
                onDestinationSelected: _selectPage,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder_rounded),
                    label: 'Library',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
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
    );
  }

  Widget _animatedPage() {
    final pages = _pages();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.018, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(pageIndex), child: pages[pageIndex]),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.controller,
    required this.onSelected,
    required this.onOpenFolder,
    required this.onAdd,
  });

  final int selectedIndex;
  final LibraryController controller;
  final ValueChanged<int> onSelected;
  final ValueChanged<String> onOpenFolder;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = controller.connected;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 244,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Brand(),
              const SizedBox(height: 26),
              _DesktopNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _DesktopNavItem(
                icon: Icons.folder_rounded,
                label: 'Library',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _DesktopNavItem(
                icon: Icons.manage_search_rounded,
                label: 'Search',
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              _DesktopNavItem(
                icon: Icons.tune_rounded,
                label: 'Settings',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
              if (controller.pinnedFolders.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
                  child: Text(
                    'PINNED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final folder in controller.pinnedFolders.take(5))
                  _DesktopNavItem(
                    icon: Icons.folder_special_rounded,
                    label: folder.name,
                    selected:
                        selectedIndex == 1 &&
                        controller.currentPath == folder.path,
                    onTap: () => onOpenFolder(folder.path),
                  ),
              ],
              const SizedBox(height: 18),
              if (connected)
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add material'),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          connected
                              ? Icons.offline_bolt_rounded
                              : Icons.folder_off_outlined,
                          size: 17,
                          color: connected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            connected ? 'Offline library' : 'No library',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      connected
                          ? (controller.libraryName ?? 'Study Library')
                          : 'Connect a local folder to begin.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Alt+1/2/3 • Ctrl+K search',
                textAlign: TextAlign.center,
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

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.76)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
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
    required this.section,
    required this.subtitle,
    required this.connected,
    required this.busy,
    required this.onSearch,
    required this.onRefresh,
    required this.onAdd,
  });

  final String section;
  final String subtitle;
  final bool connected;
  final bool busy;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (connected) ...[
            SizedBox(
              width: 250,
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: onSearch,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 19,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Command center',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          'Ctrl K',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: busy ? null : onRefresh,
              icon: const Icon(Icons.sync_rounded),
            ),
            const SizedBox(width: 8),
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
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Study',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'Offline student library',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

String _sectionName(int index) => switch (index) {
  0 => 'Home',
  1 => 'Library',
  2 => 'Search',
  _ => 'Settings',
};

String _sectionSubtitle(int index) => switch (index) {
  0 => 'Everything you need to continue learning.',
  1 => 'Organize material into folders that make sense to you.',
  2 => 'Find anything across every folder and format.',
  _ => 'Storage, portability and app preferences.',
};

class _AmbientBackdrop extends StatefulWidget {
  const _AmbientBackdrop();

  @override
  State<_AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<_AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 0.5;
    } else if (!motion.isAnimating) {
      motion.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, child) => Transform.translate(
            offset: Offset(18 * motion.value, 10 * (1 - motion.value)),
            child: child,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -120,
                child: Container(
                  width: 330,
                  height: 330,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.primary.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: -140,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.tertiary.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                    ),
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

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    super.key,
    required this.text,
    required this.onDismiss,
    this.error = false,
  });

  final String text;
  final bool error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(18, 9, 8, 9),
      child: Row(
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
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
