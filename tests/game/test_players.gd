# Proves dels jugadors de la fase 4 (esquelet i animacions) que no necessiten pantalla:
# l'equipació per regions, les animacions convertides, el pal al punt de control de la
# simulació, les mans al pal i els peus a terra.
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


# --- Equipació ------------------------------------------------------------------------


func test_parts_del_cos_pels_ossos() -> void:
	assert_int(KitMesh.part_of("Head")).is_equal(KitMesh.Part.HEAD)
	assert_int(KitMesh.part_of("spine_02")).is_equal(KitMesh.Part.TORSO)
	assert_int(KitMesh.part_of("clavicle_l")).is_equal(KitMesh.Part.TORSO)
	assert_int(KitMesh.part_of("lowerarm_r")).is_equal(KitMesh.Part.ARM)
	assert_int(KitMesh.part_of("index_02_l")).is_equal(KitMesh.Part.ARM)
	assert_int(KitMesh.part_of("calf_r")).is_equal(KitMesh.Part.LEG)
	assert_int(KitMesh.part_of("ball_l")).is_equal(KitMesh.Part.LEG)


## La roba tapa el que toca: samarreta al pit, pantaló a la cuixa, mitja a la canyella,
## sabata al peu, i pell al genoll, a l'avantbraç i a la mà.
func test_regions_de_l_equipacio() -> void:
	var body: Node = auto_free(PlayerRig.BODY_SCENE.instantiate())
	var sk := body.get_node("Armature/Skeleton3D") as Skeleton3D
	var lm := KitMesh.landmarks(sk)
	var at := func(b: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(b)).origin
	var reg := KitMesh.Region
	var part := KitMesh.Part
	assert_int(KitMesh.classify(at.call("spine_03"), part.TORSO, lm)).is_equal(reg.SHIRT)
	assert_int(KitMesh.classify(at.call("pelvis") - Vector3(0, 0.05, 0), part.TORSO, lm)).is_equal(
		reg.SHORTS
	)
	var hip: Vector3 = at.call("thigh_l")
	var knee: Vector3 = at.call("calf_l")
	var ankle: Vector3 = at.call("foot_l")
	assert_int(KitMesh.classify(hip.lerp(knee, 0.2), part.LEG, lm)).is_equal(reg.SHORTS)
	assert_int(KitMesh.classify(knee, part.LEG, lm)).is_equal(reg.SKIN)
	assert_int(KitMesh.classify(knee.lerp(ankle, 0.6), part.LEG, lm)).is_equal(reg.SOCKS)
	assert_int(KitMesh.classify(ankle - Vector3(0, 0.05, 0), part.LEG, lm)).is_equal(reg.SHOES)
	var sh: Vector3 = at.call("upperarm_r")
	var el: Vector3 = at.call("lowerarm_r")
	assert_int(KitMesh.classify(sh.lerp(el, 0.3), part.ARM, lm)).is_equal(reg.SLEEVE)
	assert_int(KitMesh.classify(el.lerp(at.call("hand_r"), 0.5), part.ARM, lm)).is_equal(
		reg.FOREARM
	)
	assert_int(KitMesh.classify(at.call("middle_02_r"), part.ARM, lm)).is_equal(reg.HAND)
	assert_int(KitMesh.classify(at.call("Head"), part.HEAD, lm)).is_equal(reg.SKIN)


func test_textura_de_dades_un_pixel_per_vertex() -> void:
	var body: Node = auto_free(PlayerRig.BODY_SCENE.instantiate())
	var sk := body.get_node("Armature/Skeleton3D") as Skeleton3D
	var mi := sk.get_node("SuperHero_Male") as MeshInstance3D
	var tex := KitMesh.data_texture(mi.mesh, mi.skin, sk)
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var img := tex.get_image()
	assert_int(img.get_width() * img.get_height()).is_greater_equal(verts.size())
	for v: int in [0, verts.size() / 2, verts.size() - 1]:
		var c := img.get_pixel(v % KitMesh.TEX_W, v / KitMesh.TEX_W)
		assert_vector(Vector3(c.r, c.g, c.b)).is_equal_approx(verts[v], Vector3.ONE * 1e-4)
		assert_float(c.a).is_between(0.0, 3.0)


# --- Animacions -------------------------------------------------------------------------


## Les animacions de córrer van més de pressa com més ràpid avança el peu: és el que fa
## servir la mescla per no fer relliscar els peus.
func test_velocitats_de_les_animacions_de_correr() -> void:
	var walk := PlayerRig._gs("walk")
	var jog := PlayerRig._gs("jog")
	var sprint := PlayerRig._gs("sprint")
	assert_float(walk).is_between(0.6, 2.0)
	assert_bool(walk < jog and jog < sprint).is_true()
	# L'esprint de l'animació arriba a la velocitat màxima dels jugadors (≈ 7 m/s; 8,5 m/s
	# l'humà esprintant): només per sobre s'accelera l'animació.
	assert_float(sprint).is_greater(7.0)
	for a: String in [
		"idle", "walk", "jog", "sprint", "celebrate", "protest", "dive", "lunge", "hit"
	]:
		assert_bool(PlayerRig.ANIMS.has_animation(a)).override_failure_message(a).is_true()
	assert_int(PlayerRig.ANIMS.get_animation("jog").loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(PlayerRig.ANIMS.get_animation("celebrate").loop_mode).is_equal(Animation.LOOP_NONE)


# --- Pal, mans i peus -------------------------------------------------------------------


## La pala és al punt de control de la simulació (stickPt), també durant un cop.
func test_el_pal_toca_on_toca_la_simulacio() -> void:
	var s := _sim.s
	var p := s.teams[0].players[6]
	var v := _rig_for(p)
	for swing: float in [0.0, 0.12, 0.2]:
		p.swing = swing
		await _frames(v, p, 2)
		var k := sin((swing / 0.25) * PI) if swing > 0.0 else 0.0
		BallActions.stick_pt(s, p, 0.72 - k * 0.55, 0.3 + k * 0.35)
		var want := Coords.to_view(s.st_x, s.st_y, k * 0.75)
		var got := v.rig.stick.global_position
		(
			assert_vector(got)
			. override_failure_message("swing %s: %s vs %s" % [swing, got, want])
			. is_equal_approx(want, Vector3.ONE * 0.01)
		)


## Amb la IK, les mans arriben al pal i els peus es queden a terra. La postura final (amb
## els modificadors) només es pot llegir durant el senyal skeleton_updated.
func test_mans_al_pal_i_peus_a_terra() -> void:
	var p := _sim.s.teams[1].players[5]
	var v := _rig_for(p)
	var rig := v.rig
	var sk := rig.skeleton
	var final := {}
	var grab := func() -> void:
		for b: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			final[b] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b))).origin
		final["grip_l"] = rig.grips[0].global_position
		final["grip_r"] = rig.grips[1].global_position
	sk.skeleton_updated.connect(grab)
	await _frames(v, p, 20)
	sk.skeleton_updated.disconnect(grab)
	assert_bool(final.is_empty()).is_false()
	for i in 2:
		var hand: Vector3 = final[["hand_l", "hand_r"][i]]
		var d := hand.distance_to(final[["grip_l", "grip_r"][i]])
		# La mà (el canell) queda a tocar del punt on agafa el pal.
		assert_float(d).override_failure_message("mà %d a %.3f m del pal" % [i, d]).is_less(0.1)
	for f: String in ["foot_l", "foot_r"]:
		var y: float = final[f].y
		assert_float(y).override_failure_message("%s a %.3f m" % [f, y]).is_less(0.16)


## Criteri de la fase 4: els peus no rellisquen. El jugador avança a velocitat v i, mentre
## un peu és a terra, aquest peu gairebé no es mou respecte a terra (com a molt un 15 % de
## v; mesurat, ≤ 7 % entre 1 i 9 m/s). L'animació s'avança a mà a 60 Hz.
func test_els_peus_no_rellisquen() -> void:
	var p := _sim.s.teams[0].players[6]
	var v := _rig_for(p)
	var rig := v.rig
	var sk := rig.skeleton
	rig.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var dt := 1.0 / 60.0
	for speed: float in [2.0, 4.5, 7.0, 9.0]:
		var zs := {"ball_l": PackedFloat64Array(), "ball_r": PackedFloat64Array()}
		var ys := {"ball_l": PackedFloat64Array(), "ball_r": PackedFloat64Array()}
		var body_z := 0.0
		for i in 180:
			rig.animate(p, speed, dt)
			rig.tree.advance(dt)
			body_z -= speed * dt
			for f: String in zs:
				var w := rig._body.transform * sk.get_bone_global_pose(sk.find_bone(f)).origin
				zs[f].append(body_z + w.z)
				ys[f].append(w.y)
			await get_tree().process_frame
		var slips := PackedFloat64Array()
		for f: String in zs:
			var lo := 1e9
			for i in range(60, 180):
				lo = minf(lo, ys[f][i])
			for i in range(60, 179):
				if ys[f][i] < lo + 0.025 and ys[f][i + 1] < lo + 0.025:
					slips.append(absf(zs[f][i + 1] - zs[f][i]) / dt)
		(
			assert_int(slips.size())
			. override_failure_message("%.1f m/s: sense recolzament" % speed)
			. is_greater(10)
		)
		slips.sort()
		var med := slips[slips.size() / 2]
		(
			assert_float(med / speed)
			. override_failure_message("%.1f m/s: el peu rellisca a %.2f m/s" % [speed, med])
			. is_less(0.15)
		)


## El ritme de la passa és continu i creix amb la velocitat.
func test_ritme_de_la_passa() -> void:
	var last := 0.0
	for i in range(1, 50):
		var v := i * 0.2
		var r := PlayerRig.gait_rate(v)
		assert_float(r).is_greater_equal(last - 1e-6)
		last = r
	assert_float(PlayerRig.gait_rate(PlayerRig._gs("jog"))).is_equal_approx(
		PlayerRig._gs("jog") / PlayerRig.stride_at(PlayerRig._gs("jog")), 1e-6
	)


## Els esdeveniments del partit disparen les accions: el golejador ho celebra i el porter
## que encaixa protesta.
func test_gol_fa_celebrar_i_protestar() -> void:
	var runner: MatchRunner = auto_free(MatchRunner.new())
	runner.start(3, 150.0, -1, "normal")
	var view: MatchView = auto_free(MatchView.new())
	view.runner = runner
	add_child(view)
	view.sync_now()
	var s := runner.sim.s
	var scorer := s.teams[0].players[9]
	view.on_events([{"type": &"goal", "team": 0, "scorer": scorer}] as Array[Dictionary])
	var sv: PlayerView = view.get_child(view.get_child_count() - 22 + s.players.find(scorer))
	assert_str(String(sv.rig._action.animation)).is_equal("celebrate")
	assert_float(sv.rig._action_left).is_greater(1.0)
	var gk: Player = null
	for p in s.teams[1].players:
		if p.is_gk:
			gk = p
	var gv: PlayerView = view.get_child(view.get_child_count() - 22 + s.players.find(gk))
	assert_str(String(gv.rig._action.animation)).is_equal("protest")
	runner.stop()
