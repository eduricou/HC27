# Proves de la fase 6: sons per a tots els esdeveniments, banc de sons, limitador del
# Master, volums ajustables i vibració del comandament. (Sense pantalla, MatchSound no
# reprodueix res però apunta a `played` què hauria sonat.)
extends GdUnitTestSuite

const SIM_DIR := "res://src/sim/"

var _sim: MatchSim
var _snd: MatchSound


func before_test() -> void:
	_sim = MatchSim.new(4, 150.0, 0)
	_sim.s.intro_t = 0.0
	_snd = MatchSound.new()
	add_child(_snd)
	_snd.silent = true


func after_test() -> void:
	_snd.queue_free()
	_sim.dispose()


## Tipus d'esdeveniment que emet la simulació, llegits del codi de src/sim/.
static func sim_event_types() -> Array[StringName]:
	var out: Array[StringName] = []
	var re := RegEx.create_from_string('"type":\\s*&"([a-z_]+)"')
	for f in DirAccess.get_files_at(SIM_DIR):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(SIM_DIR + f)
		for m in re.search_all(src):
			var t := StringName(m.get_string(1))
			if t not in out:
				out.append(t)
	return out


func test_tots_els_esdeveniments_tenen_so() -> void:
	var types := sim_event_types()
	assert_int(types.size()).is_greater(10)
	for t in types:
		var known := MatchSound.SOUNDS.has(t) or MatchSound.SILENT.has(t)
		assert_bool(known).override_failure_message("esdeveniment sense so: %s" % t).is_true()


func test_cada_esdeveniment_demana_el_seu_so() -> void:
	var s := _sim.s
	var p := s.teams[0].players[5]
	var gk := s.teams[1].gk
	var cases := [
		[{"type": &"kick", "player": p, "kind": &"pass", "speed": 12.0}, &"sfx/stick_pass"],
		[{"type": &"kick", "player": p, "kind": &"shot", "speed": 28.0}, &"sfx/stick_hit"],
		[{"type": &"kick", "player": p, "kind": &"hit", "speed": 20.0}, &"sfx/stick_hit"],
		[{"type": &"control", "player": p}, &"sfx/control"],
		[{"type": &"deflect", "player": p}, &"sfx/control"],
		[{"type": &"tackle", "player": p, "won": true}, &"sfx/tackle"],
		[{"type": &"save", "player": gk}, &"sfx/pads"],
		[{"type": &"post"}, &"sfx/post"],
		[{"type": &"intro_end"}, &"crowd/applause"],
		[{"type": &"quarter_end", "quarter": 1}, &"crowd/applause"],
		[{"type": &"switch", "player": p}, &"ui/switch"],
		[{"type": &"wipe", "team": 0}, &"ui/whoosh"],
	]
	for c: Array in cases:
		_snd.played.clear()
		_snd.play_event(s, c[0])
		var names := _names()
		assert_array(names).override_failure_message(str(c[0]["type"])).contains([c[1]])


func test_el_gol_fa_bum_a_la_taula_i_el_public_crida() -> void:
	var s := _sim.s
	s.ball.z = 0.1
	_snd.play_event(s, {"type": &"goal", "team": 0, "scorer": s.teams[0].players[9]})
	assert_array(_names()).contains([&"sfx/backboard", &"crowd/cheer", &"crowd/applause"])
	assert_float(_snd.excitement).is_equal(1.0)
	# Gol alt (per sobre de la taula de fons): la xarxa. Gol del Polo: només aplaudiments.
	_snd.played.clear()
	s.ball.z = 1.2
	_snd.play_event(s, {"type": &"goal", "team": 1, "scorer": s.teams[1].players[9]})
	assert_array(_names()).contains([&"sfx/net", &"crowd/applause"])
	assert_array(_names()).not_contains([&"crowd/cheer"])


func test_el_xiulet_fa_tants_bufets_com_toca() -> void:
	_snd.play_event(_sim.s, {"type": &"whistle", "strength": 0.7, "count": 3})
	assert_int(_snd.pending_blasts()).is_equal(3)


func test_xiulet_curt_per_a_les_faltes_i_llarg_per_als_finals() -> void:
	_snd.whistle(0.28, 1)
	_snd._process(0.0)
	assert_array(_names()).contains([&"sfx/whistle_short"])
	_snd.played.clear()
	_snd.whistle(0.7, 2)
	_snd._process(0.0)
	assert_array(_names()).contains([&"sfx/whistle_long"])
	# El segon bufet espera que s'acabi el primer (0,98 s) i la pausa entre bufets.
	assert_int(_snd.pending_blasts()).is_equal(1)
	_snd._process(0.9)
	assert_int(_snd.pending_blasts()).is_equal(1)
	_snd._process(0.3)
	assert_int(_snd.pending_blasts()).is_equal(0)


func test_el_pal_sona_mes_fort_com_mes_rapid() -> void:
	var s := _sim.s
	var p := s.teams[0].players[5]
	_snd.play_event(s, {"type": &"kick", "player": p, "kind": &"shot", "speed": 6.0})
	_snd.play_event(s, {"type": &"kick", "player": p, "kind": &"shot", "speed": 30.0})
	assert_float(float(_snd.played[1][1])).is_greater(float(_snd.played[0][1]) + 4.0)


func test_el_public_s_anima_al_corner_curt() -> void:
	_snd.play_event(_sim.s, {"type": &"pc", "team": 0, "reason": &"", "by": null})
	assert_float(_snd.excitement).is_greater(0.5)


func test_banc_de_sons_complet() -> void:
	for sound: StringName in SfxBank.SOUNDS:
		for st in SfxBank.variants(sound):
			assert_object(st).override_failure_message(String(sound)).is_not_null()
	# El murmuri del públic dura prou perquè el bucle no es noti.
	assert_float(SfxBank.pick(&"crowd/murmur_a").get_length()).is_greater(60.0)


func test_limitador_al_master() -> void:
	AudioBuses.ensure()
	AudioBuses.ensure()
	var master := AudioServer.get_bus_index(&"Master")
	var limiters := 0
	for k in AudioServer.get_bus_effect_count(master):
		var fx := AudioServer.get_bus_effect(master, k)
		if fx is AudioEffectHardLimiter:
			limiters += 1
			assert_float((fx as AudioEffectHardLimiter).ceiling_db).is_less_equal(-0.3)
	assert_int(limiters).is_equal(1)


func test_els_volums_de_les_opcions_s_apliquen() -> void:
	var g := GameSettings.new()
	g.volumes[&"Efectes"] = 0.25
	g.volumes[&"Ambient"] = 0.0
	g.apply_audio()
	assert_float(AudioBuses.get_volume(&"Efectes")).is_equal_approx(0.25, 0.01)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambient"))).is_true()
	GameSettings.new().apply_audio()


func test_la_vibracio_es_desa() -> void:
	var path := "user://prova_vibracio.cfg"
	var a := GameSettings.new()
	a.vibration = false
	a.save_file(path)
	var b := GameSettings.new()
	b.load_file(path)
	assert_bool(b.vibration).is_false()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_vibracio_en_xuts_entrades_i_gols() -> void:
	var s := _sim.s  # l'humà és l'Iluro (equip 0)
	var mine := s.teams[0].players[8]
	var theirs := s.teams[1].players[8]
	var shot := Rumble.pattern(s, {"type": &"kick", "player": mine, "kind": &"shot", "speed": 28.0})
	assert_float(shot.z).is_greater(0.0)
	var passing := Rumble.pattern(
		s, {"type": &"kick", "player": mine, "kind": &"pass", "speed": 12.0}
	)
	assert_float(passing.z).is_equal(0.0)
	var cpu_shot := Rumble.pattern(
		s, {"type": &"kick", "player": theirs, "kind": &"shot", "speed": 28.0}
	)
	assert_float(cpu_shot.z).is_equal(0.0)
	# Si ens prenen la pilota, vibra més que quan la prenem nosaltres.
	var ours := Rumble.pattern(s, {"type": &"tackle", "player": mine, "won": true})
	var against := Rumble.pattern(s, {"type": &"tackle", "player": theirs, "won": true})
	assert_float(against.y).is_greater(ours.y)
	var goal_for := Rumble.pattern(s, {"type": &"goal", "team": 0})
	var goal_against := Rumble.pattern(s, {"type": &"goal", "team": 1})
	assert_float(goal_for.z).is_greater(goal_against.z)
	assert_float(goal_against.z).is_greater(0.0)
	# CPU contra CPU: res.
	var demo := MatchSim.new(4, 150.0, -1)
	var g := Rumble.pattern(demo.s, {"type": &"goal", "team": 0})
	assert_float(g.z).is_equal(0.0)
	demo.dispose()


func _names() -> Array:
	var out := []
	for e: Array in _snd.played:
		out.append(e[0])
	return out
