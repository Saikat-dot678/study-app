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

  List<LibraryEntry> get visibleEntries {
    final values = [...controller.entries];
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
    final title = controller.currentPath.isEmpty ? 'Library' : controller.currentPath.split('/').last;
    final entries = visibleEntries;

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
                ),
        ),
        if (!selecting) _Breadcrumbs(controller: controller),
        if (!selecting && controller.currentPath == 'Inbox')
          _InboxGuide(
            count: entries.length,
            onImport: () => controller.importFiles(destination: 'Inbox'),
          ),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: EmptyCard(
                    icon: Icons.folder_open_rounded,
                    title: 'Nothing here yet',
                    subtitle: 'Import material, create a folder or add a quick note.',
                  ),
                )
              : controller.gridMode
                  ? _Grid(
                      controller: controller,
                      entries: entries,
                      selected: selected,
                      onTap: _handleTap,
                      onLongPress: _toggle,
                    )
                  : _List(
                      controller: controller,
                      entries: entries,
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
    final values = _selectedEntries;
    final moved = await showBulkMoveSheet(context, controller, values);
    if (moved && mounted) _clearSelection();
  }

  Future<void> _deleteSelected() async {
    final values = _selectedEntries;
    final deleted = await confirmBulkDelete(context, controller, values);
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
  });

  final String title;
  final LibraryController controller;
  final _LibrarySort sort;
  final ValueChanged<_LibrarySort> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 5),
      child: Row(
        children: [
          if (controller.currentPath.isNotEmpty)
            IconButton.filledTonal(
              onPressed: controller.goUp,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          if (controller.currentPath.isNotEmpty) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4),
                ),
                Text(
                  '${controller.entries.length} item${controller.entries.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
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
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                controller.gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                key: ValueKey(controller.gridMode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    super.key,
    required this.count,
    required this.onClose,
    required this.onSelectAll,
  });

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
          Expanded(
            child: Text('$count selected', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
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
      height: 44,
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
              padding: EdgeInsets.symmetric(horizontal: 4),
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primaryContainer.withValues(alpha: 0.68), scheme.tertiaryContainer.withValues(alpha: 0.45)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.64), borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.inbox_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your landing zone', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    count == 0 ? 'Share anything here from WhatsApp, Files or Gallery.' : 'Long-press files to select several, then move them together.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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

class _List extends StatelessWidget {
  const _List({
    required this.controller,
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final LibraryController controller;
  final List<LibraryEntry> entries;
  final Set<String> selected;
  final ValueChanged<LibraryEntry> onTap;
  final ValueChanged<LibraryEntry> onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 116),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = selected.contains(entry.path);
        return FileRow(
          entry: entry,
          selected: isSelected,
          onTap: () => onTap(entry),
          onLongPress: () => onLongPress(entry),
          trailing: selected.isNotEmpty
              ? Checkbox(value: isSelected, onChanged: (_) => onTap(entry))
              : IconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => showEntryActions(context, controller, entry),
                ),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.controller,
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final LibraryController controller;
  final List<LibraryEntry> entries;
  final Set<String> selected;
  final ValueChanged<LibraryEntry> onTap;
  final ValueChanged<LibraryEntry> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 116),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 188,
        childAspectRatio: 0.92,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = selected.contains(entry.path);
        return Card(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.62) : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onTap(entry),
            onLongPress: () => onLongPress(entry),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FileIcon(
                        entry: entry,
                        large: true,
                        heroTag: entry.isDirectory ? null : 'entry:${entry.path}',
                      ),
                      const Spacer(),
                      if (selected.isNotEmpty)
                        Checkbox(value: isSelected, onChanged: (_) => onTap(entry))
                      else
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded),
                          onPressed: () => showEntryActions(context, controller, entry),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(fileMeta(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
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
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('$count selected', style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Move'),
              style: TextButton.styleFrom(foregroundColor: scheme.onInverseSurface),
            ),
            IconButton(
              tooltip: 'Delete selected',
              onPressed: onDelete,
              color: scheme.errorContainer,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
