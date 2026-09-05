import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';

class StudyShell extends StatefulWidget {
  const StudyShell({super.key});

  @override
  State<StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<StudyShell> {
  late final LibraryController controller;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    controller = LibraryController()..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _goLibrary([String? path]) {
    if (path != null) controller.openFolder(path);
    setState(() => pageIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pages = <Widget>[
          _HomePage(controller: controller, openLibrary: _goLibrary),
          _LibraryPage(controller: controller),
          _SearchPage(controller: controller, openLibrary: _goLibrary),
          _SettingsPage(controller: controller),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('Study App'),
              ],
            ),
            actions: [
              if (controller.connected)
                IconButton(
                  tooltip: 'Refresh library',
                  onPressed: controller.busy ? null : controller.refresh,
                  icon: const Icon(Icons.sync_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (controller.error != null)
                _StatusStrip(
                  icon: Icons.error_outline_rounded,
                  text: controller.error!,
                  error: true,
                )
              else if (controller.notice != null)
                _StatusStrip(
                  icon: Icons.check_circle_outline_rounded,
                  text: controller.notice!,
                ),
              if (controller.busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: pages[pageIndex]),
            ],
          ),
          floatingActionButton: controller.connected && pageIndex <= 1
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddSheet(context, controller, pageIndex == 0),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: pageIndex,
            onDestinationSelected: (index) => setState(() => pageIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.controller, required this.openLibrary});

  final LibraryController controller;
  final ValueChanged<String?> openLibrary;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) {
      return _ConnectLibrary(controller: controller);
    }

    final recent = controller.recentFiles;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _HeroCard(controller: controller),
          const SizedBox(height: 28),
          _SectionTitle(title: 'Quick access', action: 'Open library', onTap: () => openLibrary(null)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 5 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _QuickFolder(label: 'Inbox', icon: Icons.inbox_rounded, onTap: () => openLibrary('Inbox')),
              _QuickFolder(label: 'Notes', icon: Icons.edit_note_rounded, onTap: () => openLibrary('Notes')),
              _QuickFolder(label: 'Books', icon: Icons.menu_book_rounded, onTap: () => openLibrary('Books')),
              _QuickFolder(label: 'Slides', icon: Icons.slideshow_rounded, onTap: () => openLibrary('Slides')),
              _QuickFolder(label: 'Recordings', icon: Icons.graphic_eq_rounded, onTap: () => openLibrary('Recordings')),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionTitle(title: 'At a glance'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountPill(icon: Icons.picture_as_pdf_rounded, label: 'PDFs', count: controller.countKind(LibraryKind.pdf)),
              _CountPill(icon: Icons.slideshow_rounded, label: 'Slides', count: controller.countKind(LibraryKind.slides)),
              _CountPill(icon: Icons.audio_file_rounded, label: 'Audio', count: controller.countKind(LibraryKind.audio)),
              _CountPill(icon: Icons.description_rounded, label: 'Notes', count: controller.countKind(LibraryKind.note)),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionTitle(title: 'Recently touched'),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const _EmptyCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Your library is ready',
              subtitle: 'Import a PDF, PPT, recording or create your first note.',
            )
          else
            ...recent.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FileRow(
                  entry: entry,
                  onTap: () => controller.openEntry(entry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.offline_bolt_rounded),
              const SizedBox(width: 8),
              Text('Offline • portable', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 24),
          Text('Everything for class,\nin one calm place.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.05)),
          const SizedBox(height: 12),
          Text('${controller.allEntries.where((item) => !item.isDirectory).length} files • ${controller.libraryName ?? 'Library'}', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 22),
          FilledButton.tonalIcon(
            onPressed: () => controller.importFiles(destination: 'Inbox'),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import to Inbox'),
          ),
        ],
      ),
    );
  }
}

class _ConnectLibrary extends StatelessWidget {
  const _ConnectLibrary({required this.controller});
  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 28),
        Icon(Icons.folder_copy_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text('Choose your study library folder', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Study App stores everything locally in one folder you choose. You can copy that folder to another phone later and reconnect it there.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: controller.connectLibrary,
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('Choose or connect folder'),
        ),
        const SizedBox(height: 14),
        Text('No account • no cloud • no all-files permission', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.controller});
  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) return _ConnectLibrary(controller: controller);
    final title = controller.currentPath.isEmpty ? 'Library' : controller.currentPath.split('/').last;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              if (controller.currentPath.isNotEmpty)
                IconButton(onPressed: controller.goUp, icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text(controller.currentPath.isEmpty ? 'Root folder' : controller.currentPath, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: controller.gridMode ? 'List view' : 'Grid view',
                onPressed: () => controller.setGridMode(!controller.gridMode),
                icon: Icon(controller.gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.entries.isEmpty
              ? const Center(child: _EmptyCard(icon: Icons.folder_open_rounded, title: 'This folder is empty', subtitle: 'Add files, a folder or a quick note.'))
              : controller.gridMode
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, childAspectRatio: 0.93, mainAxisSpacing: 12, crossAxisSpacing: 12),
                      itemCount: controller.entries.length,
                      itemBuilder: (context, index) => _GridEntry(controller: controller, entry: controller.entries[index]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                      itemCount: controller.entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _LibraryRow(controller: controller, entry: controller.entries[index]),
                    ),
        ),
      ],
    );
  }
}

class _SearchPage extends StatefulWidget {
  const _SearchPage({required this.controller, required this.openLibrary});
  final LibraryController controller;
  final ValueChanged<String?> openLibrary;

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  String query = '';
  LibraryKind? kind;

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.connected) return _ConnectLibrary(controller: widget.controller);
    final normalized = query.trim().toLowerCase();
    final results = widget.controller.allEntries.where((entry) {
      final matchesText = normalized.isEmpty || entry.name.toLowerCase().contains(normalized) || entry.path.toLowerCase().contains(normalized);
      final matchesKind = kind == null || entry.kind == kind;
      return matchesText && matchesKind;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        TextField(
          autofocus: false,
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search files, folders, notes…'),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(label: 'All', selected: kind == null, onTap: () => setState(() => kind = null)),
              _FilterChip(label: 'PDF', selected: kind == LibraryKind.pdf, onTap: () => setState(() => kind = LibraryKind.pdf)),
              _FilterChip(label: 'Slides', selected: kind == LibraryKind.slides, onTap: () => setState(() => kind = LibraryKind.slides)),
              _FilterChip(label: 'Audio', selected: kind == LibraryKind.audio, onTap: () => setState(() => kind = LibraryKind.audio)),
              _FilterChip(label: 'Notes', selected: kind == LibraryKind.note, onTap: () => setState(() => kind = LibraryKind.note)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('${results.length} result${results.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        ...results.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FileRow(
                entry: entry,
                showPath: true,
                onTap: () {
                  if (entry.isDirectory) {
                    widget.openLibrary(entry.path);
                  } else {
                    widget.controller.openEntry(entry);
                  }
                },
              ),
            )),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller});
  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text('Storage', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(controller.connected ? Icons.folder_special_rounded : Icons.folder_off_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(controller.connected ? controller.libraryName ?? 'Connected folder' : 'No library connected', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 10),
                Text(controller.connected ? 'This is the only place Study App stores your study material.' : 'Choose an existing folder or create a new one with Android’s folder picker.'),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.tonalIcon(onPressed: controller.connectLibrary, icon: const Icon(Icons.drive_file_move_outline), label: Text(controller.connected ? 'Change folder' : 'Connect folder')),
                  if (controller.connected)
                    OutlinedButton.icon(onPressed: controller.refresh, icon: const Icon(Icons.sync_rounded), label: const Text('Rescan')),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Move to a new phone', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.phone_android_rounded,
          title: 'Copy once, reconnect once',
          body: 'Copy the entire library folder to the new phone, install Study App, then choose that copied folder. Nested folders, notes and files appear again because the folder itself is the library.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.shield_outlined,
          title: 'Private by default',
          body: 'No account, analytics service or backend is required. Android only grants Study App access to the folder you explicitly choose.',
        ),
        if (controller.connected) ...[
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmForget(context, controller),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Forget folder connection'),
          ),
          const SizedBox(height: 8),
          Text('This never deletes the folder or any material inside it.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.controller, required this.entry});
  final LibraryController controller;
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _FileIcon(entry: entry),
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w650)),
        subtitle: Text(entry.isDirectory ? 'Folder' : _fileMeta(entry), maxLines: 1),
        onTap: () => controller.openEntry(entry),
        trailing: IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _showEntryActions(context, controller, entry)),
      ),
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _FileIcon(entry: entry, large: true),
                IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _showEntryActions(context, controller, entry)),
              ]),
              const Spacer(),
              Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(entry.isDirectory ? 'Folder' : _fileMeta(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.entry, required this.onTap, this.showPath = false});
  final LibraryEntry entry;
  final VoidCallback onTap;
  final bool showPath;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: _FileIcon(entry: entry),
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(showPath ? entry.path : (entry.isDirectory ? 'Folder' : _fileMeta(entry)), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.entry, this.large = false});
  final LibraryEntry entry;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.kind) {
      LibraryKind.folder => Icons.folder_rounded,
      LibraryKind.pdf => Icons.picture_as_pdf_rounded,
      LibraryKind.slides => Icons.slideshow_rounded,
      LibraryKind.document => Icons.description_rounded,
      LibraryKind.note => Icons.edit_note_rounded,
      LibraryKind.audio => Icons.graphic_eq_rounded,
      LibraryKind.video => Icons.movie_rounded,
      LibraryKind.image => Icons.image_rounded,
      LibraryKind.archive => Icons.archive_rounded,
      LibraryKind.other => Icons.insert_drive_file_rounded,
    };
    final size = large ? 48.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer, size: large ? 27 : 23),
    );
  }
}

class _QuickFolder extends StatelessWidget {
  const _QuickFolder({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.icon, required this.label, required this.count});
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 8), Text('$count $label')]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body),
          ])),
        ]),
      ),
    );
  }
}

String _fileMeta(LibraryEntry entry) {
  if (entry.isDirectory) return 'Folder';
  final bytes = entry.size;
  final size = bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : bytes < 1024 * 1024 * 1024
              ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  return entry.extension.isEmpty ? size : '${entry.extension.toUpperCase()} • $size';
}

Future<void> _showAddSheet(BuildContext context, LibraryController controller, bool fromHome) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import files'),
            subtitle: Text(fromHome ? 'Put selected files in Inbox' : 'Put selected files in this folder'),
            onTap: () {
              Navigator.pop(sheetContext);
              controller.importFiles(destination: fromHome ? 'Inbox' : controller.currentPath);
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
        ]),
      ),
    ),
  );
}

Future<void> _newFolderDialog(BuildContext context, LibraryController controller) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(controller: input, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text), child: const Text('Create')),
      ],
    ),
  );
  if (value != null) await controller.createFolder(value);
}

Future<void> _newNoteSheet(BuildContext context, LibraryController controller) async {
  final title = TextEditingController();
  final body = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Quick note', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(controller: title, autofocus: true, decoration: const InputDecoration(hintText: 'Title')),
        const SizedBox(height: 10),
        TextField(controller: body, minLines: 6, maxLines: 12, decoration: const InputDecoration(hintText: 'Write anything…')),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(sheetContext);
            await controller.createNote(title.text.isEmpty ? 'Untitled note' : title.text, body.text);
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save note'),
        ),
      ]),
    ),
  );
}

Future<void> _showEntryActions(BuildContext context, LibraryController controller, LibraryEntry entry) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: const Text('Rename'), onTap: () { Navigator.pop(sheetContext); _renameDialog(context, controller, entry); }),
        ListTile(leading: const Icon(Icons.drive_file_move_outline), title: const Text('Move to…'), onTap: () { Navigator.pop(sheetContext); _moveDialog(context, controller, entry); }),
        ListTile(leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error), title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)), onTap: () { Navigator.pop(sheetContext); _deleteDialog(context, controller, entry); }),
      ]),
    ),
  );
}

Future<void> _renameDialog(BuildContext context, LibraryController controller, LibraryEntry entry) async {
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
  if (value != null && value.trim().isNotEmpty && value.trim() != entry.name) await controller.renameEntry(entry, value);
}

Future<void> _moveDialog(BuildContext context, LibraryController controller, LibraryEntry entry) async {
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
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Move ${entry.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Expanded(child: ListView.builder(
            itemCount: folders.length,
            itemBuilder: (_, index) {
              final path = folders[index];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(path.isEmpty ? 'Library root' : path.split('/').last),
                subtitle: path.isEmpty ? null : Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(sheetContext, path),
              );
            },
          )),
        ]),
      ),
    ),
  );
  if (destination != null) await controller.moveEntry(entry, destination);
}

Future<void> _deleteDialog(BuildContext context, LibraryController controller, LibraryEntry entry) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete ${entry.name}?'),
      content: Text(entry.isDirectory ? 'This deletes the folder and everything inside it from your library folder.' : 'This deletes the file from your library folder.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok == true) await controller.deleteEntry(entry);
}

Future<void> _confirmForget(BuildContext context, LibraryController controller) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Forget folder connection?'),
      content: const Text('Study App will lose access until you select a folder again. Your files will not be deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Forget')),
      ],
    ),
  );
  if (ok == true) await controller.forgetLibrary();
}
