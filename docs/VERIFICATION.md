# Workspace verification

Local verification on Windows, September 6, 2026, using Flutter 3.47.2 / Dart 3.13.2. The feature branch is `feature/study-workspace-polish`.

## Automated checks

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed, 23 tests |
| `flutter build apk --debug` | Passed |
| `flutter build apk --release` | Passed, 74.5 MB APK |
| Windows native reader integration test | Passed, including optional MP4 fixture |
| `tool/build_windows.ps1` | Passed, Windows release build; CMake audio compatibility patch retained |

The test suite covers search syntax, relative metadata recovery/remapping, actual opening history, partial bulk moves, serialized navigation, 30 nested folder levels, note contents, rename/move/delete, root/metadata protection, collision-safe imports, source preservation, library-copy reconnection, 5,100-file enumeration, and offline document extraction (DOCX, PPTX, XLSX, EPUB, corrupt archive).

Widget tests cover widths of 320, 390, 768, 1280, and 1920 logical pixels with normal and 180% text; grids and the complete shell; Ctrl/Shift selection, select-all, right-click menus, system back through nested folders, custom filing categories, command palette arrow/Enter navigation, and lazy rendering of 6,000 search results. Generated phone/desktop screenshots were visually inspected.

The Windows integration test runs actual native readers against an isolated temporary library containing PDF, Markdown, PNG, PCM WAV, and a local MP4. It checks successful opening, native video initialization, and restoration of saved audio/video positions. It caught an audio load race where a temporary zero duration reset the saved position, then passed after the fix. It also verifies the corrected local-file video initialization. It does not use the user's library.

Reproduce the optional video test with:

```powershell
flutter test integration_test/offline_readers_test.dart -d windows --dart-define=STUDY_QA_VIDEO=E:/study-app/build/qa/lecture.mp4
```

The MP4 is a local copy of the sample linked in the [Flutter video cookbook](https://docs.flutter.dev/cookbook/plugins/play-video). It is a QA input, not an application dependency or committed asset. Without the define, the native test still exercises PDF, Markdown, image, and audio.

## Local artifacts

- Android: `build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk`.
- Windows release: `build/windows/x64/runner/Release/study_app.exe`. Keep the entire Release directory together, including its DLLs and data directory.
- Screenshots: `build/qa/workspace-390.png`, `build/qa/workspace-1280.png`, and `build/qa/study-desk.png`.
- Logs: `build/qa/windows-release.log`, `build/qa/native-test.log`, `build/qa/android-debug.log`, and `build/qa/android-release.log`.

Generated runners, logs, screenshots, test media, and binaries remain local build artifacts. Existing local analyzer/Gradle configuration edits were preserved outside the feature commits.

## Acceptance still needed

- No physical Android device or configured emulator was available. SAF provider differences, incoming Share intents, revoked permissions, and Android media playback need device acceptance despite successful compilation checks.
- Explorer's native drag gesture needs manual acceptance. The desktop drop target compiles and its source-copy/filing pipeline is tested; folder drops, clipboard file objects, and internal drag-to-move are deferred.
- PDF native opening is tested; PDF page restoration still needs a multi-page device acceptance check. EPUB scroll resume is not implemented.
- Library search uses an in-memory full scan. Large-fixture tests establish coverage and lazy widget creation, not device-independent frame-rate guarantees. No real-device frame profiling was performed.
- Original files remain ordinary files. External renames can leave stale optional metadata references; alternating snapshots provide interrupted-write recovery, not concurrent multi-device synchronization.

See [the workspace review](WORKSPACE_REVIEW.md) for research, design decisions, storage architecture, and deliberately deferred features.
