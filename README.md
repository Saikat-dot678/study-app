# Study App

An offline-first Flutter student library for Android. It keeps notes, books, PPTs, PDFs, recordings, images and other study material in one user-selected folder instead of a cloud account.

## What is implemented

- User-selected portable library folder using Android Storage Access Framework (SAF).
- Nested folders with create, rename, move and delete.
- Common `Inbox` for files shared from WhatsApp, Files/My Files, Drive providers and other Android apps through the system share sheet.
- Multi-file import through Android's document picker.
- Quick Markdown notes created directly inside the library.
- Home dashboard, quick folders, recents, library browser, global search and settings.
- Local file opening with the phone's installed PDF/PPT/audio/document apps.
- No account, server, telemetry or internet requirement.
- Hidden `.studyapp/library.json` marker inside the chosen folder so the folder is self-describing and migratable.

## Portable library / phone migration

1. Choose a folder when Study App first starts. The app creates `Inbox`, `Notes`, `Books`, `Slides`, `Recordings` and `.studyapp` inside it.
2. Copy that whole folder to another phone using USB, SD card, Nearby Share, a local backup tool, or any method you prefer.
3. Install Study App on the new phone.
4. Tap **Connect library folder** and select the copied folder.
5. The app scans the folder and everything is available again. The files themselves are the source of truth; there is no cloud database to restore.

Android intentionally does not grant permanent raw filesystem access to arbitrary folders. Study App uses SAF and stores the permission Android gives it for the selected folder. That is safer than requesting `MANAGE_EXTERNAL_STORAGE` and works with Android's scoped-storage model.

## Run

Use a current Flutter stable SDK (the project targets the 2026 Flutter Android template generation: AGP 9.1 / Kotlin 2.4 / Java 17).

```bash
flutter pub get
flutter run
```

Flutter injects the Gradle wrapper if it is missing. Android Studio or `flutter run` will create `android/local.properties` with your local Flutter SDK path.

## Android sharing

The launcher activity registers for `ACTION_SEND` and `ACTION_SEND_MULTIPLE`. Shared files are copied immediately into `Inbox`. If the library has not been connected yet, the incoming content is temporarily staged in the app's private storage and flushed to `Inbox` after a library folder is selected.

## Privacy

All study files remain in the folder you chose. The app does not request network permission for release functionality and contains no backend integration.
