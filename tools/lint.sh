#!/usr/bin/env bash
# Format i lint del GDScript propi (no toca addons/ de tercers).
# Ús: bash tools/lint.sh        (només comprova)
#     bash tools/lint.sh --fix  (reformata els fitxers i després fa el lint)
set -euo pipefail
cd "$(dirname "$0")/.."
# Força UTF-8 a Python perquè gdformat no espatlli els accents a Windows.
export PYTHONUTF8=1

# gdtoolkit: les ordres del PATH o, si no hi són, el mòdul de Python.
if command -v gdformat >/dev/null 2>&1; then GDFORMAT=(gdformat); else GDFORMAT=(python -m gdtoolkit.formatter); fi
if command -v gdlint >/dev/null 2>&1; then GDLINT=(gdlint); else GDLINT=(python -m gdtoolkit.linter); fi

dirs=()
for d in src tests tools; do [ -d "$d" ] && dirs+=("$d"); done
mapfile -t files < <(find "${dirs[@]}" -name '*.gd' -type f | sort)

if [ ${#files[@]} -eq 0 ]; then
	echo "LINT: cap fitxer .gd"
	exit 0
fi

if [ "${1:-}" = "--fix" ]; then
	"${GDFORMAT[@]}" "${files[@]}"
	# A Windows, gdformat escriu CRLF; el projecte fa servir LF.
	sed -i 's/\r$//' "${files[@]}"
else
	"${GDFORMAT[@]}" --check "${files[@]}"
fi
"${GDLINT[@]}" "${files[@]}"
echo "LINT: OK (${#files[@]} fitxers)"
