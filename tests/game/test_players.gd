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


## La pilota toca la cara del ganxo al punt de control de la simulació (stickPt), també
## durant un cop; i quan el jugador porta la pilota, on es veu la pilota.
func test_el_pal_toca_on_toca_la_simulacio() -> void:
	var s := _sim.s
	var p := s.teams[0].players[6]
	var v := _rig_for(p)
	var r := BallView.RADIUS
	for swing: float in [0.0, 0.12, 0.2]:
		p.swing = swing
		await _frames(v, p, 2)
		var k := sin((swing / 0.25) * PI) if swing > 0.0 else 0.0
		BallActions.stick_pt(s, p, 0.72 - k * 0.55, 0.3 + k * 0.35)
		var want := Coords.to_view(s.st_x, s.st_y, k * 0.75 + r)
		var got := v.rig.to_global(v.rig.blade)
		(
			assert_vector(got)
			. override_failure_message("swing %s: %s vs %s" % [swing, got, want])
			. is_equal_approx(want, Vector3.ONE * 0.015)
		)
	p.swing = 0.0
	var ball := v.to_global(Vector3(0.15, r, -0.9))
	for i in 20:
		v.animate(p, 0.0, 1.0 / 60.0, ball)
		await get_tree().process_frame
	var at := v.rig.to_global(v.rig.blade)
	assert_vector(at).is_equal_approx(ball, Vector3.ONE * 0.015)


## Amb la IK, les mans arriben al pal i els peus es queden a terra. La postura final (amb
## els modificadors) només es pot llegir durant el senyal skeleton_updated.
func test_mans_al_pal_i_peus_a_terra() -> void:
	var p := _sim.s.teams[1].players[5]
	var v := _rig_for(p)
	var rig := v.rig
	var sk := rig.skeleton
	var final := {}
	var tips := ["index_04_leaf", "middle_04_leaf", "ring_04_leaf", "pinky_04_leaf"]
	var grab := func() -> void:
		for b: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			final[b] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b))
		for i in 2:
			for t: String in tips:
				var b := sk.find_bone(t + ["_l", "_r"][i])
				final[t + str(i)] = (sk.global_transform * sk.get_bone_global_pose(b)).origin
	sk.skeleton_updated.connect(grab)
	await _frames(v, p, 20)
	sk.skeleton_updated.disconnect(grab)
	assert_bool(final.is_empty()).is_false()
	var grips: Array[Vector3] = []
	for i in 2:
		var hand: Transform3D = final[["hand_l", "hand_r"][i]]
		var grip := rig.to_global(rig.grip_points[i])
		grips.append(grip)
		# La canya passa pel puny...
		var d := (hand * GripModifier3D.hole(i)).distance_to(grip)
		assert_float(d).override_failure_message("puny %d a %.3f m del pal" % [i, d]).is_less(0.04)
		# ... i els dits l'envolten (les puntes, a tocar de la superfície).
		var axis := rig.to_global(rig.grip_points[0]) - rig.to_global(rig.grip_points[1])
		axis = axis.normalized()
		for t: String in tips:
			var q: Vector3 = final[t + str(i)] - grip
			var gap := (q - axis * q.dot(axis)).length()
			assert_float(gap).override_failure_message("%s %d a %.3f m" % [t, i, gap]).is_less(
				0.045
			)
	# La dreta agafa més avall que l'esquerra.
	assert_float(grips[0].distance_to(grips[1])).is_greater(0.12)
	assert_float(grips[0].y).is_greater(grips[1].y)
	for f: String in ["foot_l", "foot_r"]:
		var y: float = (final[f] as Transform3D).origin.y
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


# --- Porter ---------------------------------------------------------------------------


func _gear_mesh(v: PlayerView, bone: String) -> ArrayMesh:
	var att := v.rig.skeleton.get_node_or_null("Equip_" + bone)
	if att == null:
		return null
	return (att.get_child(0) as MeshInstance3D).mesh as ArrayMesh


static func _verts(mesh: ArrayMesh, surface: int) -> PackedVector3Array:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]


## El casc tapa el cap per dalt i pel clatell però deixa la cara a la vista, darrere la
## reixa; les guardes van de sobre la xutera a sobre el genoll i les xuteres tapen la bota.
## Els jugadors de camp no porten res de tot això.
func test_equip_del_porter() -> void:
	var gk: Player = _sim.s.teams[0].gk
	var v := _rig_for(gk)
	var sk := v.rig.skeleton
	var at := func(b: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(b)).origin
	var helmet := _gear_mesh(v, "Head")
	assert_int(helmet.get_surface_count()).is_equal(3)
	var shell := _verts(helmet, 0)
	var top := -INF
	var back := INF
	var face := 0
	for p in shell:
		top = maxf(top, p.y)
		back = minf(back, p.z)
		if absf(p.x) < 0.05 and p.y > 1.6 and p.y < 1.74 and p.z > 0.06:
			face += 1
	var head := Vector3(at.call("Head"))
	assert_float(top).is_greater(head.y + 0.22)
	assert_float(back).is_less(-0.12)
	assert_int(face).override_failure_message("la closca tapa la cara").is_equal(0)
	var in_front := 0
	for p in _verts(helmet, 1):
		if absf(p.x) < 0.02 and p.y > 1.62 and p.y < 1.72 and p.z > 0.15:
			in_front += 1
	assert_int(in_front).override_failure_message("no hi ha reixa davant la cara").is_greater(0)
	for side: String in ["l", "r"]:
		var pad := _gear_mesh(v, "calf_" + side).get_aabb()
		var kick := _gear_mesh(v, "foot_" + side).get_aabb()
		var knee := Vector3(at.call("calf_" + side))
		assert_float(pad.end.y).is_greater(knee.y + 0.08)
		assert_float(pad.position.y).is_less(kick.end.y)
		# La xutera tapa el peu (de 0 a 0,10 d'alçada i de −0,14 a 0,13 de llarg).
		assert_float(kick.position.z).is_less(-0.14)
		assert_float(kick.end.z).is_greater(0.13)
		assert_float(kick.end.y).is_greater(0.11)
		assert_float(signf(kick.get_center().x)).is_equal(signf(knee.x))
	assert_object(_gear_mesh(v, "hand_l")).is_not_null()
	var field := _rig_for(_sim.s.teams[0].players[9])
	assert_object(_gear_mesh(field, "Head")).is_null()


## Cada peça es fa una sola vegada per joc de colors (els dos porters del mateix equip,
## o el mateix en partits seguits, la comparteixen); el ribet és el color que contrasta.
func test_equip_del_porter_es_reaprofita() -> void:
	var lime := Color("c4e84a")
	var black := Color("1b1d20")
	assert_object(GkGear.leg_guard(1.0, lime, black)).is_same(GkGear.leg_guard(1.0, lime, black))
	assert_object(GkGear.leg_guard(-1.0, lime, black)).is_not_same(
		GkGear.leg_guard(1.0, lime, black)
	)
	var navy := Color("14234b")
	var kit: Array[Color] = [Color("f2c500"), navy]
	assert_object(GkGear.contrast(Color("f4f4f2"), kit)).is_equal(navy)


# --- Sabatilles -----------------------------------------------------------------------


## Els jugadors de camp porten sabatilles que es mouen amb el peu, de colors diferents
## entre companys; el porter no (porta xuteres).
func test_sabatilles_de_colors_diferents() -> void:
	var uppers := {}
	for p in _sim.s.teams[0].players:
		var v := _rig_for(p)
		var shoes := v.rig.skeleton.get_node_or_null("Sabatilles") as MeshInstance3D
		if p.is_gk:
			assert_object(shoes).is_null()
			continue
		assert_object(shoes).is_not_null()
		assert_object(shoes.skin).is_same(v.rig.body_mesh.skin)
		uppers[ShoeMesh.colors_for(p)[0]] = true
	assert_int(uppers.size()).is_equal(10)


## Les sabatilles tapen el peu del model: gairebé tots els vèrtexs del peu (del turmell
## avall) queden dins del perfil. Els pesos sumen 1 i van als ossos del peu i de la cama.
func test_les_sabatilles_tapen_el_peu() -> void:
	var body: Node = auto_free(PlayerRig.BODY_SCENE.instantiate())
	var sk := body.get_node("Armature/Skeleton3D") as Skeleton3D
	var mi := sk.get_node("SuperHero_Male") as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var inside := 0
	var total := 0
	for p in verts:
		if p.y > 0.1 or absf(p.x) < 0.05 or p.z < -0.2 or p.z > 0.2:
			continue
		total += 1
		var pr := ShoeMesh.profile_at(p.z)
		var ok := p.z >= ShoeMesh.PROFILE[0].x and p.z <= ShoeMesh.PROFILE[-1].x
		ok = ok and absf(absf(p.x) - pr.x) <= pr.y + 0.005 and p.y <= pr.z + 0.002
		if ok:
			inside += 1
	assert_int(total).is_greater(100)
	assert_float(float(inside) / total).is_greater(0.97)
	var mesh := ShoeMesh.build(mi.skin, sk)
	var arr := mesh.surface_get_arrays(0)
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var b: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var names := {}
	for k in range(0, w.size(), 4):
		assert_float(w[k] + w[k + 1] + w[k + 2] + w[k + 3]).is_equal_approx(1.0, 1e-4)
		for j in 3:
			names[mi.skin.get_bind_name(b[k + j])] = true
	assert_array(names.keys()).contains_exactly_in_any_order(
		["foot_l", "ball_l", "calf_l", "foot_r", "ball_r", "calf_r"]
	)


# --- Complexions ------------------------------------------------------------------------


## Els Papis no són tots iguals: cada jugador té una complexió (alçada, gruix, panxa i
## músculs llisos), sempre la mateixa, i en un equip n'hi ha de ben diferents.
func test_complexions_diferents() -> void:
	var builds := {}
	var lo := INF
	var hi := -INF
	for p in _sim.s.teams[0].players:
		var v := _rig_for(p)
		var b := PlayerRig.build_of(p)
		builds[Vector3(b.y, b.z, b.w)] = true
		lo = minf(lo, b.x)
		hi = maxf(hi, b.x)
		assert_float(v.rig.height).is_equal(b.x)
		assert_vector(v.rig._body.scale).is_equal_approx(Vector3.ONE * b.x, Vector3.ONE * 1e-5)
		var mi := v.rig.body_mesh
		assert_float(float(mi.get_instance_shader_parameter("belly"))).is_equal_approx(b.z, 1e-6)
		assert_float(float(mi.get_instance_shader_parameter("girth"))).is_equal_approx(b.y, 1e-6)
		assert_float(float(mi.get_instance_shader_parameter("soft"))).is_equal_approx(b.w, 1e-6)
	assert_int(builds.size()).is_greater_equal(6)
	assert_float(hi - lo).is_greater(0.07)


## Relleu dels músculs: un píxel per vèrtex, uns quants mil·límetres de mitjana i mai més
## de 3 cm (el suavitzat no ha d'encongir ni inflar el cos).
func test_relleu_dels_musculs() -> void:
	var body: Node = auto_free(PlayerRig.BODY_SCENE.instantiate())
	var mi := body.get_node("Armature/Skeleton3D/SuperHero_Male") as MeshInstance3D
	var img := KitMesh.shape_texture(mi.mesh).get_image()
	var n: int = mi.mesh.surface_get_array_len(0)
	assert_int(img.get_width() * img.get_height()).is_greater_equal(n)
	var total := 0.0
	var worst := 0.0
	for i in n:
		var o := img.get_pixel(i % KitMesh.TEX_W, i / KitMesh.TEX_W).r
		total += absf(o)
		worst = maxf(worst, absf(o))
	assert_float(total / n).is_between(0.001, 0.01)
	assert_float(worst).is_less(0.03)


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
	assert_float(r.blade.y).is_greater(0.25)
	var up_drop := r.posture.drop
	var up_hip := r.posture.hip
	v.animate(p, 0.0, 1.0 / 60.0, Vector3.INF, 1.0)
	# No canvia de cop.
	assert_float(r.low).is_less(0.2)
	for i in 90:
		v.animate(p, 0.0, 1.0 / 60.0, Vector3.INF, 1.0)
		await get_tree().process_frame
	assert_float(r.low).is_greater(0.99)
	assert_float(r.blade.y).is_less(BallView.RADIUS + 0.01)
	assert_float(r.posture.drop).is_greater(up_drop + 0.1)
	assert_float(r.posture.hip).is_greater(up_hip + 0.3)
