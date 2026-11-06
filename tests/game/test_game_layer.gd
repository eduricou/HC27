# Proves de la capa de joc de la fase 2 que no necessiten pantalla: entrada, coordenades,
# HUD i el MatchRunner (pausa, descansos i final). L'estadi: test_stadium.gd.
extends GdUnitTestSuite

const HL := Constants.HL
const HW := Constants.HW

# --- Entrada ----------------------------------------------------------------------


func test_accions_registrades_amb_teclat_i_comandament() -> void:
	InputActions.reset()
	InputActions.ensure()  # dues vegades no ha de duplicar res
	for action: StringName in InputActions.ACTIONS:
		assert_bool(InputMap.has_action(action)).is_true()
		var events := InputMap.action_get_events(action)
		var d: Dictionary = InputActions.DEFAULTS[action]
		assert_int(events.size()).is_equal(d["keys"].size() + d["pad"].size())
		var has_key := false
		var has_pad := false
		for e in events:
			has_key = has_key or e is InputEventKey
			has_pad = has_pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		assert_bool(has_key and has_pad).override_failure_message(String(action)).is_true()
	assert_bool(InputMap.has_action(InputActions.SKIP)).is_true()


func test_entrada_humana_normalitza_la_direccio() -> void:
	var inp := SimInput.new()
	HumanController.compose(inp, Vector2(1.0, 1.0), true, true, true, false, true)
	assert_float(inp.mv.length()).is_equal_approx(1.0, 1e-5)
	assert_bool(inp.sprint).is_true()
	assert_bool(inp.shoot_held).is_true()
	assert_bool(inp.pass_e).is_true()
	assert_bool(inp.shoot_e).is_false()
	assert_bool(inp.shoot_up_e).is_true()
	HumanController.compose(inp, Vector2(0.3, 0.0), false, false, false, false, false)
	assert_float(inp.mv.x).is_equal_approx(0.3, 1e-6)


# --- Coordenades ------------------------------------------------------------------


func test_coordenades_de_la_vista() -> void:
	assert_vector(Coords.to_view(1.0, 2.0, 3.0)).is_equal(Vector3(1.0, 3.0, 2.0))


func test_orientacio_dels_jugadors() -> void:
	var n := Node3D.new()
	for face: float in [0.0, 0.7, PI * 0.5, 2.5, -1.2, PI]:
		n.rotation = Vector3(0.0, Coords.face_to_yaw(face), 0.0)
		var fwd := -n.basis.z
		# El −Z local ha d'apuntar cap a (cos face, sin face) de la simulació.
		assert_float(fwd.x).is_equal_approx(cos(face), 1e-5)
		assert_float(fwd.z).is_equal_approx(sin(face), 1e-5)
	n.free()


# --- HUD --------------------------------------------------------------------------


func test_rellotge() -> void:
	assert_str(Hud.fmt_clock(900.0)).is_equal("15:00")
	assert_str(Hud.fmt_clock(59.2)).is_equal("1:00")
	assert_str(Hud.fmt_clock(65.0)).is_equal("1:05")
	assert_str(Hud.fmt_clock(0.0)).is_equal("0:00")


func test_indicacio_del_servei_per_a_l_huma() -> void:
	var sim := MatchSim.new(1, 150.0, 0)
	var s := sim.s
	s.intro_t = 0.0
	assert_object(s.ctrl).is_same(s.restart_taker)
	s.state_t = 0.5
	assert_str(Hud.hint_text(s)).is_empty()
	s.state_t = 1.3
	assert_str(Hud.hint_text(s)).is_equal("PASSA per fer el servei")
	sim.dispose()


# --- MatchRunner --------------------------------------------------------------------


func _runner(side: int) -> MatchRunner:
	var r: MatchRunner = auto_free(MatchRunner.new())
	r.start(1, 150.0, side, "normal")
	r.sim.s.intro_t = 0.0
	return r


## Porta el partit al final del quart actual.
func _end_quarter(r: MatchRunner) -> void:
	r.sim.s.state = &"play"
	r.sim.s.clock = 0.001
	r.tick()


func test_cpu_continua_sola_despres_de_5_s() -> void:
	var r := _runner(-1)
	var breaks := [0]
	var starts := [0]
	r.quarter_break.connect(func() -> void: breaks[0] += 1)
	r.quarter_started.connect(func() -> void: starts[0] += 1)
	_end_quarter(r)
	assert_str(r.sim.s.state).is_equal("break")
	assert_int(breaks[0]).is_equal(1)
	var ticks := 0
	while r.sim.s.state == &"break" and ticks < 1000:
		r.tick()
		ticks += 1
	assert_int(ticks).is_between(299, 302)
	assert_int(r.sim.s.quarter).is_equal(2)
	assert_int(starts[0]).is_equal(1)
	r.stop()


func test_huma_espera_el_boto_al_descans() -> void:
	var r := _runner(0)
	_end_quarter(r)
	for i in 600:
		r.tick()
	assert_str(r.sim.s.state).is_equal("break")
	r.next_quarter()
	assert_int(r.sim.s.quarter).is_equal(2)
	assert_str(r.sim.s.state).is_equal("restart")
	r.stop()


func test_final_del_partit() -> void:
	var r := _runner(-1)
	var fulls := [0]
	r.full_time.connect(func() -> void: fulls[0] += 1)
	r.sim.s.quarter = 4
	_end_quarter(r)
	assert_str(r.sim.s.state).is_equal("full")
	assert_int(fulls[0]).is_equal(1)
	var t := r.sim.s.time
	r.tick()
	assert_float(r.sim.s.time).is_equal(t)
	r.stop()


func test_pausa_atura_la_simulacio() -> void:
	var r := _runner(-1)
	r.tick()
	var t := r.sim.s.time
	r.paused = true
	for i in 30:
		r.tick()
	assert_float(r.sim.s.time).is_equal(t)
	r.paused = false
	r.tick()
	assert_float(r.sim.s.time).is_greater(t)
	r.stop()


func test_sense_entrada_el_jugador_no_es_mou_sol() -> void:
	var r := _runner(0)
	r.sim.s.input.mv = Vector2(1.0, 0.0)
	r.sim.s.input.sprint = true
	r.input_enabled = false
	r.tick()
	assert_vector(r.sim.s.input.mv).is_equal(Vector2.ZERO)
	assert_bool(r.sim.s.input.sprint).is_false()
	r.stop()


func test_esdeveniments_de_cada_pas() -> void:
	var r := _runner(-1)
	var seen := {}
	r.stepped.connect(
		func(events: Array[Dictionary]) -> void:
			for e in events:
				seen[e["type"]] = true
	)
	for i in 600:
		r.tick()
	assert_bool(seen.has(&"kick")).is_true()
	r.stop()
