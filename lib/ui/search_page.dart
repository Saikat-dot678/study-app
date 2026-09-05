import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
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
  String query = '';
  LibraryKind? kind;

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.connected) {
      return ConnectLibraryView(controller: widget.controller);
    }

    final normalized = query.trim().toLowerCase();
    final results = widget.controller.allEntries.where((entry) {
      final textMatch = normalized.isEmpty ||
          entry.name.toLowerCase().contains(normalized) ||
          entry.path.toLowerCase().contains(normalized);
      return textMatch && (kind == null || entry.kind == kind);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search files, folders, notes…',
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Filter(label: 'All', selected: kind == null, onTap: () => setState(() => kind = null)),
              _Filter(label: 'PDF', selected: kind == LibraryKind.pdf, onTap: () => setState(() => kind = LibraryKind.pdf)),
              _Filter(label: 'Slides', selected: kind == LibraryKind.slides, onTap: () => setState(() => kind = LibraryKind.slides)),
              _Filter(label: 'Audio', selected: kind == LibraryKind.audio, onTap: () => setState(() => kind = LibraryKind.audio)),
              _Filter(label: 'Notes', selected: kind == LibraryKind.note, onTap: () => setState(() => kind = LibraryKind.note)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${results.length} result${results.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        ...results.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FileRow(
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
          ),
        ),
      ],
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
