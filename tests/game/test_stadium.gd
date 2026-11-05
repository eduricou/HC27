# Proves del camp (fase 3) que no necessiten pantalla: la disposició (el camp real de
# l'Iluro, amb la ciutat del fons de la web), els efectes que depenen del partit, els
# presets de qualitat i la construcció.
extends GdUnitTestSuite

const HL := Constants.HL
const GHW := Constants.GHW

# --- Disposició ----------------------------------------------------------------------


## Valors de referència calculats amb el codi de glInit() de la web (generador amb
## llavor 11): 26 blocs de pisos.
func test_ciutat_com_la_web() -> void:
	var rnd := StadiumLayout.ParkMiller.new()
	var blocks := StadiumLayout.city_blocks(rnd)
	assert_int(blocks.size()).is_equal(26)
	var first: Rect2 = blocks[0][0]
	assert_float(first.position.x).is_equal_approx(-259.95523, 1e-3)
	assert_float(first.position.y).is_equal_approx(-229.70254, 1e-3)
	assert_float(first.size.x).is_equal_approx(22.85649, 1e-3)
	assert_float(first.size.y).is_equal_approx(10.54182, 1e-3)
	assert_float(blocks[0][1]).is_equal_approx(26.20879, 1e-3)


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
	var st: Stadium = auto_free(load("res://scenes/stadium.tscn").instantiate())
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
		"Ciutat",
		"Vegetacio",
		"PorteriaEsquerra",
		"PorteriaDreta",
		"PorteriesRecanvi",
	]:
		assert_object(st.get_node_or_null(n)).override_failure_message(n).is_not_null()
	# No hi ha grada.
	assert_object(st.get_node_or_null("Grada")).is_null()
	var spots := st.find_children("*", "SpotLight3D", true, false)
	assert_int(spots.size()).is_equal(StadiumLayout.POLES.size())
	for sp: SpotLight3D in spots:
		# El camp fix no fa ombra amb els focus.
		assert_int(sp.shadow_caster_mask & Stadium.STATIC_LAYER).is_equal(0)
	var people: MultiMeshInstance3D = st.get_node("Public")
	assert_int(people.multimesh.instance_count).is_equal(StadiumLayout.SPECTATORS)
	st.set_night(false)
	assert_bool((st.get_node("Sol") as Light3D).visible).is_true()
	assert_bool((spots[0] as Light3D).visible).is_false()
	st.set_night(true)
	assert_bool((st.get_node("Sol") as Light3D).visible).is_false()
	assert_bool((spots[0] as Light3D).visible).is_true()
