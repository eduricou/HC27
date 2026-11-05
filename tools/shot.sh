#!/usr/bin/env bash
# Executa el joc uns quants fotogrames i en desa captures PNG per revisar-les.
# Ús: bash tools/shot.sh [escenari=menu] [fotogrames=120]
#   L'escenari arriba al joc com a argument d'usuari (--scenario=<nom>);
#   a partir de la fase 2 el llegirà game/main.gd per col·locar la càmera.
# Resultat: build/shots/<escenari>/frameNNNNNNNN.png (es mostra l'últim).
# No pot ser headless: necessita la GPU per renderitzar.
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

scenario="${1:-menu}"
frames="${2:-120}"
out="build/shots/$scenario"
mkdir -p "$out"

"$GODOT" --path . --resolution 1920x1080 --write-movie "$out/frame.png" \
	--fixed-fps 60 --quit-after "$frames" -- --scenario="$scenario" >/dev/null 2>&1
rc=$?

last="$(ls "$out"/frame*.png 2>/dev/null | sort | tail -1)"
if [ -z "$last" ]; then
	echo "error: no s'ha generat cap captura (codi $rc)" >&2
	exit 1
fi
echo "Captura: $last"
