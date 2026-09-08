import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import 'library_widgets.dart';
import 'motion.dart';

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
  bool favoritesOnly = false;

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

    final results = widget.controller
        .searchEntries(query, kind: kind)
        .where(
          (entry) => !favoritesOnly || widget.controller.isFavorite(entry.path),
        )
        .toList();

    void open(LibraryEntry entry) {
      if (entry.isDirectory) {
        widget.openLibrary(entry.path);
      } else {
        openStudyViewer(context, widget.controller, entry);
      }
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search your study graph',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ranked fuzzy search across names and paths. Everything stays on this device.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: input,
                      // Search can live in an offstage adaptive page stack.
                      // Request focus explicitly through Ctrl+K instead of
                      // stealing it while Home is opening.
                      autofocus: false,
                      onChanged: (value) => setState(() => query = value),
                      onSubmitted: (_) {
                        if (results.isNotEmpty) open(results.first);
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.bolt_rounded),
                        hintText: 'DBMS normalization, type:pdf, is:favorite…',
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
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
                            onTap: () =>
                                setState(() => kind = LibraryKind.book),
                          ),
                          _Filter(
                            label: 'Slides',
                            icon: Icons.slideshow_rounded,
                            selected: kind == LibraryKind.slides,
                            onTap: () =>
                                setState(() => kind = LibraryKind.slides),
                          ),
                          _Filter(
                            label: 'Video',
                            icon: Icons.movie_rounded,
                            selected: kind == LibraryKind.video,
                            onTap: () =>
                                setState(() => kind = LibraryKind.video),
                          ),
                          _Filter(
                            label: 'Audio',
                            icon: Icons.graphic_eq_rounded,
                            selected: kind == LibraryKind.audio,
                            onTap: () =>
                                setState(() => kind = LibraryKind.audio),
                          ),
                          _Filter(
                            label: 'Notes',
                            icon: Icons.edit_note_rounded,
                            selected: kind == LibraryKind.note,
                            onTap: () =>
                                setState(() => kind = LibraryKind.note),
                          ),
                          _Filter(
                            label: 'Docs',
                            icon: Icons.description_rounded,
                            selected: kind == LibraryKind.document,
                            onTap: () =>
                                setState(() => kind = LibraryKind.document),
                          ),
                          _Filter(
                            label: 'Starred',
                            icon: Icons.star_rounded,
                            selected: favoritesOnly,
                            onTap: () =>
                                setState(() => favoritesOnly = !favoritesOnly),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          '${results.length} result${results.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        if (query.isEmpty)
                          Flexible(
                            child: Text(
                              'Type to rank · Enter opens first',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (results.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 116),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: const EmptyCard(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matched',
                    subtitle: 'Try a shorter keyword, a path, or another material filter.',
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 116),
            sliver: SliverList.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final entry = results[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: StaggeredReveal(
                        index: index,
                        child: FileRow(
                          entry: entry,
                          showPath: true,
                          trailing: IconButton(
                            tooltip: widget.controller.isFavorite(entry.path)
                                ? 'Remove favorite'
                                : 'Add favorite',
                            onPressed: () =>
                                widget.controller.toggleFavorite(entry),
                            icon: Icon(
                              widget.controller.isFavorite(entry.path)
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                            ),
                          ),
                          onTap: () => open(entry),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
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
