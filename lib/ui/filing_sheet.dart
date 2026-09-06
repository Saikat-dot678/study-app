import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../storage/storage_bridge.dart';

Future<bool> showFilingSheet(
  BuildContext context,
  LibraryController controller, {
  required String initialPath,
  List<LibraryEntry>? moving,
  List<String>? sourcePaths,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _FilingSheet(
          controller: controller,
          initialPath: initialPath,
          moving: moving,
          sourcePaths: sourcePaths,
        ),
      ) ??
      false;
}

class _FilingSheet extends StatefulWidget {
  const _FilingSheet({
    required this.controller,
    required this.initialPath,
    this.moving,
    this.sourcePaths,
  });
  final LibraryController controller;
  final String initialPath;
  final List<LibraryEntry>? moving;
  final List<String>? sourcePaths;
  @override
  State<_FilingSheet> createState() => _FilingSheetState();
}

class _FilingSheetState extends State<_FilingSheet> {
  late String destination = widget.initialPath;
  String query = '', category = '';
  String? error;
  bool saving = false;
  final custom = TextEditingController();
  static const categories = [
    '',
    'Notes',
    'Slides',
    'Books',
    'PYQs',
    'Assignments',
    'Papers',
    'Videos',
    'Audio',
    'Code',
    'Custom',
  ];
  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  bool allowed(String path) => !(widget.moving ?? []).any(
    (entry) =>
        entry.isDirectory &&
        (path == entry.path || path.startsWith('${entry.path}/')),
  );

  String get bucket => category == 'Custom' ? custom.text.trim() : category;
  String get target => bucket.isEmpty
      ? destination
      : destination.isEmpty
      ? bucket
      : '$destination/$bucket';

  Future<void> submit() async {
    if (saving) return;
    try {
      if (category == 'Custom' || bucket.isNotEmpty) {
        StorageBridge.validateName(bucket);
      }
      if (!allowed(target)) {
        throw StateError('Choose a folder outside the selection.');
      }
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    if (widget.moving == null) {
      await widget.controller.importOrganized(
        basePath: destination,
        sourcePaths: widget.sourcePaths,
        category: bucket.isEmpty ? null : bucket,
      );
    } else {
      await widget.controller.moveOrganized(
        widget.moving!,
        destination,
        bucket,
      );
    }
    if (!mounted) return;
    if (widget.controller.error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        saving = false;
        error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final recent = controller.recentDestinations;
    final pinned = controller.starredEntries
        .where((e) => e.isDirectory)
        .map((e) => e.path)
        .toSet();
    final folders = controller.folderPaths
        .where(allowed)
        .where(
          (path) => query
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .every(
                (word) => (path.isEmpty ? 'library root' : path)
                    .toLowerCase()
                    .contains(word),
              ),
        )
        .toList();
    folders.sort((a, b) {
      int rank(String p) => recent.contains(p)
          ? recent.indexOf(p)
          : pinned.contains(p)
          ? 10
          : 20;
      final order = rank(a).compareTo(rank(b));
      return order == 0 ? a.toLowerCase().compareTo(b.toLowerCase()) : order;
    });
    return PopScope(
      canPop: !saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.moving == null
                                  ? 'Import material'
                                  : 'File ${widget.moving!.length} items',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose a destination. Add a category if it helps.',
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => query = value),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Find a folder',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'DESTINATION',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final path = folders[index];
                        return ListTile(
                          selected: destination == path,
                          leading: Icon(
                            pinned.contains(path)
                                ? Icons.star_outline
                                : recent.contains(path)
                                ? Icons.history
                                : Icons.folder_outlined,
                          ),
                          title: Text(
                            path.isEmpty
                                ? 'Library root'
                                : path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            path.isEmpty ? 'Top level' : path,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: destination == path
                              ? const Icon(Icons.check_circle_outline)
                              : null,
                          onTap: saving
                              ? null
                              : () => setState(() => destination = path),
                        );
                      },
                    ),
                    if (folders.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No matching folder. Try a subject or semester name.',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final value in categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  value.isEmpty ? 'Keep here' : value,
                                ),
                                selected: category == value,
                                onSelected: saving
                                    ? null
                                    : (_) => setState(() => category = value),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (category == 'Custom')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: custom,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Custom category',
                            hintText: 'e.g. Formula sheets',
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'To: ${target.isEmpty ? 'Library root' : target}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (error != null)
                      Text(
                        error!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: saving ? null : submit,
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              widget.moving == null
                                  ? Icons.file_open_outlined
                                  : Icons.drive_file_move_outline,
                            ),
                      label: Text(
                        saving
                            ? 'Working locally…'
                            : widget.moving == null
                            ? widget.sourcePaths == null
                                  ? 'Choose files'
                                  : 'Import ${widget.sourcePaths!.length} files'
                            : 'Move here',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
