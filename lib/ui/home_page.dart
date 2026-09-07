import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../models/study_metadata.dart';
import '../viewers/viewer_page.dart';
import 'actions.dart';
import 'library_widgets.dart';
import 'motion.dart';

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

  static const _legacyRoots = {
    'Notes',
    'Books',
    'Slides',
    'Recordings',
    'Videos',
  };

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) {
      return ConnectLibraryView(controller: controller);
    }

    final spaces = controller.rootSpaces.where((space) {
      if (!_legacyRoots.contains(space.name)) return true;
      return controller.materialCountUnder(space.path) > 0 ||
          controller.directFolderCount(space.path) > 0;
    }).toList();
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final quickAccess = <String, LibraryEntry>{
      for (final entry in controller.pinnedFolders) entry.path: entry,
      for (final entry in controller.favoriteEntries) entry.path: entry,
    }.values.take(8).toList();

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          width > 900 ? 28 : 18,
          10,
          width > 900 ? 28 : 18,
          130,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (width < 900) ...[
                    StaggeredReveal(child: _SearchLauncher(onTap: openSearch)),
                    const SizedBox(height: 16),
                  ],
                  StaggeredReveal(
                    index: 1,
                    child: _Hero(
                      greeting: greeting,
                      controller: controller,
                      onCreate: () => showCreateSpaceSheet(context, controller),
                      onInbox: () => openLibrary('Inbox'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SectionTitle(
                    title: 'Your spaces',
                    action: 'Open library',
                    onTap: () => openLibrary(null),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Semester, GATE, research, projects, club work—build the hierarchy that matches your life.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 13),
                  _SpacesGrid(
                    controller: controller,
                    spaces: spaces,
                    onOpen: (path) => openLibrary(path),
                    onCreate: () => showCreateSpaceSheet(context, controller),
                  ),
                  if (quickAccess.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const SectionTitle(title: 'Pinned & starred'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickAccess.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 9),
                        itemBuilder: (context, index) {
                          final entry = quickAccess[index];
                          return SizedBox(
                            width: 292,
                            child: FileRow(
                              entry: entry,
                              showPath: true,
                              onTap: () => entry.isDirectory
                                  ? openLibrary(entry.path)
                                  : openStudyViewer(context, controller, entry),
                              trailing: Icon(
                                entry.isDirectory &&
                                        controller.isPinned(entry.path)
                                    ? Icons.push_pin_rounded
                                    : Icons.star_rounded,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _InboxStrip(
                    count: controller.directMaterialCount('Inbox'),
                    onTap: () => openLibrary('Inbox'),
                  ),
                  if (controller.recentFiles.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const SectionTitle(title: 'Continue learning'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 188 + ((textScale - 1).clamp(0, 1) * 80),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.recentFiles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final entry = controller.recentFiles[index];
                          return _RecentCard(
                            entry: entry,
                            progress: controller.progressFor(entry.path),
                            onTap: () =>
                                openStudyViewer(context, controller, entry),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  const SectionTitle(title: 'Library pulse'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _Metric(
                        icon: Icons.folder_copy_rounded,
                        label: 'Spaces',
                        count: spaces.length,
                      ),
                      _Metric(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDFs',
                        count: controller.countKind(LibraryKind.pdf),
                      ),
                      _Metric(
                        icon: Icons.slideshow_rounded,
                        label: 'Slides',
                        count: controller.countKind(LibraryKind.slides),
                      ),
                      _Metric(
                        icon: Icons.movie_rounded,
                        label: 'Videos',
                        count: controller.countKind(LibraryKind.video),
                      ),
                      _Metric(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Audio',
                        count: controller.countKind(LibraryKind.audio),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      color: scheme.surfaceContainerLow.withValues(alpha: 0.86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.primary),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Search every folder and material',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ctrl K',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({
    required this.greeting,
    required this.controller,
    required this.onCreate,
    required this.onInbox,
  });

  final String greeting;
  final LibraryController controller;
  final VoidCallback onCreate;
  final VoidCallback onInbox;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  bool moved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => moved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width > 720;
    final files = widget.controller.allEntries
        .where((entry) => !entry.isDirectory)
        .length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.surfaceContainerLow,
            scheme.tertiary.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeInOutCubic,
            right: moved ? -35 : -75,
            top: moved ? -55 : -20,
            child: Container(
              width: wide ? 250 : 180,
              height: wide ? 250 : 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.secondary.withValues(alpha: 0.18),
                    scheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 28 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Badge(
                      icon: Icons.offline_bolt_rounded,
                      label: 'Offline by design',
                    ),
                    const Spacer(),
                    Text(
                      '$files materials',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                SizedBox(height: wide ? 38 : 27),
                Text(
                  widget.controller.recentFiles.isEmpty
                      ? '${widget.greeting}.\nBuild your study system.'
                      : '${widget.greeting}.\nPick up where you left off.',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: wide ? 40 : null, height: 0.98),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: Text(
                    'Every folder can contain folders and material together. Use templates when useful, ignore them when they are not.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create a space'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onInbox,
                      icon: const Icon(Icons.inbox_rounded),
                      label: const Text('Open Inbox'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpacesGrid extends StatelessWidget {
  const _SpacesGrid({
    required this.controller,
    required this.spaces,
    required this.onOpen,
    required this.onCreate,
  });

  final LibraryController controller;
  final List<LibraryEntry> spaces;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1050
        ? 4
        : width > 650
        ? 3
        : 2;
    final cards = <Widget>[
      for (final space in spaces)
        _SpaceCard(
          entry: space,
          folders: controller.directFolderCount(space.path),
          materials: controller.materialCountUnder(space.path),
          onTap: () => onOpen(space.path),
        ),
      _CreateCard(onTap: onCreate),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: width > 650 ? 1.42 : 0.85,
      children: cards,
    );
  }
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({
    required this.entry,
    required this.folders,
    required this.materials,
    required this.onTap,
  });

  final LibraryEntry entry;
  final int folders;
  final int materials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverLift(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.28),
                            scheme.secondary.withValues(alpha: 0.14),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.folder_rounded, color: scheme.primary),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$folders folders • $materials materials',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 30),
              Spacer(),
              Text(
                'New space',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'Semester • GATE • Project • Custom',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxStrip extends StatelessWidget {
  const _InboxStrip({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.36)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.inbox_rounded, color: scheme.tertiary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inbox',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'Shared and unorganized material lands here.'
                          : '$count item${count == 1 ? '' : 's'} waiting to be organized.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.entry,
    required this.progress,
    required this.onTap,
  });
  final LibraryEntry entry;
  final StudyProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = ((progress?.fraction ?? 0) * 100).round();
    return SizedBox(
      width: 220,
      child: HoverLift(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
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
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (progress?.hasProgress ?? false) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress!.fraction,
                        minHeight: 3,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress!.pageCount > 0
                          ? 'Page ${progress!.page} of ${progress!.pageCount} · $percent%'
                          : '${_shortTime(progress!.position)} of ${_shortTime(progress!.duration)} · $percent%',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _shortTime(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes
      .remainder(60)
      .toString()
      .padLeft(hours > 0 ? 2 : 1, '0');
  return hours > 0 ? '$hours:$minutes' : '$minutes min';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.count});
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              '$count $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
