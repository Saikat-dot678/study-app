import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';

Future<void> showAddSheet(
  BuildContext context,
  LibraryController controller, {
  required bool fromHome,
}) async {
  final targetLabel = fromHome ? 'Inbox' : (controller.currentPath.isEmpty ? 'Library root' : controller.currentPath.split('/').last);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add to Study', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Destination: $targetLabel', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              _AddCard(
                icon: Icons.add_to_photos_outlined,
                title: 'Import anything',
                subtitle: 'PDF, PPT, book, video, audio, images & more',
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.importFiles(destination: fromHome ? 'Inbox' : controller.currentPath);
                },
              ),
              _AddCard(
                icon: Icons.create_new_folder_outlined,
                title: 'New folder',
                subtitle: 'Nest folders as deeply as you need',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _newFolderDialog(context, controller, parent: fromHome ? '' : controller.currentPath);
                },
              ),
              _AddCard(
                icon: Icons.note_add_outlined,
                title: 'Quick note',
                subtitle: 'Portable Markdown, stored with your files',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _newNoteSheet(context, controller, destination: fromHome ? 'Notes' : controller.currentPath);
                },
              ),
              _AddCard(
                icon: Icons.ios_share_rounded,
                title: 'From other apps',
                subtitle: 'Share from WhatsApp, Files, Gallery and more',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const _ShareHintSheet(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: scheme.primary),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareHintSheet extends StatelessWidget {
  const _ShareHintSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 50, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text('Share straight into your Inbox', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'In WhatsApp, Gallery, Files or another app: tap Share → Study App. One or many files are copied into your Study Inbox, ready to organize.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showEntryActions(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
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
                  child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          if (!entry.isDirectory)
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share'),
              subtitle: const Text('Send this material to another app or person'),
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
            subtitle: Text(_suggestedFolder(entry) == null ? 'Choose any folder' : 'Suggested: ${_suggestedFolder(entry)}'),
            onTap: () {
              Navigator.pop(sheetContext);
              _moveSingle(context, controller, entry);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
            title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

Future<void> _newFolderDialog(
  BuildContext context,
  LibraryController controller, {
  required String parent,
}) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: input,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'e.g. Semester 5'),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text), child: const Text('Create')),
      ],
    ),
  );
  input.dispose();
  if (value != null) await controller.createFolderAt(parent, value);
}

Future<void> _newNoteSheet(
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
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick note', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Saved in ${destination.isEmpty ? 'Library root' : destination}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(hintText: 'Title')),
          const SizedBox(height: 10),
          TextField(
            controller: body,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(hintText: 'Write anything… Markdown is supported.'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              final noteTitle = title.text.trim().isEmpty ? 'Untitled note' : title.text;
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
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text), child: const Text('Rename')),
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
  final destination = await _pickDestination(context, controller, [entry]);
  if (destination != null) await controller.moveEntry(entry, destination);
}

Future<bool> showBulkMoveSheet(
  BuildContext context,
  LibraryController controller,
  List<LibraryEntry> entries,
) async {
  if (entries.isEmpty) return false;
  final destination = await _pickDestination(context, controller, entries);
  if (destination == null) return false;
  await controller.moveEntries(entries, destination);
  return controller.error == null;
}

Future<String?> _pickDestination(
  BuildContext context,
  LibraryController controller,
  List<LibraryEntry> entries,
) async {
  final blocked = <String>{};
  for (final entry in entries.where((entry) => entry.isDirectory)) {
    blocked.add(entry.path);
    blocked.addAll(controller.folderPaths.where((path) => path.startsWith('${entry.path}/')));
  }
  final folders = controller.folderPaths.where((path) => !blocked.contains(path)).toList();
  final suggestions = entries.length == 1
      ? [_suggestedFolder(entries.first)].whereType<String>().where(folders.contains).toList()
      : <String>[];
  String query = '';

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final normalized = query.trim().toLowerCase();
        final filtered = folders.where((path) {
          if (normalized.isEmpty) return true;
          return (path.isEmpty ? 'library root' : path).toLowerCase().contains(normalized);
        }).toList();
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entries.length == 1 ? 'Move ${entries.first.name}' : 'Move ${entries.length} items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setSheetState(() => query = value),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Find a folder'),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Suggested', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final path in suggestions)
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: Text(path),
                          onPressed: () => Navigator.pop(sheetContext, path),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final path = filtered[index];
                      return ListTile(
                        leading: Icon(path.isEmpty ? Icons.home_rounded : Icons.folder_rounded),
                        title: Text(path.isEmpty ? 'Library root' : path.split('/').last),
                        subtitle: path.isEmpty ? null : Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(sheetContext, path),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String? _suggestedFolder(LibraryEntry entry) => switch (entry.kind) {
      LibraryKind.book || LibraryKind.pdf => 'Books',
      LibraryKind.slides => 'Slides',
      LibraryKind.audio => 'Recordings',
      LibraryKind.video => 'Videos',
      LibraryKind.note || LibraryKind.document => 'Notes',
      _ => null,
    };

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
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
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
      content: const Text('Selected files and folders are permanently removed from your portable library folder.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete selected')),
      ],
    ),
  );
  if (ok != true) return false;
  await controller.deleteEntries(entries);
  return controller.error == null;
}
