# Simula N partits CPU contra CPU sense gràfics i en calcula les mitjanes per partit.
# S'executa amb `bash tools/sim.sh [N] [llavor] [qlen] [processos]`, que reparteix les
# llavors entre diversos processos de Godot i després en fusiona els resultats.
# (Amb fils dins d'un sol procés no escala: tots comparteixen els objectes de script.)
#
# Modes:
#   --n=N --seed=S --qlen=Q                    tots els partits en aquest procés
#   --n=N --seed=S --qlen=Q --part=i --parts=K només els partits i, i+K, i+2K…;
#                                              els desa a reports/sim_part_i.json
#   --n=N --seed=S --qlen=Q --merge=K          fusiona les K parts i fa el resum
#
# Contracte amb la simulació (src/sim/match_sim.gd):
#   var sim = MatchSim.new(llavor: int, qlen: float)
#   var r: Dictionary = sim.run_to_end()
#   r = {"score": [a, b], "stats": {"shots": [a, b], "on": [a, b], "pcs": [a, b],
#        "fouls": [a, b], "poss": [a, b]}}
#   sim.dispose()
# És el mateix format que retorna window.__estic.simulate() a la versió web,
# i el resum té les mateixes claus que reference/golden/stats_web.json.
#
# Codi de sortida: 0 si les mitjanes són dins de la tolerància, 1 si no, 2 si no hi ha
# simulació o falta alguna part. El rendiment (objectiu del pla: 50 partits en menys de
# 3 minuts repartits entre processos; vegeu docs/decisions/0003) s'informa però no fa fallar.
extends SceneTree

const SIM_PATH := "res://src/sim/match_sim.gd"
const GOLDEN_PATH := "res://reference/golden/stats_web.json"
const OUT_DIR := "res://reports"
const OUT_PATH := "res://reports/sim_stats.json"
const PART_PATH := "res://reports/sim_part_%d.json"
## Mètriques que han de quedar dins de la tolerància (pla, secció 1).
const GATED: Array[String] = ["goals", "shots", "pcs"]
const TOLERANCE := 0.20
## Objectiu de rendiment: 50 partits en menys de 3 minuts (docs/decisions/0003).
const TARGET_SECONDS_PER_50 := 180.0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var args := _parse_args(OS.get_cmdline_user_args())
	var n := int(args.get("n", "50"))
	var first_seed := int(args.get("seed", "1"))
	var qlen := float(args.get("qlen", "150"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	if args.has("merge"):
		return _merge(n, first_seed, qlen, int(args["merge"]))

	if not ResourceLoader.exists(SIM_PATH):
		printerr("sim: encara no existeix %s (es porta a la fase 1)" % SIM_PATH)
		return 2
	var sim_script: GDScript = load(SIM_PATH)
	var parts := int(args.get("parts", "1"))
	var part := int(args.get("part", "0"))

	var wall0 := Time.get_ticks_usec()
	var results: Array = []
	for i in range(part, n, parts):
		var t0 := Time.get_ticks_usec()
		var sim: Object = sim_script.new(first_seed + i, qlen)
		var r: Dictionary = sim.call("run_to_end")
		sim.call("dispose")
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		results.append({"i": i, "score": r["score"], "stats": r["stats"], "ms": ms})
	var wall_s := (Time.get_ticks_usec() - wall0) / 1e6

	if args.has("part"):
		var pf := FileAccess.open(PART_PATH % part, FileAccess.WRITE)
		pf.store_string(JSON.stringify({"results": results, "segons": wall_s}))
		return 0
	return _finish(results, n, first_seed, qlen, 1, wall_s)


## Llegeix les parts que han escrit els processos i fa el resum.
func _merge(n: int, first_seed: int, qlen: float, parts: int) -> int:
	var results: Array = []
	results.resize(n)
	var wall_s := 0.0
	for k in parts:
		var path := PART_PATH % k
		if not FileAccess.file_exists(path):
			printerr("sim: falta la part %d (%s)" % [k, path])
			return 2
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		wall_s = maxf(wall_s, data["segons"])
		for r: Dictionary in data["results"]:
			results[int(r["i"])] = r
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for r: Variant in results:
		if r == null:
			printerr("sim: falten partits a les parts")
			return 2
	return _finish(results, n, first_seed, qlen, parts, wall_s)


func _finish(
	results: Array, n: int, first_seed: int, qlen: float, procs: int, wall_s: float
) -> int:
	var matches: Array[Dictionary] = []
	var worst_ms := 0.0
	var total_ms := 0.0
	for r: Dictionary in results:
		worst_ms = maxf(worst_ms, r["ms"])
		total_ms += r["ms"]
		matches.append({"score": r["score"], "stats": r["stats"]})

	var out := summarize(matches)
	out["meta"] = {
		"font": "godot",
		"data": Time.get_datetime_string_from_system(),
		"n": n,
		"llavor": first_seed,
		"qlen": qlen,
		"processos": procs,
		"segons_totals": wall_s,
		"ms_per_partit": total_ms / maxf(1.0, n),
		"ms_pitjor_partit": worst_ms,
	}

	var code := 0
	var golden := _load_golden()
	if not golden.is_empty():
		var cmp := compare(out["mean"], golden["mean"])
		out["comparacio"] = cmp
		if not cmp["ok"]:
			code = 1

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
	_print_summary(out)
	return code


## Resum llegible per pantalla (el JSON complet va a reports/sim_stats.json).
static func _print_summary(out: Dictionary) -> void:
	var meta: Dictionary = out["meta"]
	var mean: Dictionary = out["mean"]
	var sd: Dictionary = out["sd"]
	print(
		(
			"%d partits · qlen %d s · llavors %d–%d · %d processos · %.1f s en total"
			% [
				meta["n"],
				meta["qlen"],
				meta["llavor"],
				meta["llavor"] + meta["n"] - 1,
				meta["processos"],
				meta["segons_totals"],
			]
		)
	)
	for key: String in ["goals", "shots", "on", "pcs", "fouls", "poss_iluro"]:
		var line := "  %-11s %7.2f ± %5.2f" % [key, mean[key], sd[key]]
		if out.has("comparacio") and out["comparacio"]["metriques"].has(key):
			var m: Dictionary = out["comparacio"]["metriques"][key]
			var verdict := "OK" if m["ok"] else "FORA"
			line += "   web %6.2f  %+6.1f %%  %s" % [m["web"], m["desviacio"] * 100.0, verdict]
		print(line)
	# Rendiment efectiu: temps total repartit entre els partits, i què trigarien 50.
	var n := maxf(1.0, float(meta["n"]))
	var per_50 := float(meta["segons_totals"]) / n * 50.0
	var note := "" if per_50 < TARGET_SECONDS_PER_50 else "  (objectiu: < 3 min)"
	print(
		(
			"  rendiment: %.1f s per partit efectiu · 50 partits ≈ %.1f min%s"
			% [per_50 / 50.0, per_50 / 60.0, note]
		)
	)
	print(
		(
			"  dins de cada procés: %.1f s per partit (pitjor %.1f s)"
			% [float(meta["ms_per_partit"]) / 1000.0, float(meta["ms_pitjor_partit"]) / 1000.0]
		)
	)
	if out.has("comparacio"):
		print("COMPARACIÓ AMB LA WEB: ", "OK" if out["comparacio"]["ok"] else "FORA DE TOLERÀNCIA")
		if int(meta["n"]) < 50:
			print("  (amb menys de 50 partits és orientativa: el soroll pot superar el ±20 %)")
	else:
		print("sim: no hi ha %s; no es compara amb la web" % GOLDEN_PATH)


## Mitjanes i desviacions per partit (els dos equips sumats), com golden_web.js.
static func summarize(matches: Array[Dictionary]) -> Dictionary:
	var rows: Array[Dictionary] = []
	for m in matches:
		var s: Dictionary = m["stats"]
		var poss: Array = s["poss"]
		var poss_total := float(poss[0]) + float(poss[1])
		var row := {
			"goals": _pair_sum(m["score"]),
			"shots": _pair_sum(s["shots"]),
			"on": _pair_sum(s["on"]),
			"pcs": _pair_sum(s["pcs"]),
			"fouls": _pair_sum(s["fouls"]),
			"poss_iluro": float(poss[0]) / poss_total if poss_total > 0.0 else 0.5,
		}
		rows.append(row)
	var mean := {}
	var sd := {}
	for key: String in ["goals", "shots", "on", "pcs", "fouls", "poss_iluro"]:
		var acc := 0.0
		for r in rows:
			acc += float(r[key])
		var mu := acc / maxf(1.0, rows.size())
		var var_acc := 0.0
		for r in rows:
			var_acc += pow(float(r[key]) - mu, 2.0)
		mean[key] = mu
		sd[key] = sqrt(var_acc / maxf(1.0, rows.size()))
	return {"n": rows.size(), "mean": mean, "sd": sd, "matches": matches}


## Compara les mitjanes amb les de la web. Desviació relativa: (godot - web) / web.
static func compare(ours: Dictionary, web: Dictionary) -> Dictionary:
	var rows := {}
	var ok := true
	for key: String in GATED:
		var ref := float(web.get(key, 0.0))
		var val := float(ours.get(key, 0.0))
		var dev := (val - ref) / ref if ref != 0.0 else 0.0
		var dins := absf(dev) <= TOLERANCE
		ok = ok and dins
		rows[key] = {"web": ref, "godot": val, "desviacio": dev, "ok": dins}
	return {"ok": ok, "toleranca": TOLERANCE, "metriques": rows}


static func _pair_sum(pair: Variant) -> float:
	var a: Array = pair
	return float(a[0]) + float(a[1])


static func _load_golden() -> Dictionary:
	if not FileAccess.file_exists(GOLDEN_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if data is Dictionary and (data as Dictionary).has("mean"):
		return data
	printerr("sim: %s no té el format esperat" % GOLDEN_PATH)
	return {}


static func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in user_args:
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
