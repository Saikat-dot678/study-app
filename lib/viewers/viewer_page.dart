import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../ui/library_widgets.dart';
import '../workspace/study_workspace_controller.dart';
import 'advanced_pdf_reader.dart';
import 'media_readers.dart';
import 'portable_study_reader.dart';

Future<void> openStudyViewer(
  BuildContext context,
  LibraryController controller,
  LibraryEntry entry,
) async {
  if (entry.isDirectory) {
    await controller.openFolder(entry.path);
    return;
  }
  unawaited(controller.recordOpened(entry));
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) =>
          StudyViewerPage(controller: controller, entry: entry),
      transitionsBuilder: (_, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0.012),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

class StudyViewerPage extends StatefulWidget {
  const StudyViewerPage({
    super.key,
    required this.controller,
    required this.entry,
  });

  final LibraryController controller;
  final LibraryEntry entry;

  @override
  State<StudyViewerPage> createState() => _StudyViewerPageState();
}

class _StudyViewerPageState extends State<StudyViewerPage> {
  final workspace = StudyWorkspaceController.instance;
  String? localPath;
  String? contentUri;
  Object? loadError;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(workspace.initialize());
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      if (widget.entry.kind == LibraryKind.video) {
        contentUri = await widget.controller.contentUri(widget.entry);
      } else if (widget.entry.canPreviewInApp) {
        localPath = await widget.controller.prepareForViewer(widget.entry);
      }
    } catch (error) {
      loadError = error;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: workspace,
      builder: (context, _) => Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.all(7),
            child: IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          titleSpacing: 8,
          title: Row(
            children: [
              FileIcon(entry: widget.entry),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _viewerSubtitle(widget.entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (workspace.annotationCount(widget.entry.path) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Chip(
                  avatar: const Icon(Icons.draw_rounded, size: 16),
                  label: Text(
                    '${workspace.annotationCount(widget.entry.path)}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            IconButton(
              tooltip: widget.controller.isFavorite(widget.entry.path)
                  ? 'Remove favorite'
                  : 'Add favorite',
              onPressed: () async {
                await widget.controller.toggleFavorite(widget.entry);
                if (mounted) setState(() {});
              },
              icon: Icon(
                widget.controller.isFavorite(widget.entry.path)
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: () => widget.controller.shareEntry(widget.entry),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'external') {
                  widget.controller.openExternally(widget.entry);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'external',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.open_in_new_rounded),
                    title: Text('Open original in another app'),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: loading
              ? const _ViewerLoading()
              : loadError != null
              ? _ViewerFallback(
                  entry: widget.entry,
                  message: 'This material could not be prepared for the offline study viewer.',
                  onExternal: () =>
                      widget.controller.openExternally(widget.entry),
                )
              : _reader(),
        ),
      ),
    );
  }

  Widget _reader() {
    final entry = widget.entry;
    if (!entry.canPreviewInApp) {
      return _ViewerFallback(
        entry: entry,
        message: 'This legacy or uncommon format is kept safely in your library, but needs another installed app for exact rendering.',
        onExternal: () => widget.controller.openExternally(entry),
      );
    }
    final preparedPath = localPath;
    final preparedUri = contentUri;
    if (entry.kind == LibraryKind.video) {
      if (preparedUri == null || preparedUri.trim().isEmpty) {
        return _ViewerFallback(
          entry: entry,
          message: 'The video could not be opened from its local library URI.',
          onExternal: () => widget.controller.openExternally(entry),
        );
      }
      return StudyVideoReader(
        uri: preparedUri,
        entry: entry,
        libraryController: widget.controller,
      );
    }
    if (preparedPath == null || preparedPath.trim().isEmpty) {
      return _ViewerFallback(
        entry: entry,
        message:
            'The material could not be prepared in the local reader cache.',
        onExternal: () => widget.controller.openExternally(entry),
      );
    }
    return switch (entry.kind) {
      LibraryKind.pdf => AdvancedPdfReader(
        path: preparedPath,
        entry: entry,
        libraryController: widget.controller,
      ),
      LibraryKind.note => StudyTextReader(
        path: preparedPath,
        markdown: {'md', 'markdown'}.contains(entry.extension),
      ),
      LibraryKind.image => StudyImageReader(path: preparedPath),
      LibraryKind.audio => StudyAudioReader(
        path: preparedPath,
        entry: entry,
        controller: widget.controller,
      ),
      LibraryKind.video => _ViewerFallback(
        entry: entry,
        message: 'The video reader is unavailable for this item.',
        onExternal: () => widget.controller.openExternally(entry),
      ),
      LibraryKind.book ||
      LibraryKind.slides ||
      LibraryKind.document ||
      LibraryKind.spreadsheet => PortableStudyReader(
        path: preparedPath,
        entry: entry,
        controller: widget.controller,
        onExternal: () => widget.controller.openExternally(entry),
      ),
      _ => _ViewerFallback(
        entry: entry,
        message: 'There is no built-in reader for this format yet.',
        onExternal: () => widget.controller.openExternally(entry),
      ),
    };
  }
}

class _ViewerLoading extends StatelessWidget {
  const _ViewerLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            'Preparing your study workspace…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ViewerFallback extends StatelessWidget {
  const _ViewerFallback({
    required this.entry,
    required this.message,
    required this.onExternal,
  });

  final LibraryEntry entry;
  final String message;
  final VoidCallback onExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('fallback'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FileIcon(entry: entry, large: true),
              const SizedBox(height: 18),
              Text(
                'Still in your library',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 22),
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

String _viewerSubtitle(LibraryEntry entry) => switch (entry.kind) {
  LibraryKind.pdf => 'PDF • pages, highlights, notes & navigation',
  LibraryKind.slides => 'Slides • navigator, key points & study notes',
  LibraryKind.book => 'Book • chapter navigation & study notes',
  LibraryKind.audio => 'Audio • resume, seek & playback speed',
  LibraryKind.video => 'Video • resume, seek & playback speed',
  LibraryKind.note => 'Note • selectable offline reading',
  LibraryKind.image => 'Image • pan & zoom',
  LibraryKind.document ||
  LibraryKind.spreadsheet => 'Document • structured offline reading',
  _ => fileMeta(entry),
};
