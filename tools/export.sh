#!/usr/bin/env bash
# Exporta l'executable de Windows (preset "Windows Desktop") i el comprimeix en un zip.
# Ús: bash tools/export.sh [release|debug]
# Resultat: build/windows/EsticHoqueiHerba.exe i build/EsticHoqueiHerba-<versió>-win64.zip
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

mode="${1:-release}"
case "$mode" in
release | debug) ;;
*)
	echo "ús: bash tools/export.sh [release|debug]" >&2
	exit 2
	;;
esac

out_dir="build/windows"
exe="$out_dir/EsticHoqueiHerba.exe"
mkdir -p "$out_dir"

"$GODOT" --headless --path . --export-"$mode" "Windows Desktop" "$exe"
rc=$?
if [ $rc -ne 0 ] || [ ! -f "$exe" ]; then
	echo "EXPORTACIÓ: ha fallat (codi $rc)" >&2
	exit 1
fi

version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
zip="build/EsticHoqueiHerba-${version:-0.0.0}-win64.zip"
powershell.exe -NoProfile -Command \
	"Compress-Archive -Path '$out_dir/*' -DestinationPath '$zip' -Force" || exit 1

echo "EXPORTACIÓ: OK"
echo "  $exe"
echo "  $zip"
