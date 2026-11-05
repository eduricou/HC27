#!/usr/bin/env bash
# Recorregut complet sense pantalla: partit amb quarts de 40 s (CPU contra CPU i amb un
# humà automàtic) → descansos → final → menú. Falla si no acaba o si la consola mostra
# algun error.
# Ús: bash tools/smoke.sh
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

rc=0
for scenario in smoke smoke_human; do
	log="reports/$scenario.log"
	"$GODOT" --headless --path . --fixed-fps 60 -- --scenario="$scenario" >"$log" 2>&1
	code=$?
	sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "^(Partit nou|SMOKE)" | sed "s/^/[$scenario] /"
	if grep -qE "SCRIPT ERROR|^ERROR|USER ERROR|WARNING" "$log"; then
		echo "[$scenario] la consola mostra errors o avisos:" >&2
		grep -E -A3 "SCRIPT ERROR|^ERROR|USER ERROR|WARNING" "$log" | head -40 >&2
		rc=1
	fi
	if [ $code -ne 0 ] || ! grep -q "SMOKE OK" "$log"; then
		echo "[$scenario] FALLA (codi $code). Registre: $log" >&2
		rc=1
	fi
done
[ $rc -eq 0 ] && echo "SMOKE: OK"
exit $rc
