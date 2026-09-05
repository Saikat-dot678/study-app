# Study

Study is an offline-first Flutter student library for Android and desktop. It keeps PDFs, notes, books, PPTs, documents, spreadsheets, recordings, videos, images and other material in one user-selected folder instead of a cloud account.

## What is implemented

- One portable **Study Library** folder as the source of truth.
- Android Storage Access Framework (SAF) integration without dangerous all-files permission.
- Native desktop filesystem + system file/folder pickers on Windows, macOS and Linux.
- Unlimited nested folders with create, rename, multi-select move and delete.
- Common `Inbox` for files shared from WhatsApp, Files/My Files and other Android apps.
- Multi-file import on phone and desktop.
- Quick Markdown notes created directly inside the library.
- Built-in PDF, Markdown/text and image reading.
- Built-in audio player with seeking and playback speed.
- Built-in video player with scrubbing and playback speed.
- Offline readable views for EPUB and modern DOCX/PPTX/XLSX/OpenDocument files.
- External-app fallback for legacy/uncommon formats.
- Responsive mobile/tablet/desktop UI with a dedicated desktop sidebar, desktop command search and keyboard shortcuts.
- Home dashboard, quick folders, continue-learning cards, library browser, global search and settings.
- No account, server, telemetry or internet requirement for the library workflow.
- Hidden `.studyapp/library.json` marker so a copied library folder is self-describing and reconnectable.

## Suggested library structure

```text
Study Library/
├── Inbox/
├── Notes/
├── Books/
├── Slides/
├── Recordings/
├── Videos/
├── Semester 5/
│   ├── Computational Number Theory/
│   ├── DBMS/
│   └── ...
└── .studyapp/
    └── library.json
```

You are free to create any nested structure you want. The app never requires this exact hierarchy.

## Phone ↔ desktop migration

1. Copy the complete Study Library folder to the other device using USB, local network transfer, SD card, an external drive or any other method you prefer.
2. Install/run Study on the destination device.
3. Choose **Connect folder** and select the copied Study Library folder.
4. Study rescans the real folder structure; there is no separate cloud database to restore.

On Android, Study persists the SAF permission Android grants for the selected folder. On desktop, Study stores only the selected local folder path in app preferences. The material itself always remains normal files inside your library.

## Android

Use current Flutter stable:

```bash
flutter pub get
flutter run -d android
```

The launcher activity registers for `ACTION_SEND` and `ACTION_SEND_MULTIPLE`. Shared material is copied into `Inbox`. If no library is connected yet, incoming items are staged in app-private storage and flushed into `Inbox` after a library folder is selected.

## Windows desktop

The repository includes a helper that generates Flutter's native Windows runner the first time, installs dependencies and launches the desktop app:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_windows.ps1
```

For a release build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
```

The release output is produced under `build/windows/x64/runner/Release`.

Flutter desktop tooling requires Visual Studio with **Desktop development with C++** and the Windows SDK. The generated `windows/` runner is standard Flutter platform scaffolding; the application logic lives in this repository's shared Dart code.

## macOS / Linux

The shared app/storage code supports desktop platforms. Bootstrap and launch using:

```bash
./tool/run_desktop.sh macos
# or
./tool/run_desktop.sh linux
```

You still need the normal Flutter platform build prerequisites for that operating system.

## Desktop UX

At widths of roughly 980px and above, Study switches to a desktop shell with:

- persistent navigation sidebar,
- wide content workspace,
- command-style library search,
- desktop add/refresh controls,
- adaptive cards and file grids,
- `Ctrl+K` / `Cmd+K` search,
- `Alt+1`, `Alt+2`, `Alt+3` navigation shortcuts.

Below that breakpoint it returns to the compact touch-first navigation used on phones and tablets.

## CI

Pull requests validate both surfaces:

- Flutter analyze + tests + Android debug APK build on Linux,
- Flutter analyze + tests + native Windows debug build on `windows-latest`.

## Privacy

Study has no backend requirement. Your study files remain in the folder you choose. Reader/player preparation may use temporary local cache files when a platform API requires them; originals remain inside your portable library folder.
