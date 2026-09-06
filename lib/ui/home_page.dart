import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import 'actions.dart';
import 'library_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.openLibrary,
    required this.openSearch,
  });
  final LibraryController controller;
  final ValueChanged<String?> openLibrary;
  final VoidCallback openSearch;

  void _open(BuildContext context, LibraryEntry entry) {
    if (entry.isDirectory) {
      openLibrary(entry.path);
    } else {
      openStudyViewer(context, controller, entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) {
      return ConnectLibraryView(controller: controller);
    }
    final scheme = Theme.of(context).colorScheme;
    final recent = controller.recentFiles;
    final stars = controller.starredEntries;
    final spaces = controller.rootSpaces;
    final inbox = controller.directMaterialCount('Inbox');
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth > 700 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your study desk',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick up where you left off. Everything stays on your device.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => showSmartImportSheet(
                                    context,
                                    controller,
                                    basePath: 'Inbox',
                                  ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Capture to Inbox'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                showCreateSpaceSheet(context, controller),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('New workspace'),
                          ),
                          TextButton.icon(
                            onPressed: () => showNewNoteSheet(
                              context,
                              controller,
                              destination: 'Inbox',
                            ),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Quick note'),
                          ),
                          TextButton.icon(
                            onPressed: openSearch,
                            icon: const Icon(Icons.search),
                            label: const Text('Find material'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Icon(
                            Icons.inbox_outlined,
                            color: scheme.secondary,
                          ),
                          title: Text(
                            inbox == 0
                                ? 'Inbox is clear'
                                : '$inbox ${inbox == 1 ? 'item' : 'items'} ready to file',
                          ),
                          subtitle: Text(
                            inbox == 0 ? 'New shared files land here.' : 'Select a batch, choose a subject, and file it together.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openLibrary('Inbox'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle(title: 'Continue studying'),
                      if (recent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Open a material to start your reading history.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList.builder(
                  itemCount: recent.length,
                  itemBuilder: (context, index) {
                    final entry = recent[index];
                    return FileRow(
                      entry: entry,
                      showPath: true,
                      onTap: () => _open(context, entry),
                      trailing: IconButton(
                        tooltip: 'Material actions',
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () =>
                            showEntryActions(context, controller, entry),
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 24, padding, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Starred'),
                      if (stars.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Star a folder, syllabus or formula sheet from its menu for quick access.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList.builder(
                  itemCount: stars.length,
                  itemBuilder: (context, index) {
                    final entry = stars[index];
                    return FileRow(
                      entry: entry,
                      showPath: true,
                      heroEnabled: false,
                      onTap: () => _open(context, entry),
                      trailing: IconButton(
                        tooltip: 'Remove star',
                        icon: Icon(Icons.star_rounded, color: scheme.primary),
                        onPressed: () => controller.toggleStar(entry),
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 24, padding, 12),
                sliver: SliverToBoxAdapter(
                  child: SectionTitle(
                    title: 'Your spaces',
                    action: 'Browse all',
                    onTap: () => openLibrary(''),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 100),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        ((constraints.maxWidth - padding * 2) /
                                (260 *
                                    MediaQuery.textScalerOf(context).scale(1)))
                            .floor()
                            .clamp(1, 5),
                    mainAxisExtent:
                        120 * MediaQuery.textScalerOf(context).scale(1),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: spaces.length,
                  itemBuilder: (context, index) {
                    final entry = spaces[index];
                    return Material(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => openLibrary(entry.path),
                        onLongPress: () =>
                            showEntryActions(context, controller, entry),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    color: scheme.primary,
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    height: 40,
                                    child: IconButton(
                                      tooltip: controller.isStarred(entry)
                                          ? 'Unpin folder'
                                          : 'Pin folder',
                                      onPressed: () =>
                                          controller.toggleStar(entry),
                                      icon: Icon(
                                        controller.isStarred(entry)
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${controller.materialCountUnder(entry.path)} materials',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
