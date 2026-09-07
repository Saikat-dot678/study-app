import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import 'motion.dart';

class ConnectLibraryView extends StatelessWidget {
  const ConnectLibraryView({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 28),
        Icon(
          Icons.folder_copy_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Choose your study library folder',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'Everything stays locally inside one folder you choose. Copy that folder to another phone later and reconnect it there.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: controller.connectLibrary,
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('Choose or connect folder'),
        ),
        const SizedBox(height: 14),
        Text(
          'No account • no cloud • no all-files permission',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class FileIcon extends StatelessWidget {
  const FileIcon({
    super.key,
    required this.entry,
    this.large = false,
    this.heroTag,
  });

  final LibraryEntry entry;
  final bool large;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.kind) {
      LibraryKind.folder => Icons.folder_rounded,
      LibraryKind.pdf => Icons.picture_as_pdf_rounded,
      LibraryKind.book => Icons.auto_stories_rounded,
      LibraryKind.slides => Icons.slideshow_rounded,
      LibraryKind.spreadsheet => Icons.table_chart_rounded,
      LibraryKind.document => Icons.description_rounded,
      LibraryKind.note => Icons.edit_note_rounded,
      LibraryKind.audio => Icons.graphic_eq_rounded,
      LibraryKind.video => Icons.movie_rounded,
      LibraryKind.image => Icons.image_rounded,
      LibraryKind.archive => Icons.archive_rounded,
      LibraryKind.other => Icons.insert_drive_file_rounded,
    };
    final size = large ? 56.0 : 44.0;
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(large ? 18 : 14),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: large ? 31 : 23,
      ),
    );
    if (heroTag == null) return box;
    return Hero(
      tag: heroTag!,
      child: Material(type: MaterialType.transparency, child: box),
    );
  }
}

class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.showPath = false,
    this.trailing,
    this.selected = false,
    this.onSecondaryTapDown,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showPath;
  final Widget? trailing;
  final bool selected;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${entry.isDirectory ? 'Folder' : 'Material'} ${entry.name}',
      child: HoverLift(
        child: GestureDetector(
          onSecondaryTapDown: onSecondaryTapDown,
          child: Card(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.55)
                : null,
            child: ListTile(
              onTap: onTap,
              onLongPress: onLongPress,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 5,
              ),
              leading: FileIcon(
                entry: entry,
                heroTag: entry.isDirectory ? null : 'entry:${entry.path}',
              ),
              title: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                showPath ? entry.path : fileMeta(entry),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

String fileMeta(LibraryEntry entry) {
  if (entry.isDirectory) return 'Folder';
  final bytes = entry.size;
  final size = bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : bytes < 1024 * 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  return entry.extension.isEmpty
      ? size
      : '${entry.extension.toUpperCase()} • $size';
}
