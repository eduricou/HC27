# Proves de partit sencer: determinisme, format del resultat, esdeveniments i repetició.
extends GdUnitTestSuite


func _run(seed_value: int, qlen: float) -> Dictionary:
	var sim := MatchSim.new(seed_value, qlen)
	var r := sim.run_to_end()
	var b := sim.s.ball
	r["final"] = [b.x, b.y, sim.s.players[5].x, sim.s.players[17].y, sim.s.rng.calls]
	sim.dispose()
	return r


func test_mateixa_llavor_mateix_partit() -> void:
	var a := _run(42, 30.0)
	var b := _run(42, 30.0)
	assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))


func test_llavors_diferents_partits_diferents() -> void:
	var a := _run(42, 30.0)
	var b := _run(43, 30.0)
	assert_str(JSON.stringify(a)).is_not_equal(JSON.stringify(b))


func test_format_del_resultat() -> void:
	var r := _run(3, 20.0)
	assert_str(r["state"]).is_equal("full")
	assert_int(r["quarter"]).is_equal(4)
	assert_int(r["score"].size()).is_equal(2)
	for key: String in ["poss", "shots", "on", "pcs", "fouls"]:
		assert_bool(r["stats"].has(key)).is_true()
		assert_int(r["stats"][key].size()).is_equal(2)
	# Xuts a porteria ≤ xuts, i la possessió suma menys que el temps jugat.
	for k in 2:
		assert_int(int(r["stats"]["on"][k])).is_less_equal(int(r["stats"]["shots"][k]))
	var poss: Array = r["stats"]["poss"]
	assert_float(float(poss[0]) + float(poss[1])).is_less(4 * 20.0 * 1.5)


func test_gol_repeticio_i_servei_del_rival() -> void:
	# Amb la llavor 1, l'Iluro marca al primer minut (com a la web: vegeu l'oracle).
	var sim := MatchSim.new(1, 150.0)
	var s := sim.s
	var seen := {}
	var scorer_team := -1
	for i in 3000:
		sim.step()
		for e in s.events:
			seen[e["type"]] = true
			if e["type"] == &"goal":
				scorer_team = e["team"]
		if s.state == &"replay":
			break
	assert_str(s.state).is_equal("replay")
	assert_int(s.replay_len).is_equal(ReplayBuffer.REPLAY_FRAMES)
	for t: StringName in [&"intro_end", &"kick", &"whistle", &"goal", &"wipe", &"replay_start"]:
		assert_bool(seen.has(t)).override_failure_message("falta l'esdeveniment " + t).is_true()
	var steps := 0
	while s.state == &"replay" and steps < 1000:
		sim.step()
		steps += 1
	# La repetició dura uns 10 s (300 fotogrames a mitja velocitat) i després serveix
	# l'equip que ha rebut el gol.
	assert_int(steps).is_between(590, 625)
	assert_str(s.restart_type).is_equal("center")
	assert_int(s.restart_team.idx).is_equal(1 - scorer_team)
	sim.dispose()


func test_saltar_la_repeticio() -> void:
	var sim := MatchSim.new(1, 150.0)
	var s := sim.s
	for i in 3000:
		sim.step()
		if s.state == &"replay":
			break
	s.input.pass_e = true
	sim.step()
	var steps := 1
	while s.state == &"replay" and steps < 100:
		sim.step()
		steps += 1
	assert_int(steps).is_less(30)
	sim.dispose()


func test_dispose_trenca_les_referencies() -> void:
	var sim := MatchSim.new(1, 150.0)
	var p := sim.s.players[3]
	sim.dispose()
	assert_object(p.team).is_null()
	assert_int(sim.s.players.size()).is_equal(0)
