import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../viewers/viewer_page.dart';
import 'actions.dart';
import 'library_widgets.dart';
import 'motion.dart';

Future<void> showCommandCenter(
  BuildContext context,
  LibraryController controller, {
  required ValueChanged<int> navigate,
  required ValueChanged<String> openFolder,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close command center',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: StudyMotion.duration(context, StudyMotion.standard),
    pageBuilder: (_, _, _) => _CommandCenter(
      hostContext: context,
      controller: controller,
      navigate: navigate,
      openFolder: openFolder,
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: StudyMotion.curve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          alignment: const Alignment(0, -0.72),
          child: child,
        ),
      );
    },
  );
}

class _CommandCenter extends StatefulWidget {
  const _CommandCenter({
    required this.hostContext,
    required this.controller,
    required this.navigate,
    required this.openFolder,
  });

  final BuildContext hostContext;
  final LibraryController controller;
  final ValueChanged<int> navigate;
  final ValueChanged<String> openFolder;

  @override
  State<_CommandCenter> createState() => _CommandCenterState();
}

class _CommandCenterState extends State<_CommandCenter> {
  final input = TextEditingController();
  final focusNode = FocusNode();
  String query = '';
  int selected = 0;

  @override
  void dispose() {
    input.dispose();
    focusNode.dispose();
    super.dispose();
  }

  List<_Command> get commands {
    final values = <_Command>[
      _Command(
        'Go Home',
        'Dashboard and continue studying',
        Icons.home_rounded,
        () => widget.navigate(0),
      ),
      _Command(
        'Open Library',
        'Browse the current folder',
        Icons.folder_rounded,
        () => widget.navigate(1),
      ),
      _Command(
        'Search library',
        'Open the full search workspace',
        Icons.manage_search_rounded,
        () => widget.navigate(2),
      ),
      _Command(
        'Open Settings',
        'Library and app information',
        Icons.tune_rounded,
        () => widget.navigate(3),
      ),
      if (widget.controller.connected)
        _Command(
          'Add material',
          'Import, create a folder, or write a note',
          Icons.add_circle_rounded,
          () {
            showAddSheet(widget.hostContext, widget.controller, fromHome: true);
          },
        ),
      if (widget.controller.connected)
        _Command(
          widget.controller.gridMode ? 'Use list view' : 'Use grid view',
          'Change the library layout',
          widget.controller.gridMode
              ? Icons.view_list_rounded
              : Icons.grid_view_rounded,
          () => widget.controller.setGridMode(!widget.controller.gridMode),
        ),
    ];
    if (query.isEmpty) return values;
    final terms = query.toLowerCase().split(RegExp(r'\s+'));
    return values.where((command) {
      final value = '${command.title} ${command.subtitle}'.toLowerCase();
      return terms.every(value.contains);
    }).toList();
  }

  List<LibraryEntry> get entries {
    if (!widget.controller.connected) return const [];
    final values = query.isEmpty
        ? [...widget.controller.pinnedFolders, ...widget.controller.recentFiles]
        : widget.controller.searchEntries(query);
    final unique = <String, LibraryEntry>{};
    for (final entry in values) {
      unique[entry.path] = entry;
      if (unique.length == 14) break;
    }
    return unique.values.toList();
  }

  int get itemCount => commands.length + entries.length;

  void _move(int delta) {
    if (itemCount == 0) return;
    setState(() => selected = (selected + delta) % itemCount);
  }

  void _activate(int index) {
    if (index < commands.length) {
      final command = commands[index];
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) => command.action());
      return;
    }
    final entry = entries[index - commands.length];
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (entry.isDirectory) {
        widget.openFolder(entry.path);
      } else {
        openStudyViewer(widget.hostContext, widget.controller, entry);
      }
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && itemCount > 0) {
      _activate(selected.clamp(0, itemCount - 1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final commandValues = commands;
    final entryValues = entries;
    if (selected >= commandValues.length + entryValues.length) selected = 0;

    return SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.72),
        child: Material(
          color: scheme.surfaceContainerLowest,
          elevation: 18,
          shadowColor: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 610),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    onKeyEvent: _onKey,
                    child: TextField(
                      controller: input,
                      focusNode: focusNode,
                      autofocus: true,
                      onChanged: (value) => setState(() {
                        query = value;
                        selected = 0;
                      }),
                      decoration: InputDecoration(
                        hintText: 'Search materials or run a command…',
                        prefixIcon: Icon(
                          Icons.bolt_rounded,
                          color: scheme.primary,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              child: Text(
                                'ESC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      shrinkWrap: true,
                      children: [
                        if (commandValues.isNotEmpty)
                          const _GroupLabel('Commands'),
                        for (
                          var index = 0;
                          index < commandValues.length;
                          index++
                        )
                          _CommandTile(
                            command: commandValues[index],
                            selected: selected == index,
                            onTap: () => _activate(index),
                          ),
                        if (entryValues.isNotEmpty)
                          _GroupLabel(
                            query.isEmpty ? 'Pinned & recent' : 'Library',
                          ),
                        for (var index = 0; index < entryValues.length; index++)
                          _EntryTile(
                            entry: entryValues[index],
                            controller: widget.controller,
                            selected: selected == commandValues.length + index,
                            onTap: () =>
                                _activate(commandValues.length + index),
                          ),
                        if (commandValues.isEmpty && entryValues.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Text(
                              'No matching material or command.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 11),
                    child: Row(
                      children: [
                        Text(
                          '↑↓ Navigate   ↵ Open',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          'Try type:pdf or is:favorite',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Command {
  const _Command(this.title, this.subtitle, this.icon, this.action);
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback action;
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.command,
    required this.selected,
    required this.onTap,
  });
  final _Command command;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: 0.48),
      leading: Icon(command.icon),
      title: Text(
        command.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(command.subtitle),
      trailing: selected
          ? const Icon(Icons.keyboard_return_rounded, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.controller,
    required this.selected,
    required this.onTap,
  });
  final LibraryEntry entry;
  final LibraryController controller;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: 0.48),
      leading: FileIcon(entry: entry),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(entry.path, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: controller.isFavorite(entry.path)
          ? const Icon(Icons.star_rounded, size: 18)
          : entry.isDirectory && controller.isPinned(entry.path)
          ? const Icon(Icons.push_pin_rounded, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
