import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 116),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your library stays local, portable and under your control.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Storage'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              controller.connected
                                  ? Icons.folder_special_rounded
                                  : Icons.folder_off_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.connected
                                      ? controller.libraryName ??
                                            'Connected folder'
                                      : 'No library connected',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  controller.connected
                                      ? 'Portable library folder'
                                      : 'Choose a folder to begin',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(
                        controller.connected
                            ? 'Study reads and writes directly inside this folder. Your materials are normal files, not trapped in a private database.'
                            : 'Choose any local folder with the system folder picker. The same library model works on Android and desktop.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: controller.connectLibrary,
                            icon: const Icon(Icons.drive_file_move_outline),
                            label: Text(
                              controller.connected
                                  ? 'Change folder'
                                  : 'Connect folder',
                            ),
                          ),
                          if (controller.connected)
                            OutlinedButton.icon(
                              onPressed: controller.refresh,
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('Rescan'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Built-in learning tools'),
              const SizedBox(height: 10),
              const _InfoCard(
                icon: Icons.play_circle_outline_rounded,
                title: 'Resume without leaving Study',
                body: 'PDFs, audio and video reopen at the saved page or position. Modern documents and EPUB files keep their offline readable view.',
              ),
              const SizedBox(height: 10),
              const _InfoCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Portable personal context',
                body: 'Favorites, pins, recent destinations and reading progress live in .studyapp/state.json beside your library marker. Removing it never removes a study file.',
              ),
              const SizedBox(height: 10),
              const _InfoCard(
                icon: Icons.open_in_new_rounded,
                title: 'External apps are still available',
                body: 'Legacy or unusual formats remain accessible through “Open in another app”, so your library never becomes a format lock-in.',
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Move between phone and desktop'),
              const SizedBox(height: 10),
              const _InfoCard(
                icon: Icons.devices_rounded,
                title: 'Copy once, reconnect once',
                body: 'Copy the complete Study Library folder to another phone or computer, install Study, then select that copied folder. Your nested structure and materials appear again immediately.',
              ),
              const SizedBox(height: 10),
              const _InfoCard(
                icon: Icons.shield_outlined,
                title: 'Private by default',
                body: 'No account, analytics service or backend is required. Study only works with the local library folder you explicitly choose.',
              ),
              if (controller.connected) ...[
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => _confirmForget(context),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Forget folder connection'),
                ),
                const SizedBox(height: 8),
                Text(
                  'This never deletes the folder or any material inside it.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmForget(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forget folder connection?'),
        content: const Text(
          'Study will lose access until you select a folder again. Your files will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.forgetLibrary();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 21,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
