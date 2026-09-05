import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import 'library_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.openLibrary,
  });

  final LibraryController controller;
  final ValueChanged<String?> openLibrary;

  @override
  Widget build(BuildContext context) {
    if (!controller.connected) return ConnectLibraryView(controller: controller);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _HeroCard(controller: controller),
          const SizedBox(height: 28),
          SectionTitle(
            title: 'Quick access',
            action: 'Open library',
            onTap: () => openLibrary(null),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 5 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _QuickFolder(
                label: 'Inbox',
                icon: Icons.inbox_rounded,
                onTap: () => openLibrary('Inbox'),
              ),
              _QuickFolder(
                label: 'Notes',
                icon: Icons.edit_note_rounded,
                onTap: () => openLibrary('Notes'),
              ),
              _QuickFolder(
                label: 'Books',
                icon: Icons.menu_book_rounded,
                onTap: () => openLibrary('Books'),
              ),
              _QuickFolder(
                label: 'Slides',
                icon: Icons.slideshow_rounded,
                onTap: () => openLibrary('Slides'),
              ),
              _QuickFolder(
                label: 'Recordings',
                icon: Icons.graphic_eq_rounded,
                onTap: () => openLibrary('Recordings'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionTitle(title: 'At a glance'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountPill(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDFs',
                count: controller.countKind(LibraryKind.pdf),
              ),
              _CountPill(
                icon: Icons.slideshow_rounded,
                label: 'Slides',
                count: controller.countKind(LibraryKind.slides),
              ),
              _CountPill(
                icon: Icons.audio_file_rounded,
                label: 'Audio',
                count: controller.countKind(LibraryKind.audio),
              ),
              _CountPill(
                icon: Icons.description_rounded,
                label: 'Notes',
                count: controller.countKind(LibraryKind.note),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionTitle(title: 'Recently touched'),
          const SizedBox(height: 12),
          if (controller.recentFiles.isEmpty)
            const EmptyCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Your library is ready',
              subtitle: 'Import a PDF, PPT, recording or create your first note.',
            )
          else
            ...controller.recentFiles.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FileRow(
                  entry: entry,
                  onTap: () => controller.openEntry(entry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileCount = controller.allEntries.where((item) => !item.isDirectory).length;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.offline_bolt_rounded),
              const SizedBox(width: 8),
              Text(
                'Offline • portable',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Everything for class,\nin one calm place.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '$fileCount files • ${controller.libraryName ?? 'Library'}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          FilledButton.tonalIcon(
            onPressed: () => controller.importFiles(destination: 'Inbox'),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import to Inbox'),
          ),
        ],
      ),
    );
  }
}

class _QuickFolder extends StatelessWidget {
  const _QuickFolder({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$count $label'),
        ],
      ),
    );
  }
}
