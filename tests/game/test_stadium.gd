# Proves del camp (fase 3) que no necessiten pantalla: la disposició (el camp real de
# l'Iluro, sense edificis al voltant), els efectes que depenen del partit, els presets de
# qualitat i la construcció.
extends GdUnitTestSuite

const HL := Constants.HL
const GHW := Constants.GHW
const STADIUM := preload("res://scenes/stadium.tscn")

# --- Disposició ----------------------------------------------------------------------


func test_talus_i_carretera_de_l_est() -> void:
	assert_float(StadiumLayout.ground_z(0.0)).is_equal(0.0)
	assert_float(StadiumLayout.ground_z(StadiumLayout.SLOPE_Y0)).is_equal(0.0)
	assert_float(StadiumLayout.ground_z(StadiumLayout.ROAD_Y0)).is_equal_approx(
		StadiumLayout.ROAD_Z, 1e-6
	)
	var mid := (StadiumLayout.ROAD_Y0 + StadiumLayout.ROAD_Y1) * 0.5
	assert_float(StadiumLayout.ground_z(mid)).is_equal_approx(StadiumLayout.ROAD_Z, 1e-6)
	assert_float(StadiumLayout.ground_z(500.0)).is_equal_approx(StadiumLayout.SLOPE_TOP.y, 1e-6)
	# La càmera TV és a sobre de la carretera.
	assert_float(StadiumLayout.TV_CAM.x).is_between(StadiumLayout.ROAD_Y0, StadiumLayout.ROAD_Y1)


## Res del costat de l'est no pot tapar la vista TV: entre la càmera i el camp (fins on la
## vista toca a terra, uns 22 m dins del camp), tot ha de quedar per sota de la visual.
func test_res_no_tapa_la_camera_tv() -> void:
	var cam := StadiumLayout.TV_CAM
	var y_ground := 22.0
	var sight := func(y: float) -> float: return cam.y * (y - y_ground) / (cam.x - y_ground)
	var veg := StadiumLayout.vegetation()
	var all: Array[Vector4] = []
	all.append_array(veg["pines"])
	all.append_array(veg["bushes"])
	for t in all:
		if t.y > y_ground and t.y < cam.x and absf(t.x) < StadiumLayout.TV_CAM_X + 10.0:
			var top := t.z + 12.0 * t.w
			if veg["bushes"].has(t):
				top = t.z + 2.8 * t.w
			assert_float(top).override_failure_message(str(t)).is_less(sight.call(t.y))
	var hedge_top := StadiumLayout.HEDGE_H + 0.3
	assert_float(hedge_top).is_less(sight.call(StadiumLayout.HEDGE_Y))
	for p in StadiumLayout.POLES:
		if p.y > 0.0:
			assert_float(absf(p.x)).is_greater(StadiumLayout.TV_CAM_X + 6.0)


func test_el_sol_ve_de_darrere_el_passeig() -> void:
	var sun := StadiumLayout.sun_view()
	assert_float(sun.length()).is_equal_approx(1.0, 1e-5)
	# Godot: Y amunt i −Z cap al passeig (y negativa de la simulació).
	assert_bool(sun.y > 0.4 and sun.z < 0.0 and sun.x < 0.0).is_true()


# --- Efectes del partit ----------------------------------------------------------------


func test_gol_mou_la_xarxa_i_fa_saltar_el_public() -> void:
	var fx := StadiumFx.new()
	var none: Array[Dictionary] = []
	fx.step([{"type": &"kick", "kind": &"shot"}] as Array[Dictionary], Constants.STEP)
	assert_float(fx.crowd_jump).is_equal_approx(0.25, 1e-6)
	fx.step([{"type": &"kick", "kind": &"pass"}] as Array[Dictionary], Constants.STEP)
	assert_float(fx.crowd_jump).is_less(0.25)
	fx.step([{"type": &"goal", "side": 1, "y": 5.0}] as Array[Dictionary], Constants.STEP)
	assert_int(fx.net_side).is_equal(1)
	assert_float(fx.net_y).is_equal_approx(GHW, 1e-6)
	assert_float(fx.net_t).is_equal(0.0)
	assert_float(fx.crowd_jump).is_equal(1.0)
	# El públic es calma a 0,16 per segon i la xarxa para al cap de 3,2 s.
	for i in 120:
		fx.step(none, Constants.STEP)
	assert_float(fx.crowd_jump).is_equal_approx(1.0 - 2.0 * 0.16, 1e-6)
	assert_int(fx.net_side).is_equal(1)
	for i in 80:
		fx.step(none, Constants.STEP)
	assert_int(fx.net_side).is_equal(0)


func test_la_repeticio_torna_a_moure_la_xarxa() -> void:
	var fx := StadiumFx.new()
	fx.step([{"type": &"goal", "side": -1, "y": 0.4}] as Array[Dictionary], Constants.STEP)
	fx.step([{"type": &"replay_start"}] as Array[Dictionary], Constants.STEP)
	assert_int(fx.net_side).is_equal(0)
	fx.step([{"type": &"net", "side": -1, "y": -0.7}] as Array[Dictionary], Constants.STEP)
	assert_int(fx.net_side).is_equal(-1)
	assert_float(fx.net_y).is_equal_approx(-0.7, 1e-6)
	fx.reset()
	assert_int(fx.net_side).is_equal(0)
	assert_float(fx.crowd_jump).is_equal(0.0)


# --- Qualitat ---------------------------------------------------------------------------


func test_presets_de_qualitat() -> void:
	var keys: Array = Quality.PRESETS[Quality.DEFAULT].keys()
	keys.sort()
	for n in Quality.NAMES:
		var q := Quality.preset(n)
		assert_str(q["name"]).is_equal(n)
		var k: Array = Quality.PRESETS[n].keys()
		k.sort()
		assert_array(k).is_equal(keys)
	# La baixa ha de ser la més barata: sense MSAA ni SSAO.
	assert_int(Quality.preset("baixa")["msaa"]).is_equal(Viewport.MSAA_DISABLED)
	assert_bool(Quality.preset("baixa")["ssao"]).is_false()
	assert_bool(Quality.preset("alta")["ssao"]).is_true()


func test_canvis_al_preset_per_provar() -> void:
	var q := Quality.preset("alta")
	Quality.override(q, "msaa=0,ssao=false,sun_dist=90")
	assert_int(q["msaa"]).is_equal(0)
	assert_bool(q["ssao"]).is_false()
	assert_float(q["sun_dist"]).is_equal(90.0)


# --- Malles -----------------------------------------------------------------------------


func test_les_cares_miren_cap_on_toca() -> void:
	var b := MeshBuilder.new()
	b.box(-1.0, 3.0, -2.0, 1.0, 0.0, 2.0)
	var mesh := b.to_mesh()
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var center := Coords.to_view(1.0, -0.5, 1.0)
	assert_int(v.size()).is_equal(5 * 6)
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		# Normal cap a fora de la caixa.
		assert_float(n[i].dot(c - center)).is_greater(0.0)
		# Godot dibuixa la cara davantera en sentit horari: la normal geomètrica
		# (regla de la mà dreta) apunta cap a dins.
		assert_float((v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i])).is_less(0.0)


func test_xarxa_de_la_porteria() -> void:
	for side: int in [-1, 1]:
		var mesh := GoalView.net_mesh(side)
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var box := mesh.get_aabb()
		assert_float(minf(absf(box.position.x), absf(box.end.x))).is_greater_equal(HL)
		assert_float(maxf(absf(box.position.x), absf(box.end.x))).is_less_equal(
			HL + Constants.GD + 1e-4
		)
		assert_float(box.position.z).is_equal_approx(-GHW, 1e-4)
		assert_float(box.end.y).is_equal_approx(Constants.GH, 1e-4)
		# El fons de la porteria es pot deformar del tot i els laterals (z = ±GHW), gens.
		for i in v.size():
			var lateral := is_equal_approx(absf(v[i].z), GHW)
			if lateral:
				assert_float(col[i].r).is_equal(0.0)
			elif (
				is_equal_approx(absf(v[i].x), HL + Constants.GD)
				and absf(v[i].z) < 0.4
				and v[i].y > 0.8
				and v[i].y < 1.4
			):
				assert_float(col[i].r).is_greater(0.9)


# --- Construcció -------------------------------------------------------------------------


func test_el_camp_es_construeix_sencer() -> void:
	var st: Stadium = auto_free(STADIUM.instantiate())
	add_child(st)
	for n: String in [
		"Entorn",
		"Sol",
		"Terra",
		"Talus",
		"Tanques",
		"Pancartes",
		"Bardissa",
		"Torres",
		"Banquetes",
		"Public",
		"CasetesClub",
		"Carrer",
		"Vegetacio",
		"PorteriaEsquerra",
		"PorteriaDreta",
		"PorteriesRecanvi",
	]:
		assert_object(st.get_node_or_null(n)).override_failure_message(n).is_not_null()
	# No hi ha grada ni edificis al voltant (només les casetes del club).
	assert_object(st.get_node_or_null("Grada")).is_null()
	assert_object(st.get_node_or_null("Ciutat")).is_null()
	for n in ["Cases", "Teulades", "Pisos", "Hospital"]:
		assert_object(st.find_child(n, true, false)).override_failure_message(n).is_null()
	var spots := st.find_children("*", "SpotLight3D", true, false)
	assert_int(spots.size()).is_equal(StadiumLayout.POLES.size())
	for sp: SpotLight3D in spots:
		# El camp fix no fa ombra amb els focus.
		assert_int(sp.shadow_caster_mask & Stadium.STATIC_LAYER).is_equal(0)
	# Públic en 3D: totes les persones, repartides en unes quantes siluetes.
	var people := 0
	for mmi: MultiMeshInstance3D in st.get_node("Public").get_children():
		people += mmi.multimesh.instance_count
		assert_object(mmi.multimesh.mesh).is_not_null()
	assert_int(people).is_equal(StadiumLayout.SPECTATORS)
	assert_int(st.get_node("Public").get_child_count()).is_greater(3)
	st.set_night(false)
	assert_bool((st.get_node("Sol") as Light3D).visible).is_true()
	assert_bool((spots[0] as Light3D).visible).is_false()
	st.set_night(true)
	assert_bool((st.get_node("Sol") as Light3D).visible).is_false()
	assert_bool((spots[0] as Light3D).visible).is_true()


# --- Banquetes i arbres ----------------------------------------------------------------


## Les banquetes com les reals: una estructura amb el sostre continu, vuit cadires a cada
## banda, i la taula amb l'escut i el rètol del club al mig.
func test_banquetes_com_les_reals() -> void:
	var b: Node3D = auto_free(Dugout.build())
	var mi := b.get_node("Estructura") as MeshInstance3D
	var aabb := mi.mesh.get_aabb()
	assert_float(aabb.size.x).is_between(17.0, 18.0)
	assert_float(aabb.end.y).is_between(Dugout.H, Dugout.H + 0.2)
	assert_float(aabb.end.z).is_less(Dugout.D + 0.3)
	# Seients: la cinquena superfície és la del plàstic; 2 x 8 closques de 9 x 9 vèrtexs.
	var seats: PackedVector3Array = mi.mesh.surface_get_arrays(3)[Mesh.ARRAY_VERTEX]
	assert_int(seats.size()).is_equal(2 * Dugout.SEATS * 9 * 9)
	assert_object(b.get_node_or_null("Escut")).is_not_null()
	var labels := b.find_children("*", "Label3D", true, false)
	var texts := labels.map(func(l: Label3D) -> String: return l.text)
	assert_array(texts).contains(["ILURO", "HOCKEY CLUB"])


## Els arbres fan la mida que toca, i res del talús tapa la vista TV (els límits de
## test_res_no_tapa_la_camera_tv: 12 m els pins i 2,8 m els arbustos, a escala 1).
func test_mida_dels_arbres() -> void:
	var leaves := TreeMesh.foliage_material(null)
	for i in 4:
		var pine := TreeMesh.pine(11 + i, leaves).get_aabb()
		assert_float(pine.end.y).is_between(9.5, 12.0)
		assert_float(maxf(pine.size.x, pine.size.z)).is_between(6.0, 11.0)
	for i in 3:
		var tree := TreeMesh.broadleaf(51 + i, leaves).get_aabb()
		assert_float(tree.end.y).is_between(6.0, 8.5)
		var bush := TreeMesh.bush(31 + i, leaves).get_aabb()
		assert_float(bush.end.y).is_less(2.8)
	var hedge := TreeMesh.hedge(-60.0, 60.0, StadiumLayout.HEDGE_D, StadiumLayout.HEDGE_H, leaves)
	var hb := hedge.get_aabb()
	assert_float(hb.end.y).is_between(StadiumLayout.HEDGE_H - 0.3, StadiumLayout.HEDGE_H + 0.3)
	assert_float(hb.position.y).is_greater_equal(0.0)


## Tots els pins i arbustos hi són, repetits amb MultiMesh (unes quantes variants).
func test_arbres_amb_multimesh() -> void:
	var st: Stadium = auto_free(STADIUM.instantiate())
	add_child(st)
	var veg := StadiumLayout.vegetation()
	var count := {}
	for group: String in ["Pins", "Arbustos"]:
		count[group] = 0
		for mmi: MultiMeshInstance3D in st.get_node("Vegetacio/" + group).get_children():
			count[group] += mmi.multimesh.instance_count
	assert_int(count["Pins"]).is_equal(veg["pines"].size())
	assert_int(count["Arbustos"]).is_equal(veg["bushes"].size())
	var street := 0
	for mmi: MultiMeshInstance3D in st.get_node("Carrer/Arbres").get_children():
		street += mmi.multimesh.instance_count
	assert_int(street).is_equal(StadiumLayout.street_trees().size())


## La càmera ampla (la de per defecte) veu terra fins a l'horitzó: el terra i el pla de
## tall arriben més lluny que on la boira ja és plena, i els arbres de lluny no són al talús
## de l'est ni a prop del camp.
func test_l_horitzo_no_es_talla() -> void:
	var st: Stadium = auto_free(STADIUM.instantiate())
	add_child(st)
	var half := Stadium.GROUND_SIZE * 0.5
	var env: Environment = (st.get_node("Entorn") as WorldEnvironment).environment
	assert_float(half).is_greater(env.fog_depth_end)
	var cam: CameraRig = auto_free(CameraRig.new())
	add_child(cam)
	assert_float(cam.far).is_greater(half)
	for t in StadiumLayout.far_trees():
		var d := Vector2(t.x, t.y + 20.0).length()
		assert_float(d).is_greater(150.0)
		assert_bool(absf(t.x) < 200.0 and t.y > 0.0 and t.y < 230.0).is_false()


## Les persones del públic fan l'alçada que toca i tenen totes les peces (pell, cabell,
## roba i sabates) marcades per al shader.
func test_public_en_3d() -> void:
	var mesh := SpectatorMesh.build(1.75, 0.5, SpectatorMesh.Pose.CROSSED, true)
	var aabb := mesh.get_aabb()
	assert_float(aabb.end.y).is_between(1.7, 1.8)
	assert_float(aabb.position.y).is_greater(-0.01)
	assert_float(aabb.size.x).is_between(0.4, 0.75)
	var kinds := {}
	for c: Color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		kinds[int(c.r * 8.0)] = true
	for k in SpectatorMesh.Part.values():
		if k != SpectatorMesh.Part.SHIRT:
			assert_bool(kinds.has(k)).override_failure_message(str(k)).is_true()
	assert_object(SpectatorMesh.build(1.75, 0.5, SpectatorMesh.Pose.CROSSED, true)).is_same(mesh)


## Els cotxes fan la mida d'un turisme i n'hi ha una filera aparcada. (El color de cada un
## va a les dades de la instància, que sense pantalla no es guarden: es veu a les captures.)
func test_cotxes() -> void:
	var aabb := CarMesh.build().get_aabb()
	assert_float(aabb.size.x).is_between(4.0, 4.6)
	assert_float(aabb.size.z).is_between(1.6, 2.0)
	assert_float(aabb.end.y).is_between(1.3, 1.6)
	assert_float(aabb.position.y).is_greater(-0.01)
	var st: Stadium = auto_free(STADIUM.instantiate())
	add_child(st)
	var mmi := st.get_node("Carrer/Cotxes/Cotxes") as MultiMeshInstance3D
	assert_int(mmi.multimesh.instance_count).is_greater(10)
	assert_bool(mmi.multimesh.use_custom_data).is_true()
