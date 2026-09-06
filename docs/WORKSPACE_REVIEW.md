# Study workspace review

Implemented on `feature/study-workspace-polish`, September 2026. This is an incremental improvement to the existing Flutter application, with its storage bridge, native Android SAF integration, hierarchy, and offline viewers retained.

## Findings and design decisions

| Finding in the existing app | Change |
| --- | --- |
| Home led with a large promotional panel and decorative animation. Recent cards actually used modification dates. | A study desk led by capture, Inbox triage, actual opening history, stars, and existing spaces. |
| Desktop command search only switched tabs. | Ctrl/Cmd+K opens searchable actions and files, with Up/Down/Enter/Escape navigation. |
| Search created every result widget and silently missed items after a 5,000-entry scan cap. | Lazy result rows, uncapped enumeration, word matching across paths, optional `type:` and `is:starred` filters. |
| Filing required finding a destination repeatedly; batch moves lacked contextual classification. | One import/move surface with pinned and recent destinations, local categories, custom names, and an explicit destination preview. |
| Fixed grids, app branding, and search headings failed at narrow widths or enlarged text. | Layouts based on available width and text scale, scrollable action sheets/sidebar, scalable material grids, and compact branding. |
| Folder counts repeatedly traversed the index during widget builds. | Counts aggregated once per scan and accessed by path. |
| Bulk failures left stale views, moves could silently rename on collision, and overlapping navigation could race. | Serialized operations, partial-failure reconciliation, explicit conflicts, selection reconciliation, and subtree metadata updates. |
| Android provider I/O/scans ran on the main thread. | A serial storage worker for scans, preparation, import copies, and metadata. System activity launches remain on the UI thread. |
| A null output stream could cause staged Android shares to be deleted without being copied. | Stream failures retain staged sources; incomplete imported files are cleaned up. |
| Android preview cache keys did not identify the library. | URI-based SHA-256 cache identities, preventing reuse across different libraries. |
| Windows video used a content-URI constructor for local files. | Native file-based video controller on desktop; content URIs retained for Android. |
| EPUB reading order used archive filenames. | Respect the package spine, with a readable fallback for damaged metadata. |

## Research and principles

- [Linear's March 2026 design refresh](https://linear.app/now/behind-the-latest-design-refresh): reduce competing visual weight and make action placement predictable. Applied through quieter surfaces, fewer decorative layers, and a task-oriented Home. This is a design interpretation, not a copied layout.
- [Raycast file search](https://manual.raycast.com/file-search) and [Quicklinks](https://manual.raycast.com/quicklinks): quick retrieval and direct access to recurring destinations informed the command palette and filing shortcuts.
- [Obsidian bookmarks](https://obsidian.md/help/plugins/bookmarks): shortcuts to normal files/folders informed stars and pins without duplicate materials.
- [Flutter adaptive design](https://docs.flutter.dev/ui/adaptive-responsive) and [best practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices): adapt to available constraints and input methods, rather than stretching a phone layout. Tests include 320–1920 logical pixels and 180% text.
- [Android document access](https://developer.android.com/training/data-storage/shared/documents-files): retain user-granted tree access and provider streams; no all-files permission or online conversion was introduced.
- [EPUB 3.3](https://www.w3.org/TR/epub-33/): the spine defines reading order; archive ordering is not a substitute.

The student features selected are retrieval, filing, and resuming existing material. Tags, collections, timers, and syllabus tracking are deferred because they add new organizational concepts and need more product validation. No account, backend, telemetry, or normal-operation network dependency was added.

## Storage and compatibility

Files and folders remain the source of truth. Existing libraries are not relocated or cleaned up automatically. New Android libraries now create only Inbox; existing type folders remain visible and usable.

Optional state uses relative paths in `.studyapp/workspace-0.json` and `workspace-1.json`: stars, opening timestamps, PDF page numbers, media milliseconds, and eight recent filing destinations. Alternating versioned snapshots allow recovery from an interrupted write. If neither snapshot is readable, files still work and the damaged metadata is preserved. Snapshot writes are serialized; failures are surfaced without blocking access to material. Removing `.studyapp` loses these conveniences, not the original files.

In-app rename and move update referenced descendants. Conflicting moves leave the source in place and report the conflict instead of silently renaming it. External renames cannot be reliably matched to old metadata; reconnect/rescan still finds the actual files. This is a portable local snapshot, not a multi-device synchronization protocol.

Desktop paths are checked against the library root, including resolved existing ancestors. Linked entries are omitted from browsing. Explorer drops copy individual files through the same filing surface; source files remain untouched. Folder drops and Explorer clipboard file objects are not supported. Internal drag-to-move is deferred; Ctrl/Shift selection and bulk filing are available.

## Readers and performance

PDF, Markdown/text, image, audio, video, EPUB and office document readers remain offline. PDF pages and audio/video positions are saved periodically and on normal reader close. An abrupt process termination can lose the last few seconds. Playback codecs remain dependent on the device.

Audio uses the provider URI on Android instead of making a complete preview copy. Office/EPUB parsing runs in an isolate. Text-preview archives over 128 MiB compressed or expanded are sent to the existing fallback rather than allowed to consume unbounded memory; originals remain available. Office views extract readable content, not an exact reproduction of slides or spreadsheet formulas/layout. EPUB uses chapter-based text viewing; EPUB scroll resume is not implemented.

The library index is still an in-memory full scan. It does not read file contents for search; filesystem mutation triggers a rescan. Incremental indexing, filesystem watchers, and real-device frame profiling remain future work. The 5,100-file filesystem and 6,000-result widget tests validate coverage/lazy rendering, not a universal performance guarantee.

## Verification

Reproduce the automated checks with:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
powershell -ExecutionPolicy Bypass -File tool/build_windows.ps1
flutter test integration_test/offline_readers_test.dart -d windows
```

The Windows helpers retain `patch_windows_cmake.ps1` and now stop on failed Flutter commands instead of printing a false success message. Native Windows runner scaffolding is generated by the existing helper/CI workflow.

The native test creates isolated PDF, Markdown, PNG, and WAV fixtures and exercises the actual Windows readers. For the optional local MP4 check, pass `--dart-define=STUDY_QA_VIDEO=<absolute local mp4 path>`. The verification run used a downloaded local copy of the [Flutter cookbook video sample](https://docs.flutter.dev/cookbook/plugins/play-video); the app/test reads the local copy. Tests never connect or modify the user's library.

Automated coverage also includes naming/path validation, 30 nested levels, note contents, rename/move/delete, source-preserving copy conflicts, partial bulk failures, metadata recovery and subtree remapping, desktop selection/context menus, command navigation, responsive layouts, and offline document fixtures. Widget screenshots are generated under `build/qa/` for visual inspection.

No physical Android device or configured Android emulator was available. Android SAF provider behavior, incoming Android Share intents, revoked permissions, and media playback on Android still require device acceptance testing. Explorer's native drag gesture itself also needs manual acceptance; the drop surface compiles, and its source-copy/filing paths are tested.

Final build outcomes and artifact paths are recorded in `VERIFICATION.md` after the final checks.
