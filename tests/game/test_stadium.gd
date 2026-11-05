# Proves de l'estadi de la fase 3 que no necessiten pantalla: la disposició (igual que la
# web), els efectes que depenen del partit, els presets de qualitat i la construcció.
extends GdUnitTestSuite

const HL := Constants.HL
const GHW := Constants.GHW

# --- Disposició ----------------------------------------------------------------------


## Valors de referència calculats amb el codi de glInit() de la web (generador amb
## llavor 11): 26 blocs de pisos i 69 pins.
func test_ciutat_i_pins_com_la_web() -> void:
	var rnd := StadiumLayout.ParkMiller.new()
	var blocks := StadiumLayout.city_blocks(rnd)
	assert_int(blocks.size()).is_equal(26)
	var first: Rect2 = blocks[0][0]
	assert_float(first.position.x).is_equal_approx(-259.95523, 1e-3)
	assert_float(first.position.y).is_equal_approx(-229.70254, 1e-3)
	assert_float(first.size.x).is_equal_approx(22.85649, 1e-3)
	assert_float(first.size.y).is_equal_approx(10.54182, 1e-3)
	assert_float(blocks[0][1]).is_equal_approx(26.20879, 1e-3)
	var pines := StadiumLayout.pines(rnd)
	assert_int(pines.size()).is_equal(69)
	assert_vector(pines[0]).is_equal_approx(
		Vector3(-73.00986, -81.64344, 1.20151), Vector3.ONE * 1e-3
	)
	assert_vector(pines[-1]).is_equal_approx(
		Vector3(-68.16135, 29.86985, 0.97379), Vector3.ONE * 1e-3
	)


func test_files_de_la_grada() -> void:
	assert_float(StadiumLayout.row_z(0)).is_equal_approx(StadiumLayout.STAND_Z0, 1e-6)
	assert_float(StadiumLayout.row_z(StadiumLayout.STAND_ROWS - 1)).is_equal_approx(
		StadiumLayout.STAND_Z1, 1e-6
	)
	assert_float(StadiumLayout.row_y(0)).is_equal_approx(StadiumLayout.STAND_YF, 1e-6)
	assert_float(StadiumLayout.row_y(StadiumLayout.STAND_ROWS)).is_equal_approx(
		StadiumLayout.STAND_YB, 1e-6
	)


func test_el_sol_ve_de_darrere_la_grada() -> void:
	var sun := StadiumLayout.sun_view()
	assert_float(sun.length()).is_equal_approx(1.0, 1e-5)
	# Godot: Y amunt i −Z cap a la grada (y negativa de la simulació).
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


## Cada 5 s les tanques passen a l'anunci següent (1/8 de la textura) en 0,6 s.
func test_desplacament_de_les_tanques_led() -> void:
	assert_float(StadiumFx.led_scroll(0.0)).is_equal(0.0)
	assert_float(StadiumFx.led_scroll(0.3)).is_equal_approx(0.0625, 1e-6)
	assert_float(StadiumFx.led_scroll(2.0)).is_equal_approx(0.125, 1e-6)
	assert_float(StadiumFx.led_scroll(5.0)).is_equal_approx(0.125, 1e-6)
	assert_float(StadiumFx.led_scroll(5.6)).is_equal_approx(0.25, 1e-6)
	assert_float(StadiumFx.led_scroll(12.0)).is_equal_approx(0.375, 1e-6)


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


func test_l_estadi_es_construeix_sencer() -> void:
	var st: Stadium = auto_free(load("res://scenes/stadium.tscn").instantiate())
	add_child(st)
	for n: String in [
		"Entorn",
		"Sol",
		"Terra",
		"Grada",
		"Public",
		"LED",
		"Tanques",
		"Torres",
		"Banquetes",
		"CasaClub",
		"Ciutat",
		"Pins",
		"PorteriaEsquerra",
		"PorteriaDreta"
	]:
		assert_object(st.get_node_or_null(n)).override_failure_message(n).is_not_null()
	var spots := st.find_children("*", "SpotLight3D", true, false)
	assert_int(spots.size()).is_equal(4)
	for sp: SpotLight3D in spots:
		# L'estadi fix no fa ombra amb els focus.
		assert_int(sp.shadow_caster_mask & Stadium.STATIC_LAYER).is_equal(0)
	var seats: MultiMeshInstance3D = st.get_node("Public/Seients")
	var people: MultiMeshInstance3D = st.get_node("Public/Persones")
	var ns := seats.multimesh.instance_count
	var np := people.multimesh.instance_count
	assert_int(ns).is_greater(800)
	assert_float(float(np) / ns).is_between(Stadium.OCCUPANCY - 0.06, Stadium.OCCUPANCY + 0.06)
	st.set_night(false)
	assert_bool((st.get_node("Sol") as Light3D).visible).is_true()
	assert_bool((spots[0] as Light3D).visible).is_false()
	st.set_night(true)
	assert_bool((st.get_node("Sol") as Light3D).visible).is_false()
	assert_bool((spots[0] as Light3D).visible).is_true()
