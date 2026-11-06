# Proves de la fase 7 (optimització i qualitat) que no necessiten pantalla: els presets, la
# qualitat del primer cop, el renderitzador Compatibility, els mapes d'ombres, els jugadors
# que es reaprofiten entre partits, els sons carregats d'entrada, l'escalfament de shaders
# i la sonda de rendiment de tools/perf.sh.
extends GdUnitTestSuite

const TEST_CSV := "user://prova_perf.csv"
const STADIUM := preload("res://scenes/stadium.tscn")


func after_test() -> void:
	if FileAccess.file_exists(TEST_CSV):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CSV))


## L'estadi muntat dins l'arbre de la prova.
func _stadium() -> Stadium:
	var st: Stadium = auto_free(STADIUM.instantiate())
	add_child(st)
	return st


# --- Presets ------------------------------------------------------------------------


func test_presets_de_mes_barat_a_mes_car() -> void:
	var prev := {}
	for n in Quality.NAMES:
		var q := Quality.preset(n)
		assert_int(q["spot_shadows"]).is_between(0, StadiumLayout.POLES.size())
		if not prev.is_empty():
			# Com més qualitat, menys LOD i més ombres i més grans.
			assert_float(q["lod"]).override_failure_message(n).is_less(prev["lod"])
			assert_int(q["spot_shadows"]).is_greater_equal(prev["spot_shadows"])
			assert_int(q["spot_atlas"]).is_greater_equal(prev["spot_atlas"])
			assert_int(q["sun_size"]).is_greater_equal(prev["sun_size"])
		prev = q
	assert_int(Quality.preset("alta")["spot_shadows"]).is_equal(StadiumLayout.POLES.size())


func test_qualitat_del_primer_cop_segons_la_grafica() -> void:
	assert_str(Quality.for_adapter_type(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU)).is_equal("alta")
	for t in [
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU,
		RenderingDevice.DEVICE_TYPE_CPU,
		RenderingDevice.DEVICE_TYPE_OTHER,
	]:
		assert_str(Quality.for_adapter_type(t)).is_equal("baixa")


func test_preset_per_al_renderitzador_compatibility() -> void:
	var q := Quality.preset("baixa")
	q["fsr"] = 0.67
	Quality.adapt_to_renderer(q, "forward_plus")
	assert_bool(q["fxaa"]).is_true()
	assert_float(q["fsr"]).is_equal(0.67)
	Quality.adapt_to_renderer(q, "gl_compatibility")
	# Sense FXAA ni FSR: MSAA 2x en lloc de l'FXAA.
	assert_bool(q["fxaa"]).is_false()
	assert_int(q["msaa"]).is_equal(Viewport.MSAA_2X)
	assert_float(q["fsr"]).is_equal(1.0)
	var u := Quality.preset("ultra")
	Quality.adapt_to_renderer(u, "gl_compatibility")
	assert_int(u["msaa"]).is_equal(Viewport.MSAA_4X)
	assert_bool(u["ssao"]).is_false()
	assert_bool(u["ssil"]).is_false()


func test_nomes_el_mapa_d_ombres_de_la_llum_que_es_fa_servir() -> void:
	var vp := get_viewport()
	var old := vp.positional_shadow_atlas_size
	var st := _stadium()
	st.apply_quality(Quality.preset("ultra"))
	st.set_night(true)
	assert_int(vp.positional_shadow_atlas_size).is_equal(8192)
	st.set_night(false)
	assert_int(vp.positional_shadow_atlas_size).is_equal(Quality.UNUSED_ATLAS)
	# L'escalfament de shaders canvia la llum sense tocar els mapes.
	st.set_night(true, false)
	assert_int(vp.positional_shadow_atlas_size).is_equal(Quality.UNUSED_ATLAS)
	vp.positional_shadow_atlas_size = old


func test_baixa_nomes_fa_ombra_amb_dos_focus() -> void:
	var st := _stadium()
	var vp := get_viewport()
	var old := vp.positional_shadow_atlas_size
	for n in Quality.NAMES:
		var q := Quality.preset(n)
		st.apply_quality(q)
		var spots := st.find_children("*", "SpotLight3D", true, false)
		var shadowed: Array[int] = []
		for i in spots.size():
			if (spots[i] as SpotLight3D).shadow_enabled:
				shadowed.append(i)
		assert_int(shadowed.size()).override_failure_message(n).is_equal(q["spot_shadows"])
		if n == "baixa":
			# Les dues torres del mig del passeig.
			assert_array(shadowed).is_equal([1, 2])
	vp.positional_shadow_atlas_size = old


# --- Estrebades -------------------------------------------------------------------------


func test_els_jugadors_es_reaprofiten_entre_partits() -> void:
	var runner: MatchRunner = auto_free(MatchRunner.new())
	runner.start(3, 150.0, -1, "normal")
	var view: MatchView = auto_free(MatchView.new())
	view.runner = runner
	add_child(view)
	view.sync_now()
	var before := view.get_children().filter(func(c: Node) -> bool: return c is PlayerView)
	assert_int(before.size()).is_equal(22)
	var scorer := runner.sim.s.teams[0].players[9]
	view.on_events([{"type": &"goal", "team": 0, "scorer": scorer}] as Array[Dictionary])
	runner.start(4, 150.0, 0, "normal")
	view.sync_now()
	var after := view.get_children().filter(func(c: Node) -> bool: return c is PlayerView)
	# Els mateixos 22 nodes, i el que celebrava ja no ho fa.
	assert_array(after).is_equal(before)
	for v: PlayerView in after:
		assert_bool(v.is_queued_for_deletion()).is_false()
		assert_float(v.rig._action_left).is_equal(0.0)
	runner.stop()


func test_tots_els_sons_es_carreguen_d_entrada() -> void:
	SfxBank._cache.clear()
	SfxBank.preload_all()
	for snd: StringName in SfxBank.SOUNDS:
		assert_bool(SfxBank._cache.has(snd)).override_failure_message(String(snd)).is_true()


func test_l_escalfament_ho_deixa_tot_com_estava() -> void:
	var vp := get_viewport()
	var old := vp.positional_shadow_atlas_size
	var st := _stadium()
	st.apply_quality(Quality.preset("baixa"))
	st.set_night(true)
	var cam: CameraRig = auto_free(CameraRig.new())
	add_child(cam)
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	var warm: ShaderWarmup = auto_free(ShaderWarmup.new())
	add_child(warm)
	var night_seen := {}
	warm.run(st, cam, hud)
	assert_bool(warm.visible).is_true()
	assert_bool(vp.gui_disable_input).is_true()
	# Passa per tots els angles, de tarda i de nit.
	var views := 0
	while warm.running and views < 200:
		night_seen[st.night] = true
		if not cam.fixed.is_empty():
			views += 1
		await get_tree().process_frame
	assert_bool(warm.running).is_false()
	assert_int(views).is_greater_equal(ShaderWarmup.VIEWS.size() * 2)
	assert_dict(night_seen).contains_keys([true, false])
	# Tot com estava: de nit, la càmera lliure, el HUD amagat i l'entrada activa.
	assert_bool(st.night).is_true()
	assert_bool(cam.fixed.is_empty()).is_true()
	assert_bool(warm.visible).is_false()
	assert_bool(vp.gui_disable_input).is_false()
	assert_int(vp.positional_shadow_atlas_size).is_equal(2048)
	vp.positional_shadow_atlas_size = old


# --- Sonda de rendiment -------------------------------------------------------------


func test_la_sonda_compta_les_estrebades_del_partit() -> void:
	var probe: PerfProbe = auto_free(PerfProbe.new())
	probe.label = "menú"
	probe.add_frame(150.0)
	probe.label = "partit"
	for i in 120:
		probe.add_frame(8.0, {"gpu": 6.0})
	probe.add_frame(60.0)
	probe.add_frame(40.0)
	probe.label = "menú final"
	probe.add_frame(70.0)
	# Només compta l'estrebada de més de 50 ms del partit.
	assert_int(probe.report(TEST_CSV, "partit", false)).is_equal(1)
	var lines := FileAccess.get_file_as_string(TEST_CSV).strip_edges().split("\n")
	assert_int(lines.size()).is_equal(1 + 124)
	assert_str(lines[0]).starts_with("t,part,fotograma_ms")
