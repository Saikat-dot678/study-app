import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../workspace/study_workspace_controller.dart';

class AdvancedPdfReader extends StatefulWidget {
  const AdvancedPdfReader({
    super.key,
    required this.path,
    required this.entry,
    required this.libraryController,
  });

  final String path;
  final LibraryEntry entry;
  final LibraryController libraryController;

  @override
  State<AdvancedPdfReader> createState() => _AdvancedPdfReaderState();
}

class _AdvancedPdfReaderState extends State<AdvancedPdfReader> {
  final viewerController = PdfViewerController();
  final workspace = StudyWorkspaceController.instance;
  PdfDocument? document;
  int currentPage = 1;
  int pageCount = 0;
  bool showThumbnails = false;
  bool showAnnotations = false;

  @override
  void initState() {
    super.initState();
    final progress = widget.libraryController.progressFor(widget.entry.path);
    currentPage = (progress?.page ?? 1).clamp(1, 1000000);
  }

  Future<void> _goToPage(int page) async {
    if (pageCount <= 0) return;
    final value = page.clamp(1, pageCount);
    await viewerController.goToPage(
      pageNumber: value,
      anchor: PdfPageAnchor.top,
    );
  }

  Future<void> _jumpDialog() async {
    final field = TextEditingController(text: '$currentPage');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Jump to page'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1–$pageCount',
            suffixText: '/ $pageCount',
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
    if (value != null) await _goToPage(value);
  }

  Future<void> _addPageNote({String selectedText = ''}) async {
    final field = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Note on page $currentPage'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedText.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedText.trim(),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: field,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Write an explanation, doubt, formula, or reminder…',
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
            icon: const Icon(Icons.note_add_rounded),
            label: const Text('Save note'),
          ),
        ],
      ),
    );
    field.dispose();
    if (note == null || note.trim().isEmpty) return;
    await workspace.addPageNote(
      path: widget.entry.path,
      page: currentPage,
      note: note,
      selectedText: selectedText,
    );
    if (mounted) {
      setState(() => showAnnotations = true);
      viewerController.invalidate();
    }
  }

  Future<void> _highlightSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
    if (ranges.isEmpty) return;
    for (final range in ranges) {
      final rects = <DocumentRect>[];
      for (final fragment in range.enumerateFragmentBoundingRects()) {
        final bounds = fragment.bounds;
        rects.add(
          DocumentRect(
            x: bounds.left,
            y: bounds.top,
            width: bounds.width,
            height: bounds.height,
          ),
        );
      }
      await workspace.addHighlight(
        path: widget.entry.path,
        page: range.pageNumber,
        text: range.text,
        rects: rects,
      );
    }
    await params.textSelectionDelegate.clearTextSelection();
    params.dismissContextMenu();
    if (mounted) setState(() {});
    viewerController.invalidate();
  }

  Future<void> _noteSelection(PdfViewerContextMenuBuilderParams params) async {
    final text = await params.textSelectionDelegate.getSelectedText();
    final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
    if (ranges.isNotEmpty && mounted) {
      setState(() => currentPage = ranges.first.pageNumber);
    }
    params.dismissContextMenu();
    await params.textSelectionDelegate.clearTextSelection();
    if (mounted) await _addPageNote(selectedText: text);
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final annotations = workspace
        .annotationsFor(widget.entry.path, page: page.pageNumber)
        .where((item) => item.kind == DocumentAnnotationKind.highlight);
    for (final annotation in annotations) {
      final paint = Paint()
        ..color = Color(annotation.colorValue).withValues(alpha: 0.30)
        ..style = PaintingStyle.fill;
      for (final item in annotation.rects) {
        final pdfRect = PdfRect(
          item.x,
          item.y,
          item.x + item.width,
          item.y - item.height,
        );
        final rect = pdfRect.toRectInDocument(page: page, pageRect: pageRect);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(0.8),
            const Radius.circular(2.5),
          ),
          paint,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: workspace,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 980;
        final thumbnailRail = showThumbnails && wide
            ? SizedBox(
                width: 168,
                child: _ThumbnailRail(
                  document: document,
                  currentPage: currentPage,
                  pageCount: pageCount,
                  onPage: _goToPage,
                ),
              )
            : null;
        final annotationRail = showAnnotations && wide
            ? SizedBox(
                width: 310,
                child: _AnnotationRail(
                  workspace: workspace,
                  path: widget.entry.path,
                  currentPage: currentPage,
                  onPage: _goToPage,
                ),
              )
            : null;
        return Column(
          children: [
            _PdfToolbar(
              page: currentPage,
              pageCount: pageCount,
              annotations: workspace.annotationCount(widget.entry.path),
              thumbnailsActive: showThumbnails,
              annotationsActive: showAnnotations,
              onPrevious: currentPage > 1
                  ? () => _goToPage(currentPage - 1)
                  : null,
              onNext: currentPage < pageCount
                  ? () => _goToPage(currentPage + 1)
                  : null,
              onJump: pageCount > 0 ? _jumpDialog : null,
              onToggleThumbnails: () {
                if (!wide) {
                  _showMobileThumbnails();
                } else {
                  setState(() => showThumbnails = !showThumbnails);
                }
              },
              onToggleAnnotations: () {
                if (!wide) {
                  _showMobileAnnotations();
                } else {
                  setState(() => showAnnotations = !showAnnotations);
                }
              },
              onAddNote: _addPageNote,
              onZoomIn: () => viewerController.zoomUp(loop: false),
              onZoomOut: () => viewerController.zoomDown(loop: false),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?thumbnailRail,
                  Expanded(
                    child: PdfViewer.file(
                      widget.path,
                      key: ValueKey(widget.path),
                      controller: viewerController,
                      initialPageNumber: currentPage,
                      params: PdfViewerParams(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        onViewerReady: (pdf, _) {
                          document = pdf;
                          pageCount = pdf.pages.length;
                          currentPage = currentPage.clamp(1, pageCount);
                          if (mounted) setState(() {});
                        },
                        onPageChanged: (page) {
                          if (page == null) return;
                          setState(() => currentPage = page);
                          unawaited(
                            widget.libraryController.saveProgress(
                              widget.entry,
                              page: page,
                              pageCount: pageCount,
                            ),
                          );
                        },
                        customizeContextMenuItems: (params, items) {
                          if (!params.textSelectionDelegate.hasSelectedText) {
                            return;
                          }
                          items.add(
                            ContextMenuButtonItem(
                              label: 'Highlight',
                              onPressed: () =>
                                  unawaited(_highlightSelection(params)),
                            ),
                          );
                          items.add(
                            ContextMenuButtonItem(
                              label: 'Add note',
                              onPressed: () =>
                                  unawaited(_noteSelection(params)),
                            ),
                          );
                        },
                        pagePaintCallbacks: [_paintHighlights],
                        pageOverlaysBuilder: (context, pageRect, page) {
                          final notes = workspace
                              .annotationsFor(
                                widget.entry.path,
                                page: page.pageNumber,
                              )
                              .where(
                                (item) =>
                                    item.kind == DocumentAnnotationKind.note,
                              )
                              .length;
                          if (notes == 0) return const [];
                          return [
                            Positioned(
                              right: 8,
                              top: 8,
                              child: PdfOverlayInteractionRegion(
                                onTap: (_) {
                                  setState(() {
                                    currentPage = page.pageNumber;
                                    showAnnotations = true;
                                  });
                                  return true;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.90),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sticky_note_2_rounded,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$notes',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ];
                        },
                        pageDropShadow: const BoxShadow(
                          blurRadius: 12,
                          color: Color(0x33000000),
                        ),
                      ),
                    ),
                  ),
                  ?annotationRail,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMobileThumbnails() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _ThumbnailRail(
          document: document,
          currentPage: currentPage,
          pageCount: pageCount,
          grid: true,
          onPage: (page) {
            Navigator.pop(context);
            _goToPage(page);
          },
        ),
      ),
    );
  }

  Future<void> _showMobileAnnotations() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: _AnnotationRail(
          workspace: workspace,
          path: widget.entry.path,
          currentPage: currentPage,
          onPage: (page) {
            Navigator.pop(context);
            _goToPage(page);
          },
        ),
      ),
    );
  }
}

class _PdfToolbar extends StatelessWidget {
  const _PdfToolbar({
    required this.page,
    required this.pageCount,
    required this.annotations,
    required this.thumbnailsActive,
    required this.annotationsActive,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
    required this.onToggleThumbnails,
    required this.onToggleAnnotations,
    required this.onAddNote,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final int page;
  final int pageCount;
  final int annotations;
  final bool thumbnailsActive;
  final bool annotationsActive;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onJump;
  final VoidCallback onToggleThumbnails;
  final VoidCallback onToggleAnnotations;
  final VoidCallback onAddNote;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Page thumbnails',
              onPressed: onToggleThumbnails,
              icon: Icon(
                thumbnailsActive
                    ? Icons.view_sidebar_rounded
                    : Icons.grid_view_rounded,
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Previous page',
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
                    '$page / ${pageCount == 0 ? '…' : pageCount}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: onNext,
              icon: const Icon(Icons.keyboard_arrow_right_rounded),
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Zoom out',
                onPressed: onZoomOut,
                icon: const Icon(Icons.zoom_out_rounded),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: onZoomIn,
                icon: const Icon(Icons.zoom_in_rounded),
              ),
            ],
            const Spacer(),
            if (!compact)
              Text(
                'Select text → Highlight / Add note',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (!compact) const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add page note',
              onPressed: onAddNote,
              icon: const Icon(Icons.note_add_outlined),
            ),
            Badge(
              isLabelVisible: annotations > 0,
              label: Text('$annotations'),
              child: IconButton.filledTonal(
                tooltip: 'Annotations',
                onPressed: onToggleAnnotations,
                icon: Icon(
                  annotationsActive
                      ? Icons.edit_note_rounded
                      : Icons.edit_note_outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailRail extends StatelessWidget {
  const _ThumbnailRail({
    required this.document,
    required this.currentPage,
    required this.pageCount,
    required this.onPage,
    this.grid = false,
  });

  final PdfDocument? document;
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPage;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (pageCount == 0 || document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    Widget builder(BuildContext context, int index) {
      final page = index + 1;
      final selected = page == currentPage;
      return InkWell(
        onTap: () => onPage(page),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: PdfPageView(
                    document: document,
                    pageNumber: page,
                    maximumDpi: 90,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$page',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: grid
            ? GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: pageCount,
                itemBuilder: builder,
              )
            : ListView.separated(
                itemCount: pageCount,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    SizedBox(height: 190, child: builder(context, index)),
              ),
      ),
    );
  }
}

class _AnnotationRail extends StatelessWidget {
  const _AnnotationRail({
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
                    'Annotations',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Text(
                  '${values.length}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
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
                        'Select PDF text and choose Highlight or Add note. Page notes also appear here.',
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
                      return _AnnotationCard(
                        annotation: item,
                        active: item.page == currentPage,
                        onTap: () => onPage(item.page),
                        onDelete: () => workspace.deleteAnnotation(item.id),
                        onEdit: item.kind == DocumentAnnotationKind.note
                            ? () => _editNote(context, item)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context, DocumentAnnotation item) async {
    final field = TextEditingController(text: item.note);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit page ${item.page} note'),
        content: TextField(
          controller: field,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null) await workspace.updateAnnotationNote(item.id, value);
  }
}

class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({
    required this.annotation,
    required this.active,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
  });

  final DocumentAnnotation annotation;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHighlight = annotation.kind == DocumentAnnotationKind.highlight;
    return Material(
      color: active
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.surfaceContainerHigh.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 5, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 36,
                decoration: BoxDecoration(
                  color: isHighlight
                      ? Color(annotation.colorValue)
                      : scheme.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHighlight
                          ? 'Highlight • page ${annotation.page}'
                          : 'Note • page ${annotation.page}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHighlight
                          ? (annotation.text.isEmpty
                                ? 'Highlighted text'
                                : annotation.text)
                          : annotation.note,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (!isHighlight && annotation.text.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '“${annotation.text}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit note'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
