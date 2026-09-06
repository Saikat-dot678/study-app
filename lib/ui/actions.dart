import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import 'filing_sheet.dart';

enum _SpaceTemplate { blank, semester, exam, project }

Future<void> showAddSheet(
  BuildContext context,
  LibraryController controller, {
  required bool fromHome,
}) async {
  final basePath = fromHome ? '' : controller.currentPath;
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Study',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(basePath.isEmpty ? 'Library root' : basePath),
            const SizedBox(height: 16),
            for (final action in [
              (
                'Import material',
                'Choose files and a filing destination',
                Icons.file_download_outlined,
              ),
              (
                'New folder',
                'Another level inside this folder',
                Icons.create_new_folder_outlined,
              ),
              (
                'New workspace',
                'Semester, exam, research or blank',
                Icons.dashboard_customize_outlined,
              ),
              ('Quick note', 'Write a local Markdown note', Icons.edit_note),
            ])
              ListTile(
                leading: Icon(action.$3),
                title: Text(action.$1),
                subtitle: Text(action.$2),
                onTap: () => Navigator.pop(context, action.$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'Import material':
      await showSmartImportSheet(context, controller, basePath: basePath);
    case 'New folder':
      await showNewFolderDialog(context, controller, parent: basePath);
    case 'New workspace':
      await showCreateSpaceSheet(context, controller, parent: basePath);
    case 'Quick note':
      await showNewNoteSheet(context, controller, destination: basePath);
  }
}

Future<void> showSmartImportSheet(
  BuildContext context,
  LibraryController controller, {
  required String basePath,
}) async {
  await showFilingSheet(context, controller, initialPath: basePath);
}

Future<void> showCreateSpaceSheet(
  BuildContext context,
  LibraryController controller, {
  String parent = '',
}) async {
  final nameController = TextEditingController();
  var selected = _SpaceTemplate.blank;
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build a study workspace',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                parent.isEmpty
                    ? 'Create a top-level space, then nest without limits.'
                    : 'Create a structured space inside ${parent.split('/').last}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.folder_special_rounded),
                  labelText: 'Workspace name',
                  hintText: 'e.g. Semester 5, GATE, LoRa Research',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Starting structure',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              _TemplateChoice(
                selected: selected == _SpaceTemplate.blank,
                icon: Icons.account_tree_outlined,
                title: 'Blank & flexible',
                subtitle: 'Start empty and create any hierarchy yourself',
                onTap: () => setState(() => selected = _SpaceTemplate.blank),
              ),
              _TemplateChoice(
                selected: selected == _SpaceTemplate.semester,
                icon: Icons.school_rounded,
                title: 'Semester',
                subtitle: 'Subjects • Assignments • Exam Prep • Resources',
                onTap: () => setState(() => selected = _SpaceTemplate.semester),
              ),
              _TemplateChoice(
                selected: selected == _SpaceTemplate.exam,
                icon: Icons.workspace_premium_rounded,
                title: 'Exam / GATE',
                subtitle: 'Subjects • PYQs • Mock Tests • Revision',
                onTap: () => setState(() => selected = _SpaceTemplate.exam),
              ),
              _TemplateChoice(
                selected: selected == _SpaceTemplate.project,
                icon: Icons.science_rounded,
                title: 'Project / Research',
                subtitle: 'Papers • Notes • Data • Presentations',
                onTap: () => setState(() => selected = _SpaceTemplate.project),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(sheetContext, true);
                    await controller.createStructure(
                      parent: parent,
                      name: name,
                      children: _templateChildren(selected),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Create workspace'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  nameController.dispose();
  if (created == true) return;
}

List<String> _templateChildren(_SpaceTemplate template) => switch (template) {
  _SpaceTemplate.blank => const [],
  _SpaceTemplate.semester => const [
    'Subjects',
    'Assignments',
    'Exam Prep',
    'Resources',
  ],
  _SpaceTemplate.exam => const ['Subjects', 'PYQs', 'Mock Tests', 'Revision'],
  _SpaceTemplate.project => const ['Papers', 'Notes', 'Data', 'Presentations'],
};

class _TemplateChoice extends StatelessWidget {
  const _TemplateChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.72)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: 0.5)
                : scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EntryMenuRegion extends StatelessWidget {
  const EntryMenuRegion({
    super.key,
    required this.controller,
    required this.entry,
    required this.child,
  });
  final LibraryController controller;
  final LibraryEntry entry;
  final Widget child;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: (details) => showEntryActions(
      context,
      controller,
      entry,
      position: details.globalPosition,
    ),
    child: child,
  );
}

Future<void> showEntryActions(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry, {
  Offset? position,
}) async {
  if (position != null || MediaQuery.sizeOf(context).width >= 980) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final point = position == null
        ? overlay.size.center(Offset.zero)
        : overlay.globalToLocal(position);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(point.dx, point.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final label in [
          controller.isStarred(entry) ? 'Remove star' : 'Star',
          'Rename',
          'Move',
          if (!entry.isDirectory) 'Share',
          'Delete',
        ])
          PopupMenuItem(value: label, child: Text(label)),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'Star':
      case 'Remove star':
        await controller.toggleStar(entry);
      case 'Rename':
        await _renameDialog(context, controller, entry);
      case 'Move':
        await _moveSingle(context, controller, entry);
      case 'Share':
        await controller.shareEntry(entry);
      case 'Delete':
        await _deleteDialog(context, controller, entry);
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              controller.isStarred(entry)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            title: Text(
              controller.isStarred(entry)
                  ? 'Remove star'
                  : entry.isDirectory
                  ? 'Pin folder'
                  : 'Star material',
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              controller.toggleStar(entry);
            },
          ),
          if (!entry.isDirectory)
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share'),
              subtitle: const Text(
                'Send this material to another app or person',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.shareEntry(entry);
              },
            ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(sheetContext);
              _renameDialog(context, controller, entry);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: const Text('Move to…'),
            subtitle: const Text('Choose any folder at any depth'),
            onTap: () {
              Navigator.pop(sheetContext);
              _moveSingle(context, controller, entry);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              _deleteDialog(context, controller, entry);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showNewFolderDialog(
  BuildContext context,
  LibraryController controller, {
  required String parent,
}) async {
  final value = await _askForName(
    context,
    title: 'New folder',
    hint: 'e.g. Operating Systems',
  );
  if (value != null) await controller.createFolderAt(parent, value);
}

Future<String?> _askForName(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, input.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  input.dispose();
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Future<void> showNewNoteSheet(
  BuildContext context,
  LibraryController controller, {
  required String destination,
}) async {
  final title = TextEditingController();
  final body = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick note',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Saved in ${destination.isEmpty ? 'Library root' : destination}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: title,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: body,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Write anything… Markdown is supported.',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              final noteTitle = title.text.trim().isEmpty
                  ? 'Untitled note'
                  : title.text;
              final noteBody = body.text;
              Navigator.pop(sheetContext);
              await controller.createNoteAt(destination, noteTitle, noteBody);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save note'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  body.dispose();
}

Future<void> _renameDialog(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
  final input = TextEditingController(text: entry.name);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(controller: input, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, input.text),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  input.dispose();
  if (value != null && value.trim().isNotEmpty && value.trim() != entry.name) {
    await controller.renameEntry(entry, value);
  }
}

Future<void> _moveSingle(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
  await showBulkMoveSheet(context, controller, [entry]);
}

Future<bool> showBulkMoveSheet(
  BuildContext context,
  LibraryController controller,
  List<LibraryEntry> entries,
) async {
  if (entries.isEmpty) return false;
  return showFilingSheet(
    context,
    controller,
    initialPath: controller.currentPath == 'Inbox'
        ? ''
        : controller.currentPath,
    moving: entries,
  );
}

Future<void> _deleteDialog(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete ${entry.name}?'),
      content: Text(
        entry.isDirectory
            ? 'This deletes the folder and everything inside it from your library folder.'
            : 'This deletes the file from your library folder.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) await controller.deleteEntry(entry);
}

Future<bool> confirmBulkDelete(
  BuildContext context,
  LibraryController controller,
  List<LibraryEntry> entries,
) async {
  if (entries.isEmpty) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete ${entries.length} items?'),
      content: const Text(
        'Selected files and folders are permanently removed from your portable library folder.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete selected'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await controller.deleteEntries(entries);
  return controller.error == null;
}
