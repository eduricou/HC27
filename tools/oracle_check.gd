# Compara la simulació de Godot amb les trajectòries de la web desades per
# tools/oracle_web.mjs (tests/fixtures/web_oracle.json).
# Ús: "$GODOT" --headless --path . -s res://tools/oracle_check.gd
# La prova tests/sim/test_oracle.gd fa servir les mateixes funcions.
extends SceneTree

const FIXTURE := "res://tests/fixtures/web_oracle.json"
## Es pot passar un altre fitxer: -- --fixture=<ruta>
const TOL := 1e-6


func _initialize() -> void:
	var path := FIXTURE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fixture="):
			path = a.substr(10)
	var data := load_fixture(path)
	var code := 0
	for run: Dictionary in data["runs"]:
		var r := compare_run(run)
		print(
			(
				"llavor %d (pc %d): %d de %d fotogrames iguals"
				% [run["seed"], run["pc"], r["ok_frames"], r["frames"]]
			)
		)
		if r["first_diff"] != "":
			print("  primera diferència: ", r["first_diff"])
			code = 1
	quit(code)


static func load_fixture(path: String = FIXTURE) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Simula com l'oracle i compara cada fotograma desat. Retorna quants coincideixen i la
## primera diferència (cadena buida si no n'hi ha).
static func compare_run(run: Dictionary) -> Dictionary:
	var sim := MatchSim.new(int(run["seed"]), float(run["qlen"]))
	var s := sim.s
	if int(run["pc"]) >= 0:
		s.intro_t = 0.0
		Rules.setup_pc(s, s.teams[int(run["pc"])], 1.0, &"test")
	var frames: Array = run["frames"]
	var ok_frames := 0
	var first_diff := ""
	var step := 0
	for f: Dictionary in frames:
		var target := int(f["step"])
		while step < target:
			if s.state == &"break":
				Rules.next_quarter(s)
			if s.state == &"full":
				break
			sim.step()
			step += 1
		var diff := compare_frame(s, f)
		if diff != "":
			first_diff = "pas %d: %s" % [target, diff]
			break
		ok_frames += 1
	sim.dispose()
	return {"ok_frames": ok_frames, "frames": frames.size(), "first_diff": first_diff}


static func compare_frame(s: MatchState, f: Dictionary) -> String:
	if String(s.state) != f["state"]:
		return "estat %s (web %s)" % [s.state, f["state"]]
	if s.quarter != int(f["q"]):
		return "quart %d (web %d)" % [s.quarter, f["q"]]
	if s.score[0] != int(f["score"][0]) or s.score[1] != int(f["score"][1]):
		return "marcador %s (web %s)" % [s.score, f["score"]]
	var owner := s.players.find(s.ball.owner) if s.ball.owner else -1
	if owner != int(f["owner"]):
		return "possessió %d (web %d)" % [owner, f["owner"]]
	if absf(s.clock - float(f["clock"])) > TOL:
		return "rellotge %f (web %f)" % [s.clock, f["clock"]]
	var b := s.ball
	var bv := [b.x, b.y, b.z, b.vx, b.vy, b.vz]
	var names := ["x", "y", "z", "vx", "vy", "vz"]
	for k in 6:
		if absf(float(bv[k]) - float(f["ball"][k])) > TOL:
			return "pilota.%s %.9f (web %.9f)" % [names[k], bv[k], f["ball"][k]]
	var pv: Array = f["p"]
	var pnames := ["x", "y", "vx", "vy", "face", "stamina"]
	for i in s.players.size():
		var p := s.players[i]
		var vals := [p.x, p.y, p.vx, p.vy, p.face, p.stamina]
		for k in 6:
			if absf(float(vals[k]) - float(pv[i * 6 + k])) > TOL:
				return (
					"jugador %d (%s).%s %.9f (web %.9f)"
					% [i, p.name, pnames[k], vals[k], pv[i * 6 + k]]
				)
	for key: String in ["shots", "on", "pcs", "fouls"]:
		var mine: Dictionary = s.stats_dict()
		if (
			int(mine[key][0]) != int(f["stats"][key][0])
			or int(mine[key][1]) != int(f["stats"][key][1])
		):
			return "estadística %s %s (web %s)" % [key, mine[key], f["stats"][key]]
	return ""
