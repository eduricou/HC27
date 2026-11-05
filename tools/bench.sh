#!/usr/bin/env bash
# Mesura els fps d'un partit CPU contra CPU amb la finestra a 1920x1080 i sense VSync.
# Ús: bash tools/bench.sh [segons=10]
# Obre una finestra durant uns segons. Necessita la GPU (no pot ser headless).
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

secs="${1:-10}"
"$GODOT" --path . --resolution 1920x1080 -- --scenario=bench --seconds="$secs" 2>&1 \
	| sed 's/\x1b\[[0-9;]*m//g' | grep -E "BENCH|ERROR|WARNING"
