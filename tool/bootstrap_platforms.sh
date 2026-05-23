#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found" >&2
  exit 127
fi

flutter create --platforms=android,ios --org io.github.iawnix .
flutter pub get
flutter analyze
