#!/usr/bin/env bash
# Executa les proves amb gdUnit4 en mode headless.
# Ús: bash tools/test.sh                         (tota la suite: tests/)
#     bash tools/test.sh tests/sim/test_rules.gd (un fitxer o una carpeta)
# Informe HTML i JUnit a reports/. Surt amb codi 0 només si tot passa.
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(tests)

args=()
for t in "${targets[@]}"; do
	args+=(-a "res://${t#res://}")
done

# --remote-debug a un port tancat evita que Godot obri el depurador
# interactiu si un script no compila (ho fa igual el runtest.sh de gdUnit4).
# Godot avisa que no s'hi pot connectar; aquests dos avisos s'amaguen.
"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	"${args[@]}" --ignoreHeadlessMode -c -rd res://reports -rc 5 \
	2> >(grep -v -E "remote port number must be|Unable to connect to host '127.0.0.1:0'" >&2)
rc=$?

"$GODOT" --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd \
	"${args[@]}" -rd res://reports >/dev/null 2>&1

if [ $rc -eq 0 ]; then
	echo "PROVES: OK"
else
	echo "PROVES: FALLEN (codi $rc). Informe: reports/"
fi
exit $rc
