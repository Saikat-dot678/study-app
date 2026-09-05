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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.initialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final pages = [
          HomePage(controller: controller, openLibrary: _openLibrary),
          LibraryPage(controller: controller),
          SearchPage(controller: controller, openLibrary: _openLibrary),
          SettingsPage(controller: controller),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('Study App'),
              ],
            ),
            actions: [
              if (controller.connected)
                IconButton(
                  tooltip: 'Refresh library',
                  onPressed: controller.busy ? null : controller.refresh,
                  icon: const Icon(Icons.sync_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (controller.error != null)
                _StatusStrip(text: controller.error!, error: true)
              else if (controller.notice != null)
                _StatusStrip(text: controller.notice!),
              if (controller.busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: pages[pageIndex]),
            ],
          ),
          floatingActionButton: controller.connected && pageIndex <= 1
              ? FloatingActionButton.extended(
                  onPressed: () => showAddSheet(
                    context,
                    controller,
                    fromHome: pageIndex == 0,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
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
              NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
