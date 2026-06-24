#!/usr/bin/env bash
# capture.sh — screenshot harness for etabli-projet (v0.1.0). Reachable screens only;
# data screens require a running OpenProject instance + credentials.
set -euo pipefail
DBG=com.raban.etabli.projet.debug
OUT="$(cd "$(dirname "$0")/.." && pwd)/vignettes/assets/0.1.0"; mkdir -p "$OUT"
cap(){ for t in 1 2 3; do adb exec-out screencap -p > "$OUT/$1.png"; [ "$(wc -c < "$OUT/$1.png")" -gt 1000 ] && break; sleep 1; done; echo "  + $1.png"; }
adb shell am force-stop "$DBG"; adb shell monkey -p "$DBG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 4
cap 01-login
adb shell input tap 950 2226; sleep 1.2; cap 02-settings
echo "Captured $(ls "$OUT"/*.png|wc -l) frames"
