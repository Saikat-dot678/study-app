import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import 'actions.dart';
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

  static const _legacyRoots = {'Notes', 'Books', 'Slides', 'Recordings', 'Videos'};

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) return ConnectLibraryView(controller: controller);

    final spaces = controller.rootSpaces.where((space) {
      if (!_legacyRoots.contains(space.name)) return true;
      return controller.materialCountUnder(space.path) > 0 || controller.directFolderCount(space.path) > 0;
    }).toList();
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width > 1180 ? 1100.0 : double.infinity;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(width > 900 ? 28 : 18, 10, width > 900 ? 28 : 18, 130),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Appear(child: _SearchLauncher(onTap: openSearch)),
                  const SizedBox(height: 16),
                  _Appear(
                    delay: 60,
                    child: _HeroCard(
                      controller: controller,
                      onCreateSpace: () => showCreateSpaceSheet(context, controller),
                      onOpenInbox: () => openLibrary('Inbox'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Appear(
                    delay: 100,
                    child: SectionTitle(
                      title: 'Your spaces',
                      action: 'Open library',
                      onTap: () => openLibrary(null),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Organize by semester, GATE, project, research, club work—or anything else.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 13),
                  _Appear(
                    delay: 135,
                    child: _SpacesGrid(
                      controller: controller,
                      spaces: spaces,
                      onOpen: openLibrary,
                      onCreate: () => showCreateSpaceSheet(context, controller),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _InboxStrip(
                    count: controller.directMaterialCount('Inbox'),
                    onOpen: () => openLibrary('Inbox'),
                  ),
                  if (controller.recentFiles.isNotEmpty) ...[
                    const SizedBox(height: 30),
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
                  ],
                  const SizedBox(height: 30),
                  const SectionTitle(title: 'Library pulse'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _CountPill(icon: Icons.folder_copy_rounded, label: 'Spaces', count: spaces.length),
                      _CountPill(icon: Icons.picture_as_pdf_rounded, label: 'PDFs', count: controller.countKind(LibraryKind.pdf)),
                      _CountPill(icon: Icons.slideshow_rounded, label: 'Slides', count: controller.countKind(LibraryKind.slides)),
                      _CountPill(icon: Icons.graphic_eq_rounded, label: 'Audio', count: controller.countKind(LibraryKind.audio)),
                      _CountPill(icon: Icons.movie_rounded, label: 'Videos', count: controller.countKind(LibraryKind.video)),
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
      color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
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
              Expanded(child: Text('Search every folder and material', style: TextStyle(color: scheme.onSurfaceVariant))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                child: Text('Ctrl K', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.controller, required this.onCreateSpace, required this.onOpenInbox});

  final LibraryController controller;
  final VoidCallback onCreateSpace;
  final VoidCallback onOpenInbox;

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
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final files = controller.allEntries.where((item) => !item.isDirectory).length;
    final wide = MediaQuery.sizeOf(context).width > 720;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.08), blurRadius: 34, spreadRadius: -12),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.20),
                    scheme.secondary.withValues(alpha: 0.06),
                    scheme.tertiary.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOutCubic,
            right: shifted ? -35 : -75,
            top: shifted ? -65 : -30,
            child: Container(
              width: wide ? 250 : 185,
              height: wide ? 250 : 185,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [scheme.secondary.withValues(alpha: 0.18), scheme.secondary.withValues(alpha: 0)],
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
                    _GlassBadge(icon: Icons.offline_bolt_rounded, text: 'Offline by design'),
                    const Spacer(),
                    Text('$files materials', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                SizedBox(height: wide ? 38 : 27),
                Text(
                  'Build your own\nstudy system.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: wide ? 40 : null,
                        height: 0.98,
                      ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Text(
                    'Semester-wise, GATE-wise, research-wise—or completely custom. Every folder can contain more folders and material together.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                  ),
                ),
                const SizedBox(height: 21),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onCreateSpace,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create a space'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenInbox,
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
  const _SpacesGrid({required this.controller, required this.spaces, required this.onOpen, required this.onCreate});

  final LibraryController controller;
  final List<LibraryEntry> spaces;
  final ValueChanged<String?> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final count = width > 1050 ? 4 : width > 650 ? 3 : 2;
    final children = <Widget>[
      for (final space in spaces)
        _SpaceCard(
          entry: space,
          materials: controller.materialCountUnder(space.path),
          directFolders: controller.directFolderCount(space.path),
          onTap: () => onOpen(space.path),
        ),
      _CreateSpaceCard(onTap: onCreate),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: count,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: width > 650 ? 1.42 : 1.05,
      children: children,
    );
  }
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.entry, required this.materials, required this.directFolders, required this.onTap});

  final LibraryEntry entry;
  final int materials;
  final int directFolders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
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
                      gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: 0.28), scheme.secondary.withValues(alpha: 0.16)]),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.folder_rounded, color: scheme.primary),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w850, fontSize: 15)),
              const SizedBox(height: 4),
              Text('$directFolders folders • $materials materials', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateSpaceCard extends StatelessWidget {
  const _CreateSpaceCard({required this.onTap});
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
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: scheme.primary, size: 30),
              const Spacer(),
              const Text('New space', style: TextStyle(fontWeight: FontWeight.w850, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Semester • GATE • Project • Custom', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxStrip extends StatelessWidget {
  const _InboxStrip({required this.count, required this.onOpen});
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.36)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: scheme.tertiary.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.inbox_rounded, color: scheme.tertiary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inbox', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w850)),
                    const SizedBox(height: 2),
                    Text(count == 0 ? 'Shared and unorganized material lands here.' : '$count item${count == 1 ? '' : 's'} waiting to be organized.', style: Theme.of(context).textTheme.bodySmall),
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

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

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
          Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
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
                    Icon(Icons.arrow_outward_rounded, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
                const Spacer(),
                Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(entry.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
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
        color: scheme.surfaceContainerLow.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Text('$count $label', style: const TextStyle(fontWeight: FontWeight.w700)),
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
      duration: Duration(milliseconds: 380 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}
