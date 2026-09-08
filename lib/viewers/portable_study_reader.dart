import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../workspace/study_workspace_controller.dart';
import '../ui/premium_components.dart';
import 'document_extractor.dart';

class PortableStudyReader extends StatefulWidget {
  const PortableStudyReader({
    super.key,
    required this.path,
    required this.entry,
    required this.controller,
    required this.onExternal,
  });

  final String path;
  final LibraryEntry entry;
  final LibraryController controller;
  final VoidCallback onExternal;

  @override
  State<PortableStudyReader> createState() => _PortableStudyReaderState();
}

class _PortableStudyReaderState extends State<PortableStudyReader> {
  final workspace = StudyWorkspaceController.instance;
  late final Future<ExtractedDocument> document = extractPortableDocument(
    widget.path,
    widget.entry.extension,
  );
  int currentSection = 0;
  bool showNotes = false;

  bool get isSlides => widget.entry.kind == LibraryKind.slides;
  bool get isBook => widget.entry.kind == LibraryKind.book;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExtractedDocument>(
      future: document,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return _PortableFallback(
            entry: widget.entry,
            onExternal: widget.onExternal,
          );
        }
        final sections = snapshot.data!.sections
            .where((section) => section.body.trim().isNotEmpty)
            .toList();
        if (sections.isEmpty) {
          return _PortableFallback(
            entry: widget.entry,
            onExternal: widget.onExternal,
          );
        }
        currentSection = currentSection.clamp(0, sections.length - 1);
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 980;
        final rail = wide
            ? SizedBox(
                width: 220,
                child: _SectionRail(
                  sections: sections,
                  current: currentSection,
                  isSlides: isSlides,
                  onSelected: _goTo,
                ),
              )
            : null;
        final noteRail = wide && showNotes
            ? SizedBox(
                width: 310,
                child: _PortableNotesRail(
                  workspace: workspace,
                  path: widget.entry.path,
                  currentPage: currentSection + 1,
                  onPage: (page) => _goTo(page - 1),
                ),
              )
            : null;
        return AnimatedBuilder(
          animation: workspace,
          builder: (context, _) => Column(
            children: [
              _PortableToolbar(
                current: currentSection + 1,
                count: sections.length,
                isSlides: isSlides,
                isBook: isBook,
                notes: workspace.annotationCount(widget.entry.path),
                onPrevious: currentSection > 0
                    ? () => _goTo(currentSection - 1)
                    : null,
                onNext: currentSection < sections.length - 1
                    ? () => _goTo(currentSection + 1)
                    : null,
                onJump: () => _jumpDialog(sections.length),
                onNavigator: wide ? null : () => _showMobileSections(sections),
                onNote: () => _addNote(sections[currentSection]),
                onKeyPoint: () => _addKeyPoint(sections[currentSection]),
                onNotes: () {
                  if (wide) {
                    setState(() => showNotes = !showNotes);
                  } else {
                    _showMobileNotes();
                  }
                },
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?rail,
                    Expanded(
                      child: _SectionCanvas(
                        key: ValueKey('${widget.entry.path}:$currentSection'),
                        section: sections[currentSection],
                        page: currentSection + 1,
                        count: sections.length,
                        isSlides: isSlides,
                        isBook: isBook,
                      ),
                    ),
                    ?noteRail,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goTo(int index) {
    if (!mounted) return;
    setState(() => currentSection = index);
    unawaited(widget.controller.saveProgress(widget.entry, page: index + 1));
  }

  Future<void> _jumpDialog(int count) async {
    final field = TextEditingController(text: '${currentSection + 1}');
    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isSlides ? 'Jump to slide' : 'Jump to section'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1–$count',
            suffixText: '/ $count',
          ),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, int.tryParse(field.text.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(field.text.trim())),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    field.dispose();
    if (page != null) _goTo((page - 1).clamp(0, count - 1));
  }

  Future<void> _addNote(ExtractedSection section) async {
    final field = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${isSlides ? 'Slide' : 'Section'} ${currentSection + 1} note',
        ),
        content: SizedBox(
          width: 470,
          child: TextField(
            controller: field,
            autofocus: true,
            minLines: 4,
            maxLines: 9,
            decoration: const InputDecoration(
              hintText: 'Add your explanation, question, summary, or reminder…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
            icon: const Icon(Icons.note_add_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (note == null || note.isEmpty) return;
    await workspace.addPageNote(
      path: widget.entry.path,
      page: currentSection + 1,
      note: note,
    );
    if (mounted) setState(() => showNotes = true);
  }

  Future<void> _addKeyPoint(ExtractedSection section) async {
    final field = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Mark key point • ${isSlides ? 'slide' : 'section'} ${currentSection + 1}',
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste or type the important line. It will be saved beside this ${isSlides ? 'slide' : 'section'} for revision.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: field,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Important definition, formula, or idea…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
            icon: const Icon(Icons.bookmark_add_rounded),
            label: const Text('Save key point'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value == null || value.isEmpty) return;
    await workspace.addPageNote(
      path: widget.entry.path,
      page: currentSection + 1,
      note: 'Key point',
      selectedText: value,
    );
    if (mounted) setState(() => showNotes = true);
  }

  Future<void> _showMobileSections(List<ExtractedSection> sections) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.78,
        child: _SectionRail(
          sections: sections,
          current: currentSection,
          isSlides: isSlides,
          grid: true,
          onSelected: (index) {
            Navigator.pop(sheetContext);
            _goTo(index);
          },
        ),
      ),
    );
  }

  Future<void> _showMobileNotes() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.78,
        child: _PortableNotesRail(
          workspace: workspace,
          path: widget.entry.path,
          currentPage: currentSection + 1,
          onPage: (page) {
            Navigator.pop(sheetContext);
            _goTo(page - 1);
          },
        ),
      ),
    );
  }
}

class _PortableToolbar extends StatelessWidget {
  const _PortableToolbar({
    required this.current,
    required this.count,
    required this.isSlides,
    required this.isBook,
    required this.notes,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
    required this.onNavigator,
    required this.onNote,
    required this.onKeyPoint,
    required this.onNotes,
  });

  final int current;
  final int count;
  final bool isSlides;
  final bool isBook;
  final int notes;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onJump;
  final VoidCallback? onNavigator;
  final VoidCallback onNote;
  final VoidCallback onKeyPoint;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final unit = isSlides
        ? 'Slide'
        : isBook
        ? 'Chapter'
        : 'Section';
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            if (onNavigator != null)
              IconButton.filledTonal(
                tooltip: '$unit navigator',
                onPressed: onNavigator,
                icon: const Icon(Icons.view_sidebar_rounded),
              ),
            if (onNavigator != null) const SizedBox(width: 5),
            IconButton(
              tooltip: 'Previous $unit',
              onPressed: onPrevious,
              icon: const Icon(Icons.keyboard_arrow_left_rounded),
            ),
            Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onJump,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  child: Text(
                    '$current / $count',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next $unit',
              onPressed: onNext,
              icon: const Icon(Icons.keyboard_arrow_right_rounded),
            ),
            const Spacer(),
            if (!compact)
              Text(
                isSlides
                    ? 'Offline slide study view • exact layout opens externally'
                    : 'Offline structured reading view',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (!compact) const SizedBox(width: 8),
            IconButton(
              tooltip: 'Mark key point',
              onPressed: onKeyPoint,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
            IconButton(
              tooltip: 'Add note',
              onPressed: onNote,
              icon: const Icon(Icons.note_add_outlined),
            ),
            Badge(
              isLabelVisible: notes > 0,
              label: Text('$notes'),
              child: IconButton.filledTonal(
                tooltip: 'Study notes',
                onPressed: onNotes,
                icon: const Icon(Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.sections,
    required this.current,
    required this.isSlides,
    required this.onSelected,
    this.grid = false,
  });

  final List<ExtractedSection> sections;
  final int current;
  final bool isSlides;
  final ValueChanged<int> onSelected;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card(int index) {
      final section = sections[index];
      final active = index == current;
      return Material(
        color: active
            ? scheme.primary.withValues(alpha: 0.11)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(index),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? scheme.primary.withValues(alpha: 0.13)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: active
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isSlides)
                      Icon(
                        Icons.slideshow_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  section.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    section.body.replaceAll('\n', ' '),
                    maxLines: grid ? 5 : 7,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.86),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: grid
            ? GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 1.05,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: sections.length,
                itemBuilder: (_, index) => card(index),
              )
            : ListView.separated(
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) =>
                    SizedBox(height: 150, child: card(index)),
              ),
      ),
    );
  }
}

class _SectionCanvas extends StatelessWidget {
  const _SectionCanvas({
    super.key,
    required this.section,
    required this.page,
    required this.count,
    required this.isSlides,
    required this.isBook,
  });

  final ExtractedSection section;
  final int page;
  final int count;
  final bool isSlides;
  final bool isBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          width > 720 ? 34 : 18,
          22,
          width > 720 ? 34 : 18,
          100,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isSlides ? 980 : 880),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isSlides
                  ? _SlideCanvas(section: section, page: page, count: count)
                  : _ReadingCanvas(
                      section: section,
                      page: page,
                      count: count,
                      isBook: isBook,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideCanvas extends StatelessWidget {
  const _SlideCanvas({
    required this.section,
    required this.page,
    required this.count,
  });
  final ExtractedSection section;
  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      key: ValueKey(page),
      aspectRatio: 16 / 10,
      child: GradientBorderCard(
        padding: const EdgeInsets.all(28),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const EyebrowLabel(
                    icon: Icons.slideshow_rounded,
                    text: 'Slide study view',
                  ),
                  const Spacer(),
                  Text(
                    '$page / $count',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                section.title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    section.body,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(height: 1.62, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Study renders readable PPTX/ODP content offline. Use “Open in another app” for the original PowerPoint layout, animations, charts and embedded media.',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingCanvas extends StatelessWidget {
  const _ReadingCanvas({
    required this.section,
    required this.page,
    required this.count,
    required this.isBook,
  });
  final ExtractedSection section;
  final int page;
  final int count;
  final bool isBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SelectionArea(
      key: ValueKey(page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyebrowLabel(
            icon: isBook
                ? Icons.auto_stories_rounded
                : Icons.description_rounded,
            text: '${isBook ? 'Chapter' : 'Section'} $page of $count',
          ),
          const SizedBox(height: 18),
          Text(
            section.title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.72,
              color: scheme.onSurface.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortableNotesRail extends StatelessWidget {
  const _PortableNotesRail({
    required this.workspace,
    required this.path,
    required this.currentPage,
    required this.onPage,
  });

  final StudyWorkspaceController workspace;
  final String path;
  final int currentPage;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = workspace.annotationsFor(path);
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 10, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Study notes',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Text(
                  '${values.length}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: values.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Add a note or key point while reading. Notes stay attached to their slide or section.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: values.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = values[index];
                      return Material(
                        color: item.page == currentPage
                            ? scheme.primary.withValues(alpha: 0.09)
                            : scheme.surfaceContainerHigh.withValues(
                                alpha: 0.48,
                              ),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onPage(item.page),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 5, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Page ${item.page}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (item.text.isNotEmpty) ...[
                                        Text(
                                          item.text,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        item.note,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      workspace.deleteAnnotation(item.id);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PortableFallback extends StatelessWidget {
  const _PortableFallback({required this.entry, required this.onExternal});
  final LibraryEntry entry;
  final VoidCallback onExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 68),
              const SizedBox(height: 16),
              Text(
                'Preview unavailable',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'The file is safe in your library, but its readable content could not be extracted offline.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onExternal,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open in another app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
