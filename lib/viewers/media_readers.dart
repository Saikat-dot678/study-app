import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';

class StudyTextReader extends StatefulWidget {
  const StudyTextReader({super.key, required this.path, required this.markdown});

  final String path;
  final bool markdown;

  @override
  State<StudyTextReader> createState() => _StudyTextReaderState();
}

class _StudyTextReaderState extends State<StudyTextReader> {
  late final Future<String> text = File(widget.path).readAsString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: text,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? '';
        if (widget.markdown) {
          return Markdown(
            data: data,
            selectable: true,
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 100),
          );
        }
        return SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Text(
                  data,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.68),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StudyImageReader extends StatelessWidget {
  const StudyImageReader({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      alignment: Alignment.center,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 8,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 72),
        ),
      ),
    );
  }
}

class StudyAudioReader extends StatefulWidget {
  const StudyAudioReader({
    super.key,
    required this.path,
    required this.entry,
    required this.controller,
  });

  final String path;
  final LibraryEntry entry;
  final LibraryController controller;

  @override
  State<StudyAudioReader> createState() => _StudyAudioReaderState();
}

class _StudyAudioReaderState extends State<StudyAudioReader> {
  final player = AudioPlayer();
  StreamSubscription<Duration>? positionSubscription;
  Duration duration = Duration.zero;
  Duration lastSaved = Duration.zero;
  double speed = 1;
  Object? error;

  @override
  void initState() {
    super.initState();
    positionSubscription = player.positionStream.listen(_savePosition);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      duration = await player.setFilePath(widget.path) ?? Duration.zero;
      final saved = widget.controller.progressFor(widget.entry.path)?.position ?? Duration.zero;
      if (saved > Duration.zero && (duration == Duration.zero || saved < duration)) {
        await player.seek(saved);
      }
      if (mounted) setState(() {});
    } catch (value) {
      error = value;
      if (mounted) setState(() {});
    }
  }

  void _savePosition(Duration value) {
    if (duration <= Duration.zero || (value - lastSaved).abs() < const Duration(seconds: 5)) {
      return;
    }
    lastSaved = value;
    unawaited(
      widget.controller.saveProgress(
        widget.entry,
        position: value,
        duration: duration,
      ),
    );
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
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return const Center(child: Text('This audio codec is not supported by the device player.'));
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                      scheme.tertiaryContainer,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.20),
                      blurRadius: 52,
                    ),
                  ],
                ),
                child: Icon(Icons.graphic_eq_rounded, size: 94, color: scheme.primary),
              ),
              const SizedBox(height: 28),
              Text(
                widget.entry.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 25),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? player.position;
                  final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
                  return Column(
                    children: [
                      Slider(
                        min: 0,
                        max: maxMs.toDouble(),
                        value: position.inMilliseconds.clamp(0, maxMs).toDouble(),
                        onChanged: (value) => player.seek(Duration(milliseconds: value.round())),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text(studyDuration(position)), Text(studyDuration(duration))],
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
                    tooltip: 'Back 10 seconds',
                    onPressed: () {
                      final value = player.position - const Duration(seconds: 10);
                      player.seek(value.isNegative ? Duration.zero : value);
                    },
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  const SizedBox(width: 18),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(22),
                        ),
                        onPressed: () => playing ? player.pause() : player.play(),
                        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 34),
                      );
                    },
                  ),
                  const SizedBox(width: 18),
                  IconButton.filledTonal(
                    tooltip: 'Forward 10 seconds',
                    onPressed: () {
                      final value = player.position + const Duration(seconds: 10);
                      player.seek(value > duration ? duration : value);
                    },
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                children: [
                  for (final value in [0.75, 1.0, 1.25, 1.5, 2.0])
                    ChoiceChip(
                      label: Text('$value×'),
                      selected: speed == value,
                      onSelected: (_) async {
                        speed = value;
                        await player.setSpeed(value);
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudyVideoReader extends StatefulWidget {
  const StudyVideoReader({
    super.key,
    required this.uri,
    required this.entry,
    required this.libraryController,
  });

  final String uri;
  final LibraryEntry entry;
  final LibraryController libraryController;

  @override
  State<StudyVideoReader> createState() => _StudyVideoReaderState();
}

class _StudyVideoReaderState extends State<StudyVideoReader> {
  late final VideoPlayerController controller;
  Object? error;
  bool controlsVisible = true;
  Duration lastSaved = Duration.zero;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse(widget.uri);
    controller = uri.scheme == 'file'
        ? VideoPlayerController.file(File.fromUri(uri))
        : VideoPlayerController.contentUri(uri);
    controller.initialize().then((_) async {
      final saved = widget.libraryController.progressFor(widget.entry.path)?.position ?? Duration.zero;
      if (saved > Duration.zero && saved < controller.value.duration) {
        await controller.seekTo(saved);
      }
      controller.addListener(_onChanged);
      if (mounted) setState(() {});
    }).catchError((Object value) {
      error = value;
      if (mounted) setState(() {});
    });
  }

  void _onChanged() {
    final position = controller.value.position;
    if (controller.value.isInitialized && (position - lastSaved).abs() >= const Duration(seconds: 5)) {
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
    controller.removeListener(_onChanged);
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
      return const Center(child: Text('This video codec is not supported by the device player.'));
    }
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
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
                aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
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
                      colors: [Color(0x55000000), Color(0x00000000), Color(0xAA000000)],
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
                    padding: const EdgeInsets.all(23),
                  ),
                  onPressed: () => controller.value.isPlaying ? controller.pause() : controller.play(),
                  child: Icon(
                    controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 38,
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
                            '${studyDuration(controller.value.position)} / ${studyDuration(controller.value.duration)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Back 10 seconds',
                            onPressed: () {
                              final target = controller.value.position - const Duration(seconds: 10);
                              controller.seekTo(target.isNegative ? Duration.zero : target);
                            },
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Forward 10 seconds',
                            onPressed: () {
                              final target = controller.value.position + const Duration(seconds: 10);
                              controller.seekTo(
                                target > controller.value.duration ? controller.value.duration : target,
                              );
                            },
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                          ),
                          PopupMenuButton<double>(
                            tooltip: 'Playback speed',
                            color: Theme.of(context).colorScheme.surface,
                            icon: const Icon(Icons.speed_rounded, color: Colors.white),
                            onSelected: controller.setPlaybackSpeed,
                            itemBuilder: (_) => [
                              for (final speed in [0.75, 1.0, 1.25, 1.5, 2.0])
                                PopupMenuItem(value: speed, child: Text('$speed×')),
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

String studyDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${value.inMinutes}:$seconds';
}
