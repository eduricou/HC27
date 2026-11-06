#!/usr/bin/env bash
# Grava el so d'un partit amb el Movie Maker de Godot (amb gols, xiulet i públic) i
# comprova que no satura (tools/audio_check.gd). Necessita finestra (no és headless).
# Ús: bash tools/audio_check.sh [segons=60] [llavor=1]
#   La llavor 1 té tres gols en els primers 55 s de joc.
# Resultat: build/audio/so.wav (es pot escoltar) i el resum per pantalla.
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

secs="${1:-60}"
seed="${2:-1}"
out="build/audio"
rm -rf "$out"
mkdir -p "$out"
frames=$((secs * 60))

"$GODOT" --path . --resolution 640x360 --write-movie "$out/so.png" --fixed-fps 60 \
	--quit-after "$frames" -- --scenario=audio --seed="$seed" >"$out/registre.log" 2>&1
rm -f "$out"/so*.png
if [ ! -f "$out/so.wav" ]; then
	echo "error: no s'ha gravat el so (vegeu $out/registre.log)" >&2
	exit 1
fi
"$GODOT" --headless --path . -s res://tools/audio_check.gd -- "$out/so.wav" 2>&1 | grep -E "^SO"
exit "${PIPESTATUS[0]}"
