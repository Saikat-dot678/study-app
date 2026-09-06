import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../models/library_query.dart';
import 'actions.dart';
import '../viewers/viewer_page.dart';
import 'library_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.controller,
    required this.openLibrary,
  });

  final LibraryController controller;
  final ValueChanged<String?> openLibrary;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController input = TextEditingController();
  String query = '';
  LibraryKind? kind;
  bool starredOnly = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.connected) {
      return ConnectLibraryView(controller: widget.controller);
    }

    final parsed = LibraryQuery(query);
    final results =
        widget.controller.allEntries
            .where(
              (entry) =>
                  parsed.matches(
                    entry,
                    starred: widget.controller.isStarred(entry),
                  ) &&
                  (!starredOnly || widget.controller.isStarred(entry)) &&
                  (kind == null || entry.kind == kind),
            )
            .toList()
          ..sort(
            (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
          );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find anything',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6),
        ),
        const SizedBox(height: 6),
        Text(
          'Search names and folder paths across your complete offline library.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: input,
          autofocus: true,
          onSubmitted: (_) {
            if (results.isNotEmpty) _open(results.first);
          },
          onChanged: (value) => setState(() => query = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Try “DBMS”, “lecture”, “semester 5”…',
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      input.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Filter(
                label: 'Starred',
                icon: Icons.star_outline,
                selected: starredOnly,
                onTap: () => setState(() => starredOnly = !starredOnly),
              ),
              _Filter(
                label: 'Folders',
                icon: Icons.folder_outlined,
                selected: kind == LibraryKind.folder,
                onTap: () => setState(() => kind = LibraryKind.folder),
              ),
              _Filter(
                label: 'All',
                icon: Icons.all_inclusive_rounded,
                selected: kind == null,
                onTap: () => setState(() => kind = null),
              ),
              _Filter(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                selected: kind == LibraryKind.pdf,
                onTap: () => setState(() => kind = LibraryKind.pdf),
              ),
              _Filter(
                label: 'Books',
                icon: Icons.auto_stories_rounded,
                selected: kind == LibraryKind.book,
                onTap: () => setState(() => kind = LibraryKind.book),
              ),
              _Filter(
                label: 'Slides',
                icon: Icons.slideshow_rounded,
                selected: kind == LibraryKind.slides,
                onTap: () => setState(() => kind = LibraryKind.slides),
              ),
              _Filter(
                label: 'Video',
                icon: Icons.movie_rounded,
                selected: kind == LibraryKind.video,
                onTap: () => setState(() => kind = LibraryKind.video),
              ),
              _Filter(
                label: 'Audio',
                icon: Icons.graphic_eq_rounded,
                selected: kind == LibraryKind.audio,
                onTap: () => setState(() => kind = LibraryKind.audio),
              ),
              _Filter(
                label: 'Notes',
                icon: Icons.edit_note_rounded,
                selected: kind == LibraryKind.note,
                onTap: () => setState(() => kind = LibraryKind.note),
              ),
              _Filter(
                label: 'Docs',
                icon: Icons.description_rounded,
                selected: kind == LibraryKind.document,
                onTap: () => setState(() => kind = LibraryKind.document),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Text(
              '${results.length} result${results.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (query.isEmpty)
              Text(
                'Type to narrow down',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 50),
            child: EmptyCard(
              icon: Icons.search_off_rounded,
              title: 'Nothing matched',
              subtitle: 'Try a shorter keyword or switch the material filter.',
            ),
          ),
      ],
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(child: header),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final entry = results[index];
              return FileRow(
                entry: entry,
                showPath: true,
                onTap: () => _open(entry),
                trailing: IconButton(
                  tooltip: 'Material actions',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () =>
                      showEntryActions(context, widget.controller, entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _open(LibraryEntry entry) {
    if (entry.isDirectory) {
      widget.openLibrary(entry.path);
    } else {
      openStudyViewer(context, widget.controller, entry);
    }
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
