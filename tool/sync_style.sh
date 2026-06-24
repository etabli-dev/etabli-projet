# Copyright 2026 R. Heller
# SPDX-License-Identifier: Apache-2.0

#!/usr/bin/env bash
# sync_style.sh — copy the central Coder Design System into one app repo.
# Run from inside an app repo:  bash tool/sync_style.sh <track>
#   <track> = flutter | ios | android | paired
#
# This is how every app stays byte-identical in look & feel: it never owns its
# own copy of the tokens; it COPIES from ~/etabli/_style at build/setup time.
set -euo pipefail

STYLE="${ETABLI_STYLE:-$HOME/etabli/_style}"
TRACK="${1:-paired}"

if [[ ! -d "$STYLE" ]]; then
  echo "ERROR: central style folder not found at $STYLE" >&2
  echo "Set ETABLI_STYLE or create ~/etabli/_style" >&2
  exit 1
fi

copy() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "  + $2"; }

echo "Syncing style from $STYLE (track: $TRACK)"

case "$TRACK" in
  flutter)
    copy "$STYLE/templates/coder_theme.dart" "lib/theme/coder_theme.dart"
    ;;
  ios)
    copy "$STYLE/templates/CoderTheme.swift" "ios/Shared/CoderTheme.swift"
    ;;
  android)
    copy "$STYLE/templates/CoderTheme.kt" \
         "android/app/src/main/java/com/raban/etabli/theme/CoderTheme.kt"
    ;;
  paired)
    copy "$STYLE/templates/CoderTheme.swift" "ios/Shared/CoderTheme.swift"
    copy "$STYLE/templates/CoderTheme.kt" \
         "android/app/src/main/java/com/raban/etabli/theme/CoderTheme.kt"
    ;;
  *) echo "Unknown track: $TRACK" >&2; exit 1 ;;
esac

# Tokens reference (read-only copy so the app documents its source of truth)
copy "$STYLE/tokens/coder-design-system.json" "design/coder-design-system.json"
echo "Style sync done."
