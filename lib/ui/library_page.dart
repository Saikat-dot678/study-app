import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import 'actions.dart';
import 'library_widgets.dart';

enum _LibrarySort { name, newest, type }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  _LibrarySort sort = _LibrarySort.name;
  final Set<String> selected = {};

  LibraryController get controller => widget.controller;
  bool get selecting => selected.isNotEmpty;

  static const _legacyRoots = {'Notes', 'Books', 'Slides', 'Recordings', 'Videos'};

  List<LibraryEntry> get visibleEntries {
    final values = controller.entries.where((entry) {
      if (controller.currentPath.isNotEmpty || !entry.isDirectory || !_legacyRoots.contains(entry.name)) return true;
      return controller.materialCountUnder(entry.path) > 0 || controller.directFolderCount(entry.path) > 0;
    }).toList();

    int compareName(LibraryEntry a, LibraryEntry b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    values.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return switch (sort) {
        _LibrarySort.name => compareName(a, b),
        _LibrarySort.newest =>
          (b.lastModified?.millisecondsSinceEpoch ?? 0).compareTo(a.lastModified?.millisecondsSinceEpoch ?? 0),
        _LibrarySort.type => a.kind.index == b.kind.index ? compareName(a, b) : a.kind.index.compareTo(b.kind.index),
      };
    });
    return values;
  }

  void _toggle(LibraryEntry entry) {
    setState(() {
      if (!selected.add(entry.path)) selected.remove(entry.path);
    });
  }

  void _clearSelection() => setState(selected.clear);

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) return ConnectLibraryView(controller: controller);
    final entries = visibleEntries;
    final folders = entries.where((entry) => entry.isDirectory).toList();
    final materials = entries.where((entry) => !entry.isDirectory).toList();
    final title = controller.currentPath.isEmpty ? 'Library' : controller.currentPath.split('/').last;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: selecting
              ? _SelectionHeader(
                  key: const ValueKey('selected'),
                  count: selected.length,
                  onClose: _clearSelection,
                  onSelectAll: () => setState(() => selected.addAll(entries.map((entry) => entry.path))),
                )
              : _LibraryHeader(
                  key: const ValueKey('normal'),
                  title: title,
                  controller: controller,
                  sort: sort,
                  onSort: (value) => setState(() => sort = value),
                  onImport: () => showSmartImportSheet(context, controller, basePath: controller.currentPath),
                  onStructure: () => showCreateSpaceSheet(context, controller, parent: controller.currentPath),
                ),
        ),
        if (!selecting) _Breadcrumbs(controller: controller),
        if (!selecting && controller.currentPath == 'Inbox')
          _InboxGuide(
            count: materials.length,
            onImport: () => showSmartImportSheet(context, controller, basePath: 'Inbox'),
          ),
        Expanded(
          child: entries.isEmpty
              ? _EmptyFolder(
                  onImport: () => showSmartImportSheet(context, controller, basePath: controller.currentPath),
                  onStructure: () => showCreateSpaceSheet(context, controller, parent: controller.currentPath),
                )
              : _FolderCanvas(
                  controller: controller,
                  folders: folders,
                  materials: materials,
                  selected: selected,
                  onTap: _handleTap,
                  onLongPress: _toggle,
                ),
        ),
        if (selecting)
          _BulkBar(
            count: selected.length,
            onMove: _moveSelected,
            onDelete: _deleteSelected,
          ),
      ],
    );
  }

  void _handleTap(LibraryEntry entry) {
    if (selecting) {
      _toggle(entry);
      return;
    }
    if (entry.isDirectory) {
      controller.openFolder(entry.path);
    } else {
      openStudyViewer(context, controller, entry);
    }
  }

  List<LibraryEntry> get _selectedEntries =>
      controller.entries.where((entry) => selected.contains(entry.path)).toList();

  Future<void> _moveSelected() async {
    final moved = await showBulkMoveSheet(context, controller, _selectedEntries);
    if (moved && mounted) _clearSelection();
  }

  Future<void> _deleteSelected() async {
    final deleted = await confirmBulkDelete(context, controller, _selectedEntries);
    if (deleted && mounted) _clearSelection();
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    super.key,
    required this.title,
    required this.controller,
    required this.sort,
    required this.onSort,
    required this.onImport,
    required this.onStructure,
  });

  final String title;
  final LibraryController controller;
  final _LibrarySort sort;
  final ValueChanged<_LibrarySort> onSort;
  final VoidCallback onImport;
  final VoidCallback onStructure;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 22 : 12, 10, wide ? 22 : 10, 5),
      child: Row(
        children: [
          if (controller.currentPath.isNotEmpty)
            IconButton.filledTonal(onPressed: controller.goUp, icon: const Icon(Icons.arrow_back_rounded)),
          if (controller.currentPath.isNotEmpty) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  controller.currentPath.isEmpty
                      ? 'Your spaces, folders and materials'
                      : '${controller.currentFolders.length} folders • ${controller.currentMaterials.length} materials',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (wide) ...[
            OutlinedButton.icon(onPressed: onStructure, icon: const Icon(Icons.account_tree_rounded), label: const Text('Structure')),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.add_rounded), label: const Text('Import')),
            const SizedBox(width: 8),
          ] else ...[
            IconButton(tooltip: 'Build structure', onPressed: onStructure, icon: const Icon(Icons.account_tree_rounded)),
            IconButton(tooltip: 'Smart import', onPressed: onImport, icon: const Icon(Icons.add_circle_outline_rounded)),
          ],
          PopupMenuButton<_LibrarySort>(
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: onSort,
            icon: const Icon(Icons.sort_rounded),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _LibrarySort.name, child: Text('Name')),
              PopupMenuItem(value: _LibrarySort.newest, child: Text('Newest')),
              PopupMenuItem(value: _LibrarySort.type, child: Text('File type')),
            ],
          ),
          IconButton(
            tooltip: controller.gridMode ? 'List view' : 'Grid view',
            onPressed: () => controller.setGridMode(!controller.gridMode),
            icon: Icon(controller.gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
        ],
      ),
    );
  }
}

class _FolderCanvas extends StatelessWidget {
  const _FolderCanvas({
    required this.controller,
    required this.folders,
    required this.materials,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final LibraryController controller;
  final List<LibraryEntry> folders;
  final List<LibraryEntry> materials;
  final Set<String> selected;
  final ValueChanged<LibraryEntry> onTap;
  final ValueChanged<LibraryEntry> onLongPress;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 12, wide ? 22 : 14, 8),
            sliver: const SliverToBoxAdapter(child: _SectionLabel(title: 'Folders', icon: Icons.folder_copy_rounded)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 0, wide ? 22 : 14, 18),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 285,
                mainAxisExtent: 112,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = folders[index];
                  return _FolderCard(
                    entry: entry,
                    folderCount: controller.directFolderCount(entry.path),
                    materialCount: controller.directMaterialCount(entry.path),
                    totalMaterials: controller.materialCountUnder(entry.path),
                    selected: selected.contains(entry.path),
                    onTap: () => onTap(entry),
                    onLongPress: () => onLongPress(entry),
                    onMenu: () => showEntryActions(context, controller, entry),
                  );
                },
                childCount: folders.length,
              ),
            ),
          ),
        ],
        if (materials.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 14, folders.isEmpty ? 12 : 2, wide ? 22 : 14, 8),
            sliver: SliverToBoxAdapter(
              child: _SectionLabel(
                title: folders.isEmpty ? 'Materials' : 'Materials in this folder',
                icon: Icons.auto_stories_rounded,
              ),
            ),
          ),
          if (controller.gridMode)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 0, wide ? 22 : 14, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  childAspectRatio: 0.95,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = materials[index];
                    return _MaterialCard(
                      entry: entry,
                      selected: selected.contains(entry.path),
                      selectionActive: selected.isNotEmpty,
                      onTap: () => onTap(entry),
                      onLongPress: () => onLongPress(entry),
                      onMenu: () => showEntryActions(context, controller, entry),
                    );
                  },
                  childCount: materials.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 0, wide ? 22 : 14, 120),
              sliver: SliverList.builder(
                itemCount: materials.length,
                itemBuilder: (context, index) {
                  final entry = materials[index];
                  final isSelected = selected.contains(entry.path);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FileRow(
                      entry: entry,
                      selected: isSelected,
                      onTap: () => onTap(entry),
                      onLongPress: () => onLongPress(entry),
                      trailing: selected.isNotEmpty
                          ? Checkbox(value: isSelected, onChanged: (_) => onTap(entry))
                          : IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => showEntryActions(context, controller, entry)),
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.entry,
    required this.folderCount,
    required this.materialCount,
    required this.totalMaterials,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final LibraryEntry entry;
  final int folderCount;
  final int materialCount;
  final int totalMaterials;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.16) : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.38)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: 0.28), scheme.secondary.withValues(alpha: 0.13)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.folder_rounded, size: 28, color: scheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w850)),
                    const SizedBox(height: 5),
                    Text(
                      folderCount == 0 && materialCount == 0
                          ? 'Empty • ready to organize'
                          : '$folderCount folders • $materialCount here • $totalMaterials total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onMenu, icon: const Icon(Icons.more_horiz_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.entry,
    required this.selected,
    required this.selectionActive,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final LibraryEntry entry;
  final bool selected;
  final bool selectionActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.6) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FileIcon(entry: entry, large: true, heroTag: 'entry:${entry.path}'),
                  const Spacer(),
                  if (selectionActive)
                    Checkbox(value: selected, onChanged: (_) => onTap())
                  else
                    IconButton(onPressed: onMenu, icon: const Icon(Icons.more_horiz_rounded)),
                ],
              ),
              const Spacer(),
              Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(fileMeta(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w850)),
      ],
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({super.key, required this.count, required this.onClose, required this.onSelectAll});
  final int count;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        children: [
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
          const SizedBox(width: 6),
          Expanded(child: Text('$count selected', style: Theme.of(context).textTheme.titleLarge)),
          TextButton(onPressed: onSelectAll, child: const Text('Select all')),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.controller});
  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final pieces = controller.currentPath.split('/').where((part) => part.isNotEmpty).toList();
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        children: [
          ActionChip(
            avatar: const Icon(Icons.home_rounded, size: 16),
            label: const Text('Root'),
            onPressed: () => controller.openFolder(''),
          ),
          for (var index = 0; index < pieces.length; index++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Icon(Icons.chevron_right_rounded, size: 17),
            ),
            ActionChip(
              label: Text(pieces[index]),
              onPressed: () => controller.openFolder(pieces.take(index + 1).join('/')),
            ),
          ],
        ],
      ),
    );
  }
}

class _InboxGuide extends StatelessWidget {
  const _InboxGuide({required this.count, required this.onImport});
  final int count;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 9),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.tertiary.withValues(alpha: 0.13), scheme.primary.withValues(alpha: 0.08)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.tertiary.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.inbox_rounded, color: scheme.tertiary),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Landing zone', style: TextStyle(fontWeight: FontWeight.w850)),
                  const SizedBox(height: 2),
                  Text(count == 0 ? 'Share material here from other apps.' : 'Select items and move them into any nested study space.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.filledTonal(onPressed: onImport, icon: const Icon(Icons.add_rounded)),
          ],
        ),
      ),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.onImport, required this.onStructure});
  final VoidCallback onImport;
  final VoidCallback onStructure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_rounded, size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('Shape this folder your way', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 7),
              const Text('Add material directly here, create another nested structure, or use a material type such as Notes, PYQs or Slides.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.add_rounded), label: const Text('Import material')),
                  OutlinedButton.icon(onPressed: onStructure, icon: const Icon(Icons.account_tree_rounded), label: const Text('Add structure')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({required this.count, required this.onMove, required this.onDelete});
  final int count;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 96),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(child: Text('$count selected', style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w800))),
            TextButton.icon(
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Move'),
              style: TextButton.styleFrom(foregroundColor: scheme.onInverseSurface),
            ),
            IconButton(tooltip: 'Delete selected', onPressed: onDelete, color: scheme.errorContainer, icon: const Icon(Icons.delete_outline_rounded)),
          ],
        ),
      ),
    );
  }
}
