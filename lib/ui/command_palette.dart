import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../models/library_query.dart';
import '../viewers/viewer_page.dart';
import 'actions.dart';

Future<void> showCommandPalette(
  BuildContext context,
  LibraryController controller, {
  required ValueChanged<String> openFolder,
  required VoidCallback openSearch,
  required VoidCallback openSettings,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _Palette(
      controller: controller,
      hostContext: context,
      openFolder: openFolder,
      openSearch: openSearch,
      openSettings: openSettings,
    ),
  );
}

class _Palette extends StatefulWidget {
  const _Palette({
    required this.controller,
    required this.hostContext,
    required this.openFolder,
    required this.openSearch,
    required this.openSettings,
  });
  final LibraryController controller;
  final BuildContext hostContext;
  final ValueChanged<String> openFolder;
  final VoidCallback openSearch, openSettings;
  @override
  State<_Palette> createState() => _PaletteState();
}

class _Command {
  const _Command(this.title, this.subtitle, this.icon, this.run);
  final String title, subtitle;
  final IconData icon;
  final VoidCallback run;
}

class _PaletteState extends State<_Palette> {
  String query = '';
  int selected = 0;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  List<_Command> get commands {
    final c = widget.controller;
    final host = widget.hostContext;
    final actions = [
      _Command(
        'Search library',
        'Names, paths and file types',
        Icons.search,
        widget.openSearch,
      ),
      if (c.connected) ...[
        _Command(
          'Import material',
          c.currentPath.isEmpty ? 'Library root' : c.currentPath,
          Icons.file_download_outlined,
          () => showSmartImportSheet(host, c, basePath: c.currentPath),
        ),
        _Command(
          'New folder',
          'Create inside the current folder',
          Icons.create_new_folder_outlined,
          () => showNewFolderDialog(host, c, parent: c.currentPath),
        ),
        _Command(
          'New workspace',
          'Semester, exam or research',
          Icons.dashboard_customize_outlined,
          () => showCreateSpaceSheet(host, c, parent: c.currentPath),
        ),
        _Command(
          'New note',
          'Save a local Markdown note',
          Icons.edit_note,
          () => showNewNoteSheet(host, c, destination: c.currentPath),
        ),
        _Command(
          'Open Inbox',
          'Organize captured material',
          Icons.inbox_outlined,
          () => widget.openFolder('Inbox'),
        ),
        _Command(
          'Toggle grid / list',
          'Change material layout',
          Icons.grid_view,
          () => c.setGridMode(!c.gridMode),
        ),
      ],
      _Command(
        'Settings',
        'Library connection and privacy',
        Icons.tune,
        widget.openSettings,
      ),
    ];
    final parsed = LibraryQuery(query);
    return [
      ...actions.where(
        (a) =>
            query.trim().isEmpty ||
            a.title.toLowerCase().contains(query.toLowerCase()),
      ),
      for (final entry
          in (query.trim().isEmpty
              ? c.recentFiles
              : c.allEntries
                    .where((e) => parsed.matches(e, starred: c.isStarred(e)))
                    .take(50)))
        _Command(
          entry.name,
          entry.path,
          entry.isDirectory
              ? Icons.folder_outlined
              : Icons.description_outlined,
          () {
            if (entry.isDirectory) {
              widget.openFolder(entry.path);
            } else {
              openStudyViewer(host, c, entry);
            }
          },
        ),
    ];
  }

  void execute(List<_Command> values) {
    if (values.isEmpty) return;
    final action = values[selected.clamp(0, values.length - 1)];
    Navigator.pop(context);
    action.run();
  }

  void _step(int delta, int length) {
    if (length == 0) return;
    setState(() => selected = (selected + delta).clamp(0, length - 1));
    if (scroll.hasClients) {
      scroll.jumpTo(
        (selected * 72.0 * MediaQuery.textScalerOf(context).scale(1)).clamp(
          0,
          scroll.position.maxScrollExtent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = commands;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _step(1, values.length),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _step(-1, values.length),
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                execute(values),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() {
                    query = value;
                    selected = 0;
                  }),
                  onSubmitted: (_) => execute(values),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search files or run a command…',
                    helperText: '↑ ↓ navigate · Enter open · Esc close',
                  ),
                ),
              ),
              const Divider(height: 1),
              if (values.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No matches. Try a subject, file type or action.',
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  controller: scroll,
                  shrinkWrap: true,
                  itemCount: values.length,
                  itemExtent: 72 * MediaQuery.textScalerOf(context).scale(1),
                  itemBuilder: (context, index) {
                    final value = values[index];
                    return ListTile(
                      selected: selected == index,
                      leading: Icon(value.icon),
                      title: Text(
                        value.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        value.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        selected = index;
                        execute(values);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
