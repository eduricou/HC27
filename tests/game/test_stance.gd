# Proves de la postura dels jugadors segons la jugada: qui va ajupit i amb el pal a terra
# (qui porta la pilota, qui la va a robar, el penal córner) i qui va dret, i les mans al pal
# també corrent. Les altres proves dels jugadors són a test_players.gd.
extends GdUnitTestSuite

var _sim: MatchSim


func before_test() -> void:
	_sim = MatchSim.new(7, 150.0)
	_sim.s.intro_t = 0.0


func after_test() -> void:
	_sim.dispose()


## Un jugador muntat dins l'arbre, mirant cap a la cara `face` de la simulació.
func _rig_for(p: Player) -> PlayerView:
	var v: PlayerView = auto_free(PlayerView.new())
	v.setup(p, p.team.def)
	add_child(v)
	v.position = Coords.to_view(p.x, p.y)
	v.rotation.y = Coords.face_to_yaw(p.face)
	return v


func _frames(v: PlayerView, p: Player, n: int, speed: float = 0.0) -> void:
	for i in n:
		v.animate(p, speed, 1.0 / 60.0)
		await get_tree().process_frame


# --- Postura segons la jugada ------------------------------------------------------------


## Qui porta la pilota va ajupit; els seus companys, drets; un rival s'ajup quan s'hi
## acosta per robar-la; el porter sempre. Amb la pilota lliure, qui hi va a prop o n'espera
## la passada.
func test_qui_es_a_la_jugada() -> void:
	var s := _sim.s
	var own := s.teams[0].players[6]
	s.ball.owner = own
	s.ball.x = own.x
	s.ball.y = own.y
	var mate := s.teams[0].players[8]
	mate.x = own.x + 2.0
	mate.y = own.y
	assert_float(MatchView.engagement(s, own)).is_equal(1.0)
	assert_float(MatchView.engagement(s, mate)).is_equal(0.0)
	var opp := s.teams[1].players[5]
	opp.y = own.y
	opp.x = own.x + 12.0
	assert_float(MatchView.engagement(s, opp)).is_equal(0.0)
	opp.x = own.x + 2.0
	assert_float(MatchView.engagement(s, opp)).is_equal(1.0)
	opp.x = own.x + 4.0
	assert_float(MatchView.engagement(s, opp)).is_between(0.1, 0.9)
	assert_float(MatchView.engagement(s, s.teams[1].gk)).is_equal(1.0)
	# Pilota lliure: a prop sí, lluny no; qui n'espera la passada, des de més lluny.
	s.ball.owner = null
	assert_float(MatchView.engagement(s, mate)).is_equal(1.0)
	mate.x = own.x + 7.0
	assert_float(MatchView.engagement(s, mate)).is_equal(0.0)
	s.ball.pass_target = mate
	assert_float(MatchView.engagement(s, mate)).is_greater(0.4)


## Fora de la jugada, el jugador va més dret i amb el pal aixecat; quan hi entra, s'ajup
## a poc a poc i posa el pal a terra.
func test_dret_lluny_de_la_jugada() -> void:
	var p := _sim.s.teams[0].players[6]
	var v := _rig_for(p)
	for i in 60:
		v.animate(p, 0.0, 1.0 / 60.0, Vector3.INF, 0.0)
		await get_tree().process_frame
	var r := v.rig
	assert_float(r.low).is_less(0.01)
	assert_float(r.placer.blade.y).is_greater(0.25)
	var up_drop := r.posture.drop
	var up_hip := r.posture.hip
	v.animate(p, 0.0, 1.0 / 60.0, Vector3.INF, 1.0)
	# No canvia de cop.
	assert_float(r.low).is_less(0.2)
	for i in 90:
		v.animate(p, 0.0, 1.0 / 60.0, Vector3.INF, 1.0)
		await get_tree().process_frame
	assert_float(r.low).is_greater(0.99)
	assert_float(r.placer.blade.y).is_less(BallView.RADIUS + 0.01)
	assert_float(r.posture.drop).is_greater(up_drop + 0.1)
	assert_float(r.posture.hip).is_greater(up_hip + 0.3)


## Corrent amb la pilota, el jugador va més ajupit i, si el braç no arriba, el pal s'inclina
## cap al cos: les dues mans continuen al pal (abans la dreta en quedava a 13–19 cm).
func test_mans_al_pal_corrent_amb_la_pilota() -> void:
	for p: Player in [_sim.s.teams[0].players[6], _sim.s.teams[1].players[3]]:
		var v := _rig_for(p)
		var rig := v.rig
		var sk := rig.skeleton
		var worst := [0.0, 0.0]
		var grab := func() -> void:
			for i in 2:
				var hand := rig.placer.bone_local(sk.find_bone(["hand_l", "hand_r"][i]))
				var d := (hand * (GripModifier3D.hole(i) * rig.height)).distance_to(
					rig.placer.grip_points[i]
				)
				worst[i] = maxf(worst[i], d)
		for f in 70:
			if f == 30:
				sk.skeleton_updated.connect(grab)
			v.animate(p, 5.0, 1.0 / 60.0, Vector3.INF, 1.0)
			await get_tree().process_frame
		sk.skeleton_updated.disconnect(grab)
		for i in 2:
			(
				assert_float(worst[i])
				. override_failure_message("mà %d a %.3f m" % [i, worst[i]])
				. is_less(0.03)
			)


## Al penal córner, atacants i defensors esperen ajupits (també després de la passada,
## mentre dura la jugada); els de lluny, no. Quan s'acaba, es tornen a redreçar.
func test_ajupits_al_penal_corner() -> void:
	var s := _sim.s
	Rules.setup_pc(s, s.teams[0], 1.0, &"prova")
	var gx := s.pc_team.dir * Constants.HL
	var near: Array[Player] = []
	for p in s.players:
		if Vector2(p.x - gx, p.y).length() < MatchView.PC_RANGE:
			near.append(p)
		elif not p.is_gk:
			assert_float(MatchView.engagement(s, p)).is_less(1.0)
	assert_int(near.size()).is_greater(8)
	for live in [false, true]:
		if live:
			s.state = &"play"
			s.pc_live = true
		for p in near:
			assert_float(MatchView.engagement(s, p)).is_equal(1.0)
	s.pc_live = false
	var upright := near.filter(func(p: Player) -> bool: return MatchView.engagement(s, p) < 1.0)
	assert_int(upright.size()).is_greater(0)


## Cops: un xut fort fa girar més el tronc i aixeca més el pal que una passada suau.
func test_el_xut_fort_gira_mes_que_la_passada() -> void:
	var out := {}
	for power: float in [0.0, 1.0]:
		var p := _sim.s.teams[0].players[6]
		var v := _rig_for(p)
		v.stroke(power)
		p.swing = 0.0
		for f in 20:
			v.animate(p, 0.0, 1.0 / 60.0)
			await get_tree().process_frame
		p.swing = 0.125
		for f in 12:
			v.animate(p, 0.0, 1.0 / 60.0)
			await get_tree().process_frame
		out[power] = [v.rig.posture.twist, v.rig.placer.blade.y]
	assert_float(out[1.0][0]).is_less(out[0.0][0] - 0.2)
	assert_float(out[1.0][1]).is_greater(out[0.0][1] + 0.15)
	_sim.s.teams[0].players[6].swing = 0.0


## Estirada del porter: cau cap al costat de la pilota i després es torna a posar dret.
func test_estirada_del_porter() -> void:
	var gk: Player = _sim.s.teams[0].gk
	var v := _rig_for(gk)
	for f in 10:
		v.animate(gk, 0.0, 1.0 / 60.0)
		await get_tree().process_frame
	v.dive_toward(v.to_global(Vector3(2.0, 0.0, -1.0)))
	for f in 15:
		v.animate(gk, 0.0, 1.0 / 60.0)
		await get_tree().process_frame
	# El cap va cap a +x (la dreta del porter) i baixa.
	var up := v.rig.transform.basis.y
	assert_float(up.x).is_greater(0.6)
	for f in 60:
		v.animate(gk, 0.0, 1.0 / 60.0)
		await get_tree().process_frame
	assert_object(v.rig.transform).is_equal(Transform3D.IDENTITY)
