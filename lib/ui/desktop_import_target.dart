import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../controllers/library_controller.dart';
import 'filing_sheet.dart';

class DesktopImportTarget extends StatefulWidget {
  const DesktopImportTarget({
    super.key,
    required this.controller,
    required this.destination,
    required this.child,
  });
  final LibraryController controller;
  final String destination;
  final Widget child;
  @override
  State<DesktopImportTarget> createState() => _DesktopImportTargetState();
}

class _DesktopImportTargetState extends State<DesktopImportTarget> {
  bool hovering = false;
  bool filing = false;
  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return widget.child;
    }
    return DropTarget(
      enable: widget.controller.connected && !widget.controller.busy && !filing,
      onDragEntered: (_) => setState(() => hovering = true),
      onDragExited: (_) => setState(() => hovering = false),
      onDragDone: (details) async {
        if (details.files.isEmpty || filing) return;
        setState(() {
          hovering = false;
          filing = true;
        });
        await showFilingSheet(
          context,
          widget.controller,
          initialPath: widget.destination,
          sourcePaths: details.files.map((f) => f.path).toList(),
        );
        if (mounted) setState(() => filing = false);
      },
      child: Stack(
        children: [
          widget.child,
          if (hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: .95),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Drop files to organize',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose a destination next. Originals stay in place.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
