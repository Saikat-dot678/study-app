#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  macos)
    flutter config --enable-macos-desktop
    if [ ! -f macos/Runner.xcodeproj/project.pbxproj ]; then
      flutter create --platforms=macos .
    fi
    flutter pub get
    flutter run -d macos
    ;;
  linux)
    flutter config --enable-linux-desktop
    if [ ! -f linux/CMakeLists.txt ]; then
      flutter create --platforms=linux .
    fi
    flutter pub get
    flutter run -d linux
    ;;
  *)
    echo "Usage: ./tool/run_desktop.sh macos|linux"
    exit 2
    ;;
esac
