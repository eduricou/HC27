#!/usr/bin/env bash
# Regenera les textures de l'estadi (assets/textures/stadium/*.png) i les importa.
# Ús: bash tools/bake_textures.sh
# Obre una finestra petita uns segons: per dibuixar text cal la GPU (no pot ser headless).
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

"$GODOT" --path . --resolution 320x180 -s res://tools/bake_textures.gd 2>&1 \
	| sed 's/\x1b\[[0-9;]*m//g' | grep -vE "^(Godot Engine|Vulkan|D3D12|OpenGL|$)"
"$GODOT" --headless --path . --import >/dev/null 2>&1
echo "Importat."
