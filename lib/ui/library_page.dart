import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import 'actions.dart';
import 'library_widgets.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) return ConnectLibraryView(controller: controller);
    final title = controller.currentPath.isEmpty
        ? 'Library'
        : controller.currentPath.split('/').last;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              if (controller.currentPath.isNotEmpty)
                IconButton(
                  onPressed: controller.goUp,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      controller.currentPath.isEmpty
                          ? 'Root folder'
                          : controller.currentPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: controller.gridMode ? 'List view' : 'Grid view',
                onPressed: () => controller.setGridMode(!controller.gridMode),
                icon: Icon(
                  controller.gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.entries.isEmpty
              ? const Center(
                  child: EmptyCard(
                    icon: Icons.folder_open_rounded,
                    title: 'This folder is empty',
                    subtitle: 'Add files, a folder or a quick note.',
                  ),
                )
              : controller.gridMode
                  ? _Grid(controller: controller)
                  : _List(controller: controller),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      itemCount: controller.entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = controller.entries[index];
        return FileRow(
          entry: entry,
          onTap: () => controller.openEntry(entry),
          trailing: IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => showEntryActions(context, controller, entry),
          ),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 0.93,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) {
        final entry = controller.entries[index];
        return _GridEntry(controller: controller, entry: entry);
      },
    );
  }
}

class _GridEntry extends StatelessWidget {
  const _GridEntry({required this.controller, required this.entry});

  final LibraryController controller;
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => controller.openEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FileIcon(entry: entry, large: true),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () => showEntryActions(context, controller, entry),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                fileMeta(entry),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
