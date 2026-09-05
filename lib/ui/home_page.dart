import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import 'library_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.openLibrary,
    required this.openSearch,
  });

  final LibraryController controller;
  final ValueChanged<String?> openLibrary;
  final VoidCallback openSearch;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) return ConnectLibraryView(controller: controller);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 130),
        children: [
          _Appear(
            child: _SearchLauncher(onTap: openSearch),
          ),
          const SizedBox(height: 16),
          _Appear(
            delay: 70,
            child: _HeroCard(controller: controller),
          ),
          const SizedBox(height: 26),
          _Appear(
            delay: 110,
            child: SectionTitle(
              title: 'Quick access',
              action: 'Open library',
              onTap: () => openLibrary(null),
            ),
          ),
          const SizedBox(height: 12),
          _Appear(
            delay: 140,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width > 760 ? 6 : 2,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 1.52,
              children: [
                _QuickFolder(
                  label: 'Inbox',
                  caption: 'Shared & new',
                  icon: Icons.inbox_rounded,
                  onTap: () => openLibrary('Inbox'),
                ),
                _QuickFolder(
                  label: 'Notes',
                  caption: 'Text & docs',
                  icon: Icons.edit_note_rounded,
                  onTap: () => openLibrary('Notes'),
                ),
                _QuickFolder(
                  label: 'Books',
                  caption: 'PDF & EPUB',
                  icon: Icons.auto_stories_rounded,
                  onTap: () => openLibrary('Books'),
                ),
                _QuickFolder(
                  label: 'Slides',
                  caption: 'Presentations',
                  icon: Icons.slideshow_rounded,
                  onTap: () => openLibrary('Slides'),
                ),
                _QuickFolder(
                  label: 'Audio',
                  caption: 'Lectures',
                  icon: Icons.graphic_eq_rounded,
                  onTap: () => openLibrary('Recordings'),
                ),
                _QuickFolder(
                  label: 'Videos',
                  caption: 'Classes & clips',
                  icon: Icons.smart_display_rounded,
                  onTap: () => openLibrary('Videos'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (controller.recentFiles.isNotEmpty) ...[
            const SectionTitle(title: 'Continue learning'),
            const SizedBox(height: 12),
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.recentFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final entry = controller.recentFiles[index];
                  return _ContinueCard(
                    entry: entry,
                    onTap: () => openStudyViewer(context, controller, entry),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
          ],
          const SectionTitle(title: 'At a glance'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _CountPill(icon: Icons.picture_as_pdf_rounded, label: 'PDFs', count: controller.countKind(LibraryKind.pdf)),
              _CountPill(icon: Icons.auto_stories_rounded, label: 'Books', count: controller.countKind(LibraryKind.book)),
              _CountPill(icon: Icons.slideshow_rounded, label: 'Slides', count: controller.countKind(LibraryKind.slides)),
              _CountPill(icon: Icons.graphic_eq_rounded, label: 'Audio', count: controller.countKind(LibraryKind.audio)),
              _CountPill(icon: Icons.movie_rounded, label: 'Videos', count: controller.countKind(LibraryKind.video)),
              _CountPill(icon: Icons.description_rounded, label: 'Notes', count: controller.countKind(LibraryKind.note)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search your entire library',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('Fast', style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.controller});

  final LibraryController controller;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool shifted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => shifted = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final fileCount = controller.allEntries.where((item) => !item.isDirectory).length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.94),
            scheme.tertiaryContainer.withValues(alpha: 0.78),
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeInOutCubic,
            right: shifted ? -28 : -55,
            top: shifted ? -48 : -24,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.offline_bolt_rounded, size: 17, color: scheme.primary),
                          const SizedBox(width: 7),
                          Text('100% offline', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.auto_awesome_rounded, color: scheme.primary.withValues(alpha: 0.72)),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Your study world.\nOne calm place.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -0.7,
                      ),
                ),
                const SizedBox(height: 11),
                Text(
                  '$fileCount materials • ${controller.libraryName ?? 'Library'}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => controller.importFiles(destination: 'Inbox'),
                  icon: const Icon(Icons.add_to_photos_outlined),
                  label: const Text('Import anything'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFolder extends StatelessWidget {
  const _QuickFolder({
    required this.label,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap});

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FileIcon(entry: entry, heroTag: 'entry:${entry.path}'),
                    const Spacer(),
                    Icon(Icons.arrow_outward_rounded, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
                const Spacer(),
                Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(fileMeta(entry), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.icon, required this.label, required this.count});

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Text('$count $label', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Appear extends StatelessWidget {
  const _Appear({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}
