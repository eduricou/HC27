# Proves de la base de la simulació: atzar, geometria i equips, comparades amb els valors
# que treu tools/oracle_web.mjs del codi original (tests/fixtures/web_oracle.json).
extends GdUnitTestSuite

const OracleCheck := preload("res://tools/oracle_check.gd")

var _fx: Dictionary


func before() -> void:
	_fx = OracleCheck.load_fixture()


func test_rng_igual_que_la_web() -> void:
	var r := SimRng.new(int(_fx["rng"]["seed"]))
	for v: float in _fx["rng"]["values"]:
		assert_float(r.rand()).is_equal_approx(v, 1e-15)
	assert_int(r.calls).is_equal(_fx["rng"]["values"].size())


func test_rng_mateixa_llavor_mateixa_sequencia() -> void:
	var a := SimRng.new(99)
	var b := SimRng.new(99)
	for i in 100:
		assert_float(a.rand()).is_equal(b.rand())


func test_in_circle() -> void:
	for c: Dictionary in _fx["geometry"]["circle"]:
		var x := float(c["x"])
		var y := float(c["y"])
		var side := int(c["side"])
		(
			assert_bool(Constants.in_circle(x, y, side))
			. override_failure_message("in_circle(%s, %s, %d)" % [x, y, side])
			. is_equal(c["r14"])
		)
		assert_bool(Constants.in_circle(x, y, side, Constants.DR)).is_equal(c["r19"])


func test_push_to_dotted() -> void:
	for c: Dictionary in _fx["geometry"]["dotted"]:
		var out := Constants.push_to_dotted(float(c["x"]), float(c["y"]), int(c["side"]))
		assert_float(out[0]).is_equal_approx(float(c["out"][0]), 1e-12)
		assert_float(out[1]).is_equal_approx(float(c["out"][1]), 1e-12)


func test_ang_diff() -> void:
	for c: Dictionary in _fx["geometry"]["angDiff"]:
		var d := Constants.ang_diff(float(c["a"]), float(c["b"]))
		assert_float(d).is_equal_approx(float(c["d"]), 1e-12)


func test_plantilles_iguals_que_la_web() -> void:
	for idx in 2:
		var web: Dictionary = _fx["teams"][idx]
		var td := TeamData.load_default(idx)
		assert_str(td.id).is_equal(web["id"])
		assert_str(td.name).is_equal(web["name"])
		assert_int(td.squad.size()).is_equal(web["squad"].size())
		for k in td.squad.size():
			var mine: Array = td.squad[k]
			var theirs: Array = web["squad"][k]
			assert_int(mine.size()).is_equal(theirs.size())
			for j in mine.size():
				# El JSON llegeix tots els números com a float.
				if theirs[j] is String:
					assert_str(mine[j]).is_equal(theirs[j])
				else:
					assert_float(float(mine[j])).is_equal(float(theirs[j]))


func test_valoracions() -> void:
	for idx in 2:
		var web: Dictionary = _fx["teams"][idx]
		var td := TeamData.load_default(idx)
		assert_int(td.team_ovr()).is_equal(int(web["ovr"]))
		for k in td.squad.size():
			assert_float(TeamData.ovr_of(td.squad[k])).is_equal_approx(
				float(web["players"][k]), 1e-9
			)


func test_equip_1433() -> void:
	var t := Team.new(TeamData.load_default(0), 0, SimRng.new(1))
	assert_int(t.dir).is_equal(1)
	assert_int(t.players.size()).is_equal(11)
	assert_object(t.gk).is_same(t.players[0])
	var count := {Player.DF: 0, Player.MF: 0, Player.FW: 0}
	for p in t.players:
		if p.is_gk:
			assert_bool(p.has_slot).is_false()
			continue
		assert_bool(p.has_slot).is_true()
		count[p.role] += 1
		assert_float(p.max_speed).is_equal_approx(5.0 + p.spd / 100.0 * 2.7, 1e-12)
	assert_int(count[Player.DF]).is_equal(4)
	assert_int(count[Player.MF]).is_equal(3)
	assert_int(count[Player.FW]).is_equal(3)
	# El davanter centre (posició y = 0) és qui fa el servei.
	assert_str(t.players[9].name).is_equal("Martí Pujol")
	assert_float(t.players[9].slot_y).is_equal(0.0)
	assert_int(Team.new(TeamData.load_default(1), 1, SimRng.new(1)).dir).is_equal(-1)
