#!/usr/bin/env bash
# Mesura els fps d'un partit CPU contra CPU amb la finestra a 1920x1080 i sense VSync.
# Ús: bash tools/bench.sh [segons=10] [qualitat=alta] [hora=nit] [res3d] [qset]
#   qualitat: baixa · mitjana · alta · ultra (src/game/quality.gd)
#   hora: tarda · nit
#   res3d: resolució 3D, p. ex. 2560x1440 (la finestra continua a 1080p i l'escena es
#          renderitza més gran i s'escala; serveix per estimar el cost de 1440p)
#   qset: canvis al preset per provar, p. ex. msaa=0,ssao=false (Quality.override)
# Obre una finestra durant uns segons. Necessita la GPU (no pot ser headless).
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

secs="${1:-10}"
quality="${2:-alta}"
time="${3:-nit}"
res3d="${4:-}"
qset="${5:-}"
extra=()
[ -n "$res3d" ] && extra+=(--res3d="$res3d")
[ -n "$qset" ] && extra+=(--qset="$qset")
"$GODOT" --path . --resolution 1920x1080 -- --scenario=bench --seconds="$secs" \
	--quality="$quality" --time="$time" "${extra[@]}" 2>&1 \
	| sed 's/\x1b\[[0-9;]*m//g' | grep -E "BENCH|ERROR|WARNING"
