import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../theme.dart';
import 'motion.dart';

class ConnectLibraryView extends StatelessWidget {
  const ConnectLibraryView({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StudyColors.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.07),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: palette.folder.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.folder_copy_rounded,
                                color: palette.folder,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Study Library',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Your library starts with a folder.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose an existing Study Library or create a new folder. Your files stay ordinary files that you control.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 18,
                          runSpacing: 12,
                          children: [
                            _LocalPromise(
                              icon: Icons.cloud_off_outlined,
                              color: palette.research,
                              label: 'No cloud required',
                            ),
                            _LocalPromise(
                              icon: Icons.person_off_outlined,
                              color: palette.exam,
                              label: 'No account',
                            ),
                            _LocalPromise(
                              icon: Icons.move_down_rounded,
                              color: palette.project,
                              label: 'Portable by design',
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        FilledButton.icon(
                          onPressed: controller.connectLibrary,
                          icon: const Icon(Icons.create_new_folder_rounded),
                          label: const Text('Choose or connect folder'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'On Android, Study uses the system folder picker. On desktop, it stores only the selected path.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalPromise extends StatelessWidget {
  const _LocalPromise({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class FileIcon extends StatelessWidget {
  const FileIcon({super.key, required this.entry, this.large = false});

  final LibraryEntry entry;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = StudyColors.of(context);
    final spec = switch (entry.kind) {
      LibraryKind.folder => (Icons.folder_rounded, palette.folder),
      LibraryKind.pdf => (Icons.picture_as_pdf_rounded, palette.pdf),
      LibraryKind.book => (Icons.auto_stories_rounded, palette.exam),
      LibraryKind.slides => (Icons.slideshow_rounded, palette.slides),
      LibraryKind.spreadsheet => (Icons.table_chart_rounded, palette.sheet),
      LibraryKind.document => (Icons.description_rounded, palette.document),
      LibraryKind.note => (Icons.edit_note_rounded, palette.note),
      LibraryKind.audio => (Icons.graphic_eq_rounded, palette.audio),
      LibraryKind.video => (Icons.movie_rounded, palette.video),
      LibraryKind.image => (Icons.image_rounded, palette.image),
      LibraryKind.archive => (Icons.archive_rounded, palette.project),
      LibraryKind.other => (Icons.insert_drive_file_rounded, palette.document),
    };
    final size = large ? 54.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: spec.$2.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(large ? 14 : 10),
        border: Border.all(color: spec.$2.withValues(alpha: 0.17)),
      ),
      child: Icon(spec.$1, color: spec.$2, size: large ? 29 : 22),
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${entry.isDirectory ? 'Folder' : 'Material'} ${entry.name}',
      child: HoverLift(
        child: GestureDetector(
          onSecondaryTapDown: onSecondaryTapDown,
          child: Material(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: BorderSide(
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: onTap,
              onLongPress: onLongPress,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 4,
              ),
              leading: FileIcon(entry: entry),
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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
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
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
