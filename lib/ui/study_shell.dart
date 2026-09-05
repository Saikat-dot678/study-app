import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import 'actions.dart';
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.initialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final pages = <Widget>[
          HomePage(
            controller: controller,
            openLibrary: _openLibrary,
            openSearch: _openSearch,
          ),
          LibraryPage(controller: controller),
          SearchPage(controller: controller, openLibrary: _openLibrary),
          SettingsPage(controller: controller),
        ];
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
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
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
                  child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Study', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      _sectionName(pageIndex),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
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
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.025, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(pageIndex),
                        child: pages[pageIndex],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: controller.connected && pageIndex <= 1
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
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
                    onPressed: () => showAddSheet(
                      context,
                      controller,
                      fromHome: pageIndex == 0,
                    ),
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
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.42)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 10)),
                    ],
                  ),
                  child: NavigationBar(
                    selectedIndex: pageIndex,
                    onDestinationSelected: (index) => setState(() => pageIndex = index),
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
      },
    );
  }
}

String _sectionName(int index) => switch (index) {
      0 => 'Your learning space',
      1 => 'Library',
      2 => 'Find anything',
      _ => 'Preferences',
    };

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
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
                  colors: [scheme.primary.withValues(alpha: 0.10), Colors.transparent],
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
                  colors: [scheme.tertiary.withValues(alpha: 0.07), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
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
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color))),
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
