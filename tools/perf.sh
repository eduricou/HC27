#!/usr/bin/env bash
# Rendiment d'un partit sencer: menú, partit CPU contra CPU (presentació, gols, repeticions,
# descansos i final) i tornada al menú, mesurant cada fotograma (PerfProbe). Falla si
# durant el partit hi ha algun fotograma de més de 50 ms (criteri de la fase 7).
# Ús: bash tools/perf.sh [qualitat=alta] [hora=nit] [qlen=40] [opcions...]
#   qualitat: baixa · mitjana · alta · ultra · hora: tarda · nit
#   qlen: segons de cada quart (un partit real en té 150)
#   opcions: --fresh (esborra les memòries cau de shaders, com en un PC on el joc no s'ha
#            obert mai) · --vsync (60 fps amb VSync, com es juga; per defecte, sense límit)
#            · --gpu-profile (temps de GPU per passades, a la consola)
#            · --no-warmup (sense l'escalfament de shaders del menú, per comparar)
#            · --d3d12 (Direct3D 12 en lloc de Vulkan) · --compat (renderitzador Compatibility,
#              OpenGL 3.3, el de les gràfiques antigues)
# Escriu els fotogrames a build/perf/<qualitat>_<hora>.csv. Obre una finestra a 1920x1080.
set -uo pipefail
source "$(dirname "$0")/_env.sh"
ensure_import

quality="${1:-alta}"
time="${2:-nit}"
qlen="${3:-40}"
shift $(( $# < 3 ? $# : 3 ))
godot_opts=()
game_opts=()
for o in "$@"; do
	case "$o" in
		--fresh)
			cache="$APPDATA/Godot/app_userdata/Estic Hoquei Herba"
			rm -rf "$cache/shader_cache" "$cache/vulkan" "$cache/d3d12"
			echo "Memòries cau de shaders esborrades."
			;;
		--vsync) game_opts+=(--vsync=1) ;;
		--gpu-profile) godot_opts+=(--gpu-profile) ;;
		--no-warmup) game_opts+=(--warmup=0) ;;
		--d3d12) godot_opts+=(--rendering-driver d3d12) ;;
		--compat) godot_opts+=(--rendering-method gl_compatibility) ;;
		*) echo "Opció desconeguda: $o" >&2; exit 2 ;;
	esac
done
"$GODOT" --path . --resolution 1920x1080 "${godot_opts[@]}" -- --scenario=perf \
	--quality="$quality" --time="$time" --qlen="$qlen" --seed=1 "${game_opts[@]}" 2>&1 \
	| sed 's/\x1b\[[0-9;]*m//g' | grep -E "PERF|ERROR|WARNING|SCRIPT|Vulkan|D3D12|OpenGL"
exit "${PIPESTATUS[0]}"
