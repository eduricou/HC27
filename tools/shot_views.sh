#!/usr/bin/env bash
# Captures de Godot des dels angles fixos de tools/views.json, per comparar-les amb les de
# la web (node tools/shot_web.mjs). Obre una finestra de 1920x1080 uns segons.
# Ús: bash tools/shot_views.sh [angles=tots, separats per comes] [hores=tarda,nit] [qualitat=alta]
# Resultat: build/shots/godot/<angle>_<hora>.png
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

cams="${1:-tots}"
times="${2:-tarda,nit}"
quality="${3:-alta}"
"$GODOT" --path . --resolution 1920x1080 -- --scenario=views --cams="$cams" --times="$times" \
	--quality="$quality" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Captura|ERROR|WARNING|SCRIPT"
