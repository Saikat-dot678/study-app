import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';

enum _SpaceTemplate { blank, semester, exam, project }

class _MaterialBucket {
  const _MaterialBucket(this.name, this.icon, this.caption);

  final String name;
  final IconData icon;
  final String caption;
}

const _materialBuckets = <_MaterialBucket>[
  _MaterialBucket('Notes', Icons.edit_note_rounded, 'Handwritten scans, text, docs'),
  _MaterialBucket('Slides', Icons.slideshow_rounded, 'PPT, PPTX and lecture decks'),
  _MaterialBucket('Books', Icons.auto_stories_rounded, 'PDFs, books and references'),
  _MaterialBucket('PYQs', Icons.history_edu_rounded, 'Previous-year questions'),
  _MaterialBucket('Assignments', Icons.assignment_rounded, 'Sheets, homework and solutions'),
  _MaterialBucket('Papers', Icons.science_rounded, 'Research papers and reading'),
  _MaterialBucket('Videos', Icons.smart_display_rounded, 'Lectures and recorded classes'),
  _MaterialBucket('Audio', Icons.graphic_eq_rounded, 'Recordings and audio lectures'),
  _MaterialBucket('Code', Icons.code_rounded, 'Programs, notebooks and datasets'),
];

Future<void> showAddSheet(
  BuildContext context,
  LibraryController controller, {
  required bool fromHome,
}) async {
  final basePath = fromHome ? '' : controller.currentPath;
  final targetLabel = basePath.isEmpty ? 'Library root' : basePath.split('/').last;
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add to Study', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    Text('Inside $targetLabel', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _AddCard(
                icon: Icons.auto_awesome_motion_rounded,
                title: 'Smart import',
                subtitle: 'Choose a material type and file it automatically',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showSmartImportSheet(context, controller, basePath: basePath);
                },
              ),
              _AddCard(
                icon: Icons.create_new_folder_outlined,
                title: 'New folder',
                subtitle: 'Create another level anywhere',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _newFolderDialog(context, controller, parent: basePath);
                },
              ),
              _AddCard(
                icon: Icons.dashboard_customize_rounded,
                title: 'New workspace',
                subtitle: 'Semester, exam, project or blank structure',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showCreateSpaceSheet(context, controller, parent: basePath);
                },
              ),
              _AddCard(
                icon: Icons.note_add_outlined,
                title: 'Quick note',
                subtitle: 'Save Markdown directly in this folder',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _newNoteSheet(context, controller, destination: basePath);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(sheetContext);
                showModalBottomSheet<void>(context: context, builder: (_) => const _ShareHintSheet());
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.ios_share_rounded, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('Tip: share from WhatsApp, Files or Gallery → Study App → Inbox')),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showSmartImportSheet(
  BuildContext context,
  LibraryController controller, {
  required String basePath,
}) async {
  final destinationLabel = basePath.isEmpty ? 'Library root' : basePath;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where should this material go?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(
                'Base: $destinationLabel. Choose a type and Study will create/reuse that folder here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 1.45,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  children: [
                    _BucketCard(
                      icon: Icons.layers_clear_rounded,
                      title: 'Keep here',
                      caption: 'Place files directly beside folders',
                      highlighted: true,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        controller.importOrganized(basePath: basePath);
                      },
                    ),
                    for (final bucket in _materialBuckets)
                      _BucketCard(
                        icon: bucket.icon,
                        title: bucket.name,
                        caption: bucket.caption,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          controller.importOrganized(basePath: basePath, category: bucket.name);
                        },
                      ),
                    _BucketCard(
                      icon: Icons.create_new_folder_rounded,
                      title: 'Custom type',
                      caption: 'Create your own category name',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final custom = await _askForName(context, title: 'Custom material type', hint: 'e.g. Cheatsheets');
                        if (custom != null) {
                          await controller.importOrganized(basePath: basePath, category: custom);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
              Text('Build a study workspace', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(
                parent.isEmpty ? 'Create a top-level space, then nest without limits.' : 'Create a structured space inside ${parent.split('/').last}.',
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
              Text('Starting structure', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
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
      _SpaceTemplate.semester => const ['Subjects', 'Assignments', 'Exam Prep', 'Resources'],
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
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.72) : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: highlighted ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.34)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
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
              'In WhatsApp, Gallery, Files or another app: tap Share → Study App. One or many files are copied into Inbox. Open Inbox later and move them into any semester, subject, GATE, project or custom folder.',
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
            subtitle: const Text('Choose any folder at any depth'),
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
  final value = await _askForName(context, title: 'New folder', hint: 'e.g. Operating Systems');
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
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text), child: const Text('Create')),
      ],
    ),
  );
  input.dispose();
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
          height: MediaQuery.sizeOf(context).height * 0.78,
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
                const SizedBox(height: 5),
                const Text('Every nested folder is available as a destination.'),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setSheetState(() => query = value),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Find Semester 5 / DBMS / Notes…'),
                ),
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
