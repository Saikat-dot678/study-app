import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';

Future<void> showAddSheet(
  BuildContext context,
  LibraryController controller, {
  required bool fromHome,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Import files'),
              subtitle: Text(
                fromHome
                    ? 'Put selected files in Inbox'
                    : 'Put selected files in this folder',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.importFiles(
                  destination: fromHome ? 'Inbox' : controller.currentPath,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              subtitle: const Text('Folders can contain more folders'),
              onTap: () {
                Navigator.pop(sheetContext);
                _newFolderDialog(context, controller);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Quick note'),
              subtitle: const Text('Saved as a portable Markdown file'),
              onTap: () {
                Navigator.pop(sheetContext);
                _newNoteSheet(context, controller);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showEntryActions(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            onTap: () {
              Navigator.pop(sheetContext);
              _moveDialog(context, controller, entry);
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

Future<void> _newFolderDialog(
  BuildContext context,
  LibraryController controller,
) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: input,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
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
  if (value != null) await controller.createFolder(value);
}

Future<void> _newNoteSheet(
  BuildContext context,
  LibraryController controller,
) async {
  final title = TextEditingController();
  final body = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
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
            decoration: const InputDecoration(hintText: 'Write anything…'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              final noteTitle = title.text.trim().isEmpty ? 'Untitled note' : title.text;
              final noteBody = body.text;
              Navigator.pop(sheetContext);
              await controller.createNote(noteTitle, noteBody);
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

Future<void> _moveDialog(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
  final folders = controller.folderPaths.where((path) {
    if (!entry.isDirectory) return path != entry.path;
    return path != entry.path && !path.startsWith('${entry.path}/');
  }).toList();

  final destination = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Move ${entry.name}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: folders.length,
                itemBuilder: (_, index) {
                  final path = folders[index];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      path.isEmpty ? 'Library root' : path.split('/').last,
                    ),
                    subtitle: path.isEmpty
                        ? null
                        : Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => Navigator.pop(sheetContext, path),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (destination != null) await controller.moveEntry(entry, destination);
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
