#!/usr/bin/env bash
# Entorn comú dels scripts de tools/. Es carrega amb `source tools/_env.sh`.
# Deixa el directori de treball a l'arrel del projecte i defineix $GODOT.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Si la variable d'entorn GODOT no hi és (p. ex. un terminal obert abans
# d'instal·lar Godot), es fa servir la ruta fixa del pla (secció 3.2).
GODOT="${GODOT:-/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
if [ ! -f "$GODOT" ]; then
	echo "error: no trobo Godot a '$GODOT'. Defineix la variable GODOT (pla, secció 3.2)." >&2
	exit 1
fi
export GODOT

# build/ i reports/ són sortides: el .gdignore fa que Godot no les importi ni les exporti.
mkdir -p build reports
[ -f build/.gdignore ] || touch build/.gdignore
[ -f reports/.gdignore ] || touch reports/.gdignore

# Importa els recursos si encara no hi ha la memòria cau del projecte (.godot/).
ensure_import() {
	if [ ! -f .godot/global_script_class_cache.cfg ]; then
		echo "Important el projecte per primer cop..."
		"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
	fi
}
