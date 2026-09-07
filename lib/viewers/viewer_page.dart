import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../ui/library_widgets.dart';
import 'document_extractor.dart';

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
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) =>
          StudyViewerPage(controller: controller, entry: entry),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0.02),
              end: Offset.zero,
            ).animate(curved),
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
  String? localPath;
  String? contentUri;
  Object? loadError;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
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
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 10,
        leading: Padding(
          padding: const EdgeInsets.all(7),
          child: IconButton.filledTonal(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        title: Row(
          children: [
            FileIcon(
              entry: widget.entry,
              heroTag: 'entry:${widget.entry.path}',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    fileMeta(widget.entry),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
          PopupMenuButton<_ViewerAction>(
            onSelected: (action) {
              if (action == _ViewerAction.external) {
                widget.controller.openExternally(widget.entry);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ViewerAction.external,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.open_in_new_rounded),
                  title: Text('Open in another app'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: loading
            ? const _ViewerLoading()
            : loadError != null
            ? _ViewerFallback(
                entry: widget.entry,
                message: 'This material could not be prepared for the in-app viewer.',
                onExternal: () =>
                    widget.controller.openExternally(widget.entry),
              )
            : _viewerForEntry(),
      ),
    );
  }

  Widget _viewerForEntry() {
    final entry = widget.entry;
    if (!entry.canPreviewInApp) {
      return _ViewerFallback(
        entry: entry,
        message: 'This legacy or uncommon format is kept safely in your library, but needs another installed app to render it.',
        onExternal: () => widget.controller.openExternally(entry),
      );
    }

    return switch (entry.kind) {
      LibraryKind.pdf => _PdfReader(
        path: localPath!,
        controller: widget.controller,
        entry: entry,
      ),
      LibraryKind.note => _TextReader(
        path: localPath!,
        markdown: {'md', 'markdown'}.contains(entry.extension),
      ),
      LibraryKind.image => _ImageReader(path: localPath!),
      LibraryKind.audio => _AudioReader(
        path: localPath!,
        entry: entry,
        controller: widget.controller,
      ),
      LibraryKind.video => _VideoReader(
        uri: contentUri!,
        entry: entry,
        libraryController: widget.controller,
      ),
      LibraryKind.book ||
      LibraryKind.slides ||
      LibraryKind.document ||
      LibraryKind.spreadsheet => _PortableDocumentReader(
        path: localPath!,
        entry: entry,
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

enum _ViewerAction { external }

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
          const SizedBox(height: 16),
          Text(
            'Preparing locally…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PdfReader extends StatelessWidget {
  const _PdfReader({
    required this.path,
    required this.controller,
    required this.entry,
  });

  final String path;
  final LibraryController controller;
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final progress = controller.progressFor(entry.path);
    var pageCount = progress?.pageCount ?? 0;
    return PdfViewer.file(
      path,
      key: ValueKey(path),
      initialPageNumber: (progress?.page ?? 1).clamp(1, 1000000),
      params: PdfViewerParams(
        onViewerReady: (document, _) => pageCount = document.pages.length,
        onPageChanged: (page) {
          if (page != null) {
            unawaited(
              controller.saveProgress(entry, page: page, pageCount: pageCount),
            );
          }
        },
        pageDropShadow: const BoxShadow(
          blurRadius: 8,
          color: Color(0x22000000),
        ),
      ),
    );
  }
}

class _TextReader extends StatefulWidget {
  const _TextReader({required this.path, required this.markdown});

  final String path;
  final bool markdown;

  @override
  State<_TextReader> createState() => _TextReaderState();
}

class _TextReaderState extends State<_TextReader> {
  late final Future<String> text = File(widget.path).readAsString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: text,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _ViewerLoading();
        final data = snapshot.data ?? '';
        if (widget.markdown) {
          return Markdown(
            data: data,
            selectable: true,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 80),
          );
        }
        return SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 80),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  data,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(height: 1.65),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImageReader extends StatelessWidget {
  const _ImageReader({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      alignment: Alignment.center,
      child: InteractiveViewer(
        minScale: 0.7,
        maxScale: 6,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image_outlined, size: 64),
        ),
      ),
    );
  }
}

class _AudioReader extends StatefulWidget {
  const _AudioReader({
    required this.path,
    required this.entry,
    required this.controller,
  });

  final String path;
  final LibraryEntry entry;
  final LibraryController controller;

  @override
  State<_AudioReader> createState() => _AudioReaderState();
}

class _AudioReaderState extends State<_AudioReader> {
  final AudioPlayer player = AudioPlayer();
  Duration duration = Duration.zero;
  double speed = 1;
  Object? error;
  StreamSubscription<Duration>? positionSubscription;
  Duration lastSaved = Duration.zero;

  @override
  void initState() {
    super.initState();
    positionSubscription = player.positionStream.listen(_savePosition);
    _load();
  }

  Future<void> _load() async {
    try {
      duration = await player.setFilePath(widget.path) ?? Duration.zero;
      final saved =
          widget.controller.progressFor(widget.entry.path)?.position ??
          Duration.zero;
      if (saved > Duration.zero && saved < duration) await player.seek(saved);
      if (mounted) setState(() {});
    } catch (value) {
      error = value;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    unawaited(positionSubscription?.cancel());
    if (duration > Duration.zero) {
      unawaited(
        widget.controller.saveProgress(
          widget.entry,
          position: player.position,
          duration: duration,
        ),
      );
    }
    player.dispose();
    super.dispose();
  }

  void _savePosition(Duration position) {
    if ((position - lastSaved).abs() < const Duration(seconds: 5) ||
        duration <= Duration.zero) {
      return;
    }
    lastSaved = position;
    unawaited(
      widget.controller.saveProgress(
        widget.entry,
        position: position,
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return const Center(
        child: Text('This audio codec is not supported by the device player.'),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(42),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.18),
                      blurRadius: 42,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 92,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.entry.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 30),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final maxMs = duration.inMilliseconds <= 0
                      ? 1
                      : duration.inMilliseconds;
                  final value = position.inMilliseconds
                      .clamp(0, maxMs)
                      .toDouble();
                  return Column(
                    children: [
                      Slider(
                        min: 0,
                        max: maxMs.toDouble(),
                        value: value,
                        onChanged: (value) =>
                            player.seek(Duration(milliseconds: value.round())),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_time(position)),
                            Text(_time(duration)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed: () async {
                      final target =
                          player.position - const Duration(seconds: 10);
                      await player.seek(
                        target.isNegative ? Duration.zero : target,
                      );
                    },
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  const SizedBox(width: 20),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(22),
                        ),
                        onPressed: () =>
                            playing ? player.pause() : player.play(),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton.filledTonal(
                    iconSize: 28,
                    onPressed: () => player.seek(
                      player.position + const Duration(seconds: 10),
                    ),
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.75, label: Text('0.75×')),
                  ButtonSegment(value: 1.0, label: Text('1×')),
                  ButtonSegment(value: 1.25, label: Text('1.25×')),
                  ButtonSegment(value: 1.5, label: Text('1.5×')),
                  ButtonSegment(value: 2.0, label: Text('2×')),
                ],
                selected: {speed},
                showSelectedIcon: false,
                onSelectionChanged: (values) async {
                  speed = values.first;
                  await player.setSpeed(speed);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoReader extends StatefulWidget {
  const _VideoReader({
    required this.uri,
    required this.entry,
    required this.libraryController,
  });

  final String uri;
  final LibraryEntry entry;
  final LibraryController libraryController;

  @override
  State<_VideoReader> createState() => _VideoReaderState();
}

class _VideoReaderState extends State<_VideoReader> {
  late final VideoPlayerController controller;
  bool controlsVisible = true;
  Object? error;
  Duration lastSaved = Duration.zero;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.contentUri(Uri.parse(widget.uri));
    controller
        .initialize()
        .then((_) async {
          final saved =
              widget.libraryController
                  .progressFor(widget.entry.path)
                  ?.position ??
              Duration.zero;
          if (saved > Duration.zero && saved < controller.value.duration) {
            await controller.seekTo(saved);
          }
          controller.addListener(_onPlayerChanged);
          if (mounted) setState(() {});
        })
        .catchError((Object value) {
          error = value;
          if (mounted) setState(() {});
        });
  }

  void _onPlayerChanged() {
    final position = controller.value.position;
    if ((position - lastSaved).abs() >= const Duration(seconds: 5)) {
      lastSaved = position;
      unawaited(
        widget.libraryController.saveProgress(
          widget.entry,
          position: position,
          duration: controller.value.duration,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onPlayerChanged);
    if (controller.value.isInitialized) {
      unawaited(
        widget.libraryController.saveProgress(
          widget.entry,
          position: controller.value.position,
          duration: controller.value.duration,
        ),
      );
    }
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return const Center(
        child: Text('This video codec is not supported by the device player.'),
      );
    }
    if (!controller.value.isInitialized) return const _ViewerLoading();

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => controlsVisible = !controlsVisible),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x44000000),
                        Color(0x00000000),
                        Color(0x99000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(22),
                  ),
                  onPressed: () => controller.value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                  child: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 36,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !controlsVisible,
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Color(0x66FFFFFF),
                          backgroundColor: Color(0x33FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _time(controller.value.position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Text(
                            ' / ',
                            style: TextStyle(color: Colors.white54),
                          ),
                          Text(
                            _time(controller.value.duration),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          PopupMenuButton<double>(
                            tooltip: 'Playback speed',
                            color: Theme.of(context).colorScheme.surface,
                            icon: const Icon(
                              Icons.speed_rounded,
                              color: Colors.white,
                            ),
                            onSelected: controller.setPlaybackSpeed,
                            itemBuilder: (_) => [
                              for (final speed in [0.75, 1.0, 1.25, 1.5, 2.0])
                                PopupMenuItem(
                                  value: speed,
                                  child: Text('$speed×'),
                                ),
                            ],
                          ),
                        ],
                      ),
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
}

class _PortableDocumentReader extends StatefulWidget {
  const _PortableDocumentReader({
    required this.path,
    required this.entry,
    required this.onExternal,
  });

  final String path;
  final LibraryEntry entry;
  final VoidCallback onExternal;

  @override
  State<_PortableDocumentReader> createState() =>
      _PortableDocumentReaderState();
}

class _PortableDocumentReaderState extends State<_PortableDocumentReader> {
  late final Future<ExtractedDocument> document = extractPortableDocument(
    widget.path,
    widget.entry.extension,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExtractedDocument>(
      future: document,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ViewerLoading();
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return _ViewerFallback(
            entry: widget.entry,
            message: 'The file is valid, but its readable content could not be extracted offline.',
            onExternal: widget.onExternal,
          );
        }
        final sections = snapshot.data!.sections
            .where((section) => section.body.trim().isNotEmpty)
            .toList();
        return SelectionArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final section = sections[index];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            section.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
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
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FileIcon(entry: entry, large: true),
              const SizedBox(height: 18),
              Text(
                'Still in your library',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
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

String _time(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${value.inMinutes}:$seconds';
}
