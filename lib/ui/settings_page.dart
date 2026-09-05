import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          'Storage',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      controller.connected
                          ? Icons.folder_special_rounded
                          : Icons.folder_off_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.connected
                            ? controller.libraryName ?? 'Connected folder'
                            : 'No library connected',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  controller.connected
                      ? 'This is the folder Study App reads and writes. Your files are not trapped inside an app database.'
                      : 'Choose an existing folder or create a new one with Android’s folder picker.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: controller.connectLibrary,
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: Text(controller.connected ? 'Change folder' : 'Connect folder'),
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
        Text(
          'Move to a new phone',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.phone_android_rounded,
          title: 'Copy once, reconnect once',
          body: 'Copy the complete library folder to the new phone, install Study App, then choose that copied folder. Nested folders, notes and files appear again immediately.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.shield_outlined,
          title: 'Private by default',
          body: 'No account, analytics service or backend is required. Android grants access only to the folder you explicitly choose.',
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
    );
  }

  Future<void> _confirmForget(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forget folder connection?'),
        content: const Text(
          'Study App will lose access until you select a folder again. Your files will not be deleted.',
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
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
