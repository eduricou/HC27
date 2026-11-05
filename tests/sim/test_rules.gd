# Proves de les regles (pla, secció 9, fase 1). L'Iluro (equip 0) ataca cap a x positiva
# i el Polo (equip 1) cap a x negativa.
extends GdUnitTestSuite

const HL := Constants.HL
const HW := Constants.HW
const GHW := Constants.GHW

var sim: MatchSim
var s: MatchState
var iluro: Team
var polo: Team


func before_test() -> void:
	sim = SimHelpers.new_sim()
	s = sim.s
	iluro = s.teams[0]
	polo = s.teams[1]
	SimHelpers.clear_field(s)


func after_test() -> void:
	sim.dispose()


# --- Gols -------------------------------------------------------------------------


func test_gol_valid_si_el_toc_es_dins_del_cercle() -> void:
	var p := iluro.players[9]
	SimHelpers.set_ball(s, 40.5, 0.0)
	BallActions.touch(s, p)
	assert_object(s.ball.valid_for).is_same(iluro)
	SimHelpers.set_ball(s, HL + 0.1, 0.5)
	Rules.check_bounds(s)
	assert_str(s.state).is_equal("goal")
	assert_int(s.score[0]).is_equal(1)
	assert_str(s.goals[0]["name"]).is_equal(p.name)
	assert_object(s.next_center).is_same(polo)


func test_gol_anullat_si_el_toc_es_fora_del_cercle() -> void:
	var p := iluro.players[9]
	SimHelpers.set_ball(s, 25.5, 0.0)
	BallActions.touch(s, p)
	assert_object(s.ball.valid_for).is_null()
	SimHelpers.set_ball(s, HL + 0.1, 0.5)
	Rules.check_bounds(s)
	assert_int(s.score[0]).is_equal(0)
	assert_str(s.state).is_equal("restart")
	assert_str(s.restart_type).is_equal("hitout")
	assert_object(s.restart_team).is_same(polo)
	assert_float(s.ball.x).is_equal_approx(HL - 14.63, 1e-9)


func test_un_toc_fora_del_cercle_anulla_la_validesa() -> void:
	var p := iluro.players[9]
	SimHelpers.set_ball(s, 40.5, 0.0)
	BallActions.touch(s, p)
	assert_object(s.ball.valid_for).is_same(iluro)
	SimHelpers.set_ball(s, 25.0, 0.0)
	BallActions.touch(s, p)
	assert_object(s.ball.valid_for).is_null()


func test_la_pilota_per_sobre_de_la_porteria_no_es_gol() -> void:
	SimHelpers.set_ball(s, 40.5, 0.0)
	BallActions.touch(s, iluro.players[9])
	SimHelpers.set_ball(s, HL + 0.1, 0.5, 0.0, 0.0, Constants.GH + 0.1)
	Rules.check_bounds(s)
	assert_int(s.score[0]).is_equal(0)
	assert_str(s.restart_type).is_equal("hitout")


# --- Sortides de la pilota --------------------------------------------------------


func test_sortida_de_fons_per_l_atacant() -> void:
	SimHelpers.set_ball(s, 30.0, 10.0)
	BallActions.touch(s, iluro.players[9])
	SimHelpers.set_ball(s, HL + 0.2, 10.0)
	Rules.check_bounds(s)
	assert_str(s.restart_type).is_equal("hitout")
	assert_object(s.restart_team).is_same(polo)
	assert_float(s.ball.x).is_equal_approx(HL - 14.63, 1e-9)
	assert_float(s.ball.y).is_equal_approx(10.0, 1e-9)


func test_corner_llarg_a_la_linia_de_23_m() -> void:
	# L'últim toc és del defensor: córner llarg per a l'atacant a la línia de 23 m.
	SimHelpers.set_ball(s, 30.0, 10.0)
	BallActions.touch(s, polo.players[2])
	SimHelpers.set_ball(s, HL + 0.2, -26.9)
	Rules.check_bounds(s)
	assert_str(s.restart_type).is_equal("long")
	assert_object(s.restart_team).is_same(iluro)
	assert_float(s.ball.x).is_equal_approx(Constants.L23, 1e-9)
	assert_float(s.ball.y).is_equal_approx(-HW + 1.0, 1e-9)


func test_treta_de_banda_per_al_rival() -> void:
	SimHelpers.set_ball(s, 5.0, 20.0)
	BallActions.touch(s, iluro.players[6])
	SimHelpers.set_ball(s, 5.0, HW + 0.1)
	Rules.check_bounds(s)
	assert_str(s.restart_type).is_equal("side")
	assert_object(s.restart_team).is_same(polo)
	assert_float(s.ball.x).is_equal_approx(5.0, 1e-9)
	assert_float(s.ball.y).is_equal_approx(HW - 0.05, 1e-9)
	# Qui treu queda darrere de la pilota i els rivals, a 5 m com a mínim.
	assert_object(s.restart_taker.team).is_same(polo)
	sim.step()
	for p in iluro.players:
		var d := Vector2(p.x - s.ball.x, p.y - s.ball.y).length()
		assert_float(d).is_greater_equal(4.999)


# --- Faltes -----------------------------------------------------------------------


func test_falta_al_mig_del_camp_es_cop_franc() -> void:
	Rules.foul(s, polo.players[5], 0.0, 5.0)
	assert_int(s.stat_fouls[1]).is_equal(1)
	assert_str(s.restart_type).is_equal("free")
	assert_object(s.restart_team).is_same(iluro)
	assert_float(s.ball.x).is_equal_approx(0.0, 1e-9)
	assert_float(s.ball.y).is_equal_approx(5.0, 1e-9)


func test_falta_a_prop_del_cercle_va_a_la_linia_discontinua() -> void:
	Rules.foul(s, polo.players[5], 28.0, 0.0)
	assert_str(s.restart_type).is_equal("free")
	assert_float(s.ball.x).is_equal_approx(HL - Constants.DR, 1e-9)
	assert_float(s.ball.y).is_equal_approx(0.0, 1e-9)


func test_falta_del_defensor_dins_del_cercle_es_penal_corner() -> void:
	Rules.foul(s, polo.players[2], 40.0, 3.0)
	assert_str(s.state).is_equal("pc")
	assert_object(s.pc_team).is_same(iluro)
	assert_int(s.stat_pcs[0]).is_equal(1)
	assert_int(s.stat_fouls[1]).is_equal(1)


func test_peu_dins_del_cercle_es_penal_corner_un_30_per_cent() -> void:
	# Un defensor del Polo rep al seu cercle una pilota ràpida que ve de l'Iluro: la
	# referència xiula peu (penal córner) amb probabilitat 0,3.
	var d := polo.players[2]
	var pcs := 0
	var trials := 400
	for i in trials:
		SimHelpers.clear_field(s)
		s.state = &"play"
		s.pc_live = false
		d.x = 40.0
		d.y = 0.0
		d.face = 0.0
		d.kick_cd = 0.0
		BallActions.stick_pt(s, d)
		SimHelpers.set_ball(s, s.st_x, s.st_y, 10.0, 0.0)
		s.ball.last_team = iluro
		s.ball.pc_pending = false
		var before := s.stat_pcs[0]
		MatchSim.pickup(s)
		if s.stat_pcs[0] > before:
			pcs += 1
			assert_str(s.state).is_equal("pc")
	var rate := float(pcs) / trials
	assert_float(rate).is_between(0.22, 0.38)


# --- Penal córner -----------------------------------------------------------------


func test_penal_corner_posicions() -> void:
	Rules.setup_pc(s, iluro, 1.0, &"test")
	assert_str(s.state).is_equal("pc")
	assert_bool(s.ball.pc_pending).is_true()
	assert_float(s.ball.x).is_equal_approx(HL - 0.05, 1e-9)
	assert_float(s.ball.y).is_equal_approx(GHW + 10.0, 1e-9)
	# Xuta qui té més xut; injecta qui té més passada.
	assert_str(s.pc_hit.name).is_equal("Martí Pujol")
	assert_float(s.pc_hit.x).is_equal_approx(HL - 15.7, 1e-9)
	assert_str(s.pc_inj.name).is_equal("Oriol Bosch")
	assert_float(s.pc_inj.x).is_equal_approx(HL + 0.8, 1e-9)
	# Quatre defensors a la línia de fons, per defensa i en ordre estable.
	var expected := {"Lluc Mas": 2.6, "Adrià Valls": 1.0, "Pau Torrent": -1.2, "Gerard Sala": -2.7}
	for p in polo.players:
		if expected.has(p.name):
			assert_float(p.x).is_equal_approx(HL + 0.35, 1e-9)
			assert_float(p.y).is_equal_approx(expected[p.name], 1e-9)
	assert_float(polo.gk.x).is_equal_approx(HL - 0.3, 1e-9)


func test_penal_corner_injeccio_al_que_xuta() -> void:
	Rules.setup_pc(s, iluro, 1.0, &"test")
	var steps := 0
	while s.state == &"pc" and steps < 200:
		sim.step()
		steps += 1
	assert_str(s.state).is_equal("play")
	assert_int(steps).is_between(108, 110)
	assert_bool(s.pc_live).is_true()
	assert_object(s.ball.pass_target).is_same(s.pc_hit)
	assert_float(s.ball.vx).is_less(0.0)


func test_penal_corner_el_gol_no_val_fins_que_la_pilota_surt_del_cercle() -> void:
	Rules.setup_pc(s, iluro, 1.0, &"test")
	var p := s.pc_hit
	SimHelpers.set_ball(s, 40.0, 0.0)
	BallActions.touch(s, p)
	assert_object(s.ball.valid_for).is_null()
	# Quan la pilota surt del cercle, pc_pending s'esborra...
	SimHelpers.clear_field(s)
	s.state = &"play"
	SimHelpers.set_ball(s, 25.0, 0.0)
	sim.step()
	assert_bool(s.ball.pc_pending).is_false()
	# ...i un toc dins del cercle ja fa vàlid el gol.
	SimHelpers.set_ball(s, 40.0, 0.0)
	BallActions.touch(s, p)
	assert_object(s.ball.valid_for).is_same(iluro)


# --- Rellotge i quarts --------------------------------------------------------------


func test_rellotge_corre_a_qgame_entre_qlen() -> void:
	s.clock = Constants.QGAME
	for i in 60:
		Rules.tick_clock(s, Constants.STEP)
	assert_float(s.clock).is_equal_approx(Constants.QGAME - 6.0, 1e-6)


func test_canvis_de_quart_i_final() -> void:
	for q in range(1, 5):
		s.state = &"play"
		s.clock = 0.001
		sim.step()
		assert_int(s.quarter).is_equal(q)
		if q < 4:
			assert_str(s.state).is_equal("break")
			sim.next_quarter()
			assert_int(s.quarter).is_equal(q + 1)
			assert_float(s.clock).is_equal(Constants.QGAME)
			assert_str(s.restart_type).is_equal("center")
			# Serveix l'equip 0 als quarts senars i l'equip 1 als parells.
			assert_object(s.restart_team).is_same(s.teams[q % 2])
			# Al 3r quart es canvia de camp.
			assert_int(iluro.dir).is_equal(-1 if q + 1 >= 3 else 1)
		else:
			assert_str(s.state).is_equal("full")


func test_servei_de_centre() -> void:
	Rules.kickoff(s, iluro)
	assert_str(s.restart_type).is_equal("center")
	assert_str(s.restart_taker.name).is_equal("Martí Pujol")
	for p in s.players:
		if p == s.restart_taker:
			continue
		# Tothom al seu camp i els rivals a 5,2 m del centre com a mínim.
		assert_float(p.x * p.team.dir).is_less_equal(0.0)
		if p.team == polo:
			assert_float(sqrt(p.x * p.x + p.y * p.y)).is_greater_equal(5.2 - 1e-9)
