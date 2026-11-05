#!/usr/bin/env bash
# Simula N partits CPU contra CPU sense gràfics i en treu les mitjanes per partit.
# Si existeix reference/golden/stats_web.json, hi compara les mitjanes (±20 %).
# Ús: bash tools/sim.sh [N=50] [llavor=1] [qlen=150] [processos=nuclis]
#   qlen: durada real de cada quart en segons (la web en fa servir 150 per defecte).
#   processos: partits simultanis, cada un en un procés de Godot. Amb 1 tots van
#     un darrere l'altre (serveix per mesurar el temps d'un partit).
# Resultat: resum per pantalla i JSON complet a reports/sim_stats.json.
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

n="${1:-50}"
seed="${2:-1}"
qlen="${3:-150}"
procs="${4:-$(nproc 2>/dev/null || echo 4)}"
[ "$procs" -gt "$n" ] && procs="$n"

base=(--n="$n" --seed="$seed" --qlen="$qlen")
if [ "$procs" -le 1 ]; then
	"$GODOT" --headless --path . -s res://tools/sim_stats.gd -- "${base[@]}" 2>&1 | grep -v "^Godot Engine"
	exit "${PIPESTATUS[0]}"
fi

mkdir -p reports
pids=()
for ((k = 0; k < procs; k++)); do
	"$GODOT" --headless --path . -s res://tools/sim_stats.gd -- "${base[@]}" --part="$k" --parts="$procs" \
		>"reports/sim_part_$k.log" 2>&1 &
	pids+=($!)
done
fail=0
for k in "${!pids[@]}"; do
	if ! wait "${pids[$k]}"; then
		echo "sim: el procés $k ha fallat (vegeu reports/sim_part_$k.log)" >&2
		fail=1
	fi
done
[ $fail -ne 0 ] && exit 2
rm -f reports/sim_part_*.log
"$GODOT" --headless --path . -s res://tools/sim_stats.gd -- "${base[@]}" --merge="$procs" 2>&1 | grep -v "^Godot Engine"
exit "${PIPESTATUS[0]}"
