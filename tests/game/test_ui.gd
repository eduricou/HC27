# Proves de la fase 5: opcions desades, reassignació de tecles, càmeres (modes, repetició
# multiangle, controls relatius al córner curt), saltar la repetició i la presentació, i
# navegació dels menús només amb teclat, només amb comandament i només amb ratolí.
extends GdUnitTestSuite

const TEST_CFG := "user://prova_opcions.cfg"


func after_test() -> void:
	InputActions.reset()
	HumanController.angle = 0.0
	if FileAccess.file_exists(TEST_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))


# --- Opcions -----------------------------------------------------------------------


func test_les_opcions_es_conserven() -> void:
	var a := GameSettings.new()
	a.resolution = Vector2i(1600, 900)
	a.window_mode = 1
	a.vsync = 2
	a.fps_limit = 144
	a.quality = "baixa"
	a.fsr = 0.67
	a.volumes[&"Efectes"] = 0.35
	a.side = -1
	a.diff = "dificil"
	a.qlen = 240.0
	a.night = false
	a.cam = "ampla"
	a.pc_cam = false
	InputActions.reset()
	InputActions.set_key(&"pass", 0, KEY_Q)
	InputActions.set_pad(&"shoot", 1, "b3")
	a.store_input()
	assert_int(a.save_file(TEST_CFG)).is_equal(OK)
	InputActions.reset()
	var b := GameSettings.new()
	assert_bool(b.load_file(TEST_CFG)).is_true()
	assert_object(b.resolution).is_equal(Vector2i(1600, 900))
	assert_int(b.window_mode).is_equal(1)
	assert_int(b.vsync).is_equal(2)
	assert_int(b.fps_limit).is_equal(144)
	assert_str(b.quality).is_equal("baixa")
	assert_float(b.fsr).is_equal_approx(0.67, 1e-6)
	assert_float(b.volumes[&"Efectes"]).is_equal_approx(0.35, 1e-6)
	assert_int(b.side).is_equal(-1)
	assert_str(b.diff).is_equal("dificil")
	assert_float(b.qlen).is_equal(240.0)
	assert_bool(b.night).is_false()
	assert_str(b.cam).is_equal("ampla")
	assert_bool(b.pc_cam).is_false()
	b.apply_input()
	assert_bool(_has_key(&"pass", KEY_Q)).is_true()
	assert_bool(_has_key(&"pass", KEY_SPACE)).is_false()
	assert_array(InputActions.current[&"shoot"]["pad"]).contains(["b3"])


func test_sense_fitxer_les_opcions_per_defecte() -> void:
	var s := GameSettings.new()
	assert_bool(s.load_file("user://no_hi_es.cfg")).is_false()
	assert_str(s.quality).is_equal(Quality.DEFAULT)
	assert_bool(s.night).is_true()
	assert_float(s.fsr).is_equal(1.0)


func test_opcions_dolentes_no_trenquen_res() -> void:
	var cf := ConfigFile.new()
	cf.set_value("pantalla", "qualitat", "extrema")
	cf.set_value("pantalla", "mode", 9)
	cf.set_value("partit", "quart", 33.0)
	cf.set_value("tecles", "pass", {"keys": ["x", -4], "pad": [7]})
	cf.save(TEST_CFG)
	var s := GameSettings.new()
	s.load_file(TEST_CFG)
	assert_str(s.quality).is_equal(Quality.DEFAULT)
	assert_int(s.window_mode).is_equal(2)
	assert_float(s.qlen).is_equal(150.0)
	s.apply_input()
	# Sense cap tecla vàlida, l'acció es queda amb les de per defecte.
	assert_bool(_has_key(&"pass", KEY_SPACE)).is_true()


func test_una_tecla_nomes_fa_una_accio() -> void:
	InputActions.reset()
	InputActions.set_key(&"shoot", 0, KEY_SPACE)
	assert_bool(_has_key(&"shoot", KEY_SPACE)).is_true()
	assert_bool(_has_key(&"pass", KEY_SPACE)).is_false()
	InputActions.set_key(&"shoot", 0, KEY_NONE)
	assert_bool(_has_key(&"shoot", KEY_SPACE)).is_false()


func test_codis_del_comandament() -> void:
	for code: String in ["b0", "b10", "a5+", "a1-"]:
		var e := InputActions.pad_event(code)
		if e is InputEventJoypadButton:
			(e as InputEventJoypadButton).pressed = true
		assert_str(InputActions.pad_code(e)).is_equal(code)
	assert_str(InputActions.pad_name("a5+")).is_equal("RT")
	assert_str(InputActions.pad_name("b0")).is_equal("A")
	assert_str(InputActions.key_name(KEY_SPACE)).is_equal("Espai")


func test_busos_i_volums() -> void:
	AudioBuses.ensure()
	for bus in AudioBuses.BUSES:
		assert_int(AudioServer.get_bus_index(bus)).is_greater_equal(0)
	AudioBuses.set_volume(&"Ambient", 0.5)
	assert_float(AudioBuses.get_volume(&"Ambient")).is_equal_approx(0.5, 0.01)
	AudioBuses.set_volume(&"Ambient", 0.0)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambient"))).is_true()
	AudioBuses.set_volume(&"Ambient", 0.8)


# --- Càmeres ------------------------------------------------------------------------


func test_modes_de_la_camera() -> void:
	var sim := MatchSim.new(3, 150.0, -1)
	var s := sim.s
	var cam: CameraRig = auto_free(CameraRig.new())
	assert_int(cam.pick_mode(s)).is_equal(CameraRig.Mode.INTRO)
	s.intro_t = 0.0
	assert_int(cam.pick_mode(s)).is_equal(CameraRig.Mode.TV)
	Rules.setup_pc(s, s.teams[1], -1.0, &"prova")
	cam.mode = cam.pick_mode(s)
	assert_int(cam.mode).is_equal(CameraRig.Mode.PC)
	cam.pc_enabled = false
	assert_int(cam.pick_mode(s)).is_equal(CameraRig.Mode.TV)
	cam.pc_enabled = true
	s.state = &"goal"
	s.state_t = 0.3
	# Durant el primer moment del gol, la càmera no canvia.
	assert_int(cam.pick_mode(s)).is_equal(CameraRig.Mode.PC)
	s.state_t = 0.8
	assert_int(cam.pick_mode(s)).is_equal(CameraRig.Mode.GOAL)
	s.state = &"replay"
	assert_int(cam.pick_mode(s)).is_equal(CameraRig.Mode.REPLAY)
	sim.dispose()


func test_repeticio_multiangle() -> void:
	# 300 fotogrames: aèria, banda arran de gespa i, al final, darrere de la porteria.
	assert_int(CameraRig.replay_angle(0.0, 300)).is_equal(0)
	assert_int(CameraRig.replay_angle(150.0, 300)).is_equal(1)
	assert_int(CameraRig.replay_angle(250.0, 300)).is_equal(2)
	assert_int(CameraRig.replay_angle(299.0, 300)).is_equal(2)
	# Una repetició curta comença directament amb l'angle de la porteria.
	assert_int(CameraRig.replay_angle(0.0, 80)).is_equal(2)


func test_controls_relatius_a_la_camera_del_corner() -> void:
	var cam: CameraRig = auto_free(CameraRig.new())
	cam.mode = CameraRig.Mode.TV
	assert_float(cam.control_angle()).is_equal(0.0)
	# Darrere de la porteria de +x, mirant cap a −x: amunt a la pantalla és −x.
	cam.mode = CameraRig.Mode.PC
	cam.ex = Constants.HL + 7.0
	cam.ey = 0.0
	cam.tx = Constants.HL - 9.0
	cam.ty = 0.0
	var a := cam.control_angle()
	var inp := SimInput.new()
	HumanController.angle = 0.0
	HumanController.compose(inp, Vector2.ZERO, false, false, false, false, false, a)
	HumanController.compose(inp, Vector2(0.0, -1.0), false, false, false, false, false, a)
	assert_float(inp.mv.x).is_equal_approx(-1.0, 1e-5)
	assert_float(inp.mv.y).is_equal_approx(0.0, 1e-5)
	# Dreta a la pantalla és −y (la banda de les banquetes queda a la dreta).
	HumanController.compose(inp, Vector2(1.0, 0.0), false, false, false, false, false, a)
	assert_float(inp.mv.y).is_equal_approx(-1.0, 1e-5)
	# Si la càmera canvia amb la palanca premuda, la direcció no canvia fins que es deixa.
	HumanController.compose(inp, Vector2(1.0, 0.0), false, false, false, false, false, 0.0)
	assert_float(inp.mv.y).is_equal_approx(-1.0, 1e-5)
	HumanController.compose(inp, Vector2.ZERO, false, false, false, false, false, 0.0)
	HumanController.compose(inp, Vector2(1.0, 0.0), false, false, false, false, false, 0.0)
	assert_float(inp.mv.x).is_equal_approx(1.0, 1e-5)


func test_cortineta() -> void:
	assert_float(Wipe.offset_at(0.0)).is_equal_approx(-1.6, 1e-4)
	assert_float(Wipe.offset_at(0.5)).is_equal(0.0)
	assert_float(Wipe.offset_at(1.0)).is_equal_approx(1.6, 1e-4)
	assert_float(Wipe.ease_curve(0.5)).is_equal_approx(0.5, 1e-3)


# --- Saltar la presentació i la repetició (també CPU contra CPU) -------------------


func test_la_repeticio_es_pot_saltar() -> void:
	var r: MatchRunner = auto_free(MatchRunner.new())
	r.start(11, 150.0, -1, "normal")
	var s := r.sim.s
	# Presentació: un toc de PASSA la salta encara que no hi hagi cap humà.
	assert_float(s.intro_t).is_greater(0.0)
	_press_once(r, &"pass")
	assert_float(s.intro_t).is_equal(0.0)
	var steps := 0
	while s.state != &"replay" and steps < 60 * 900:
		r.tick()
		steps += 1
	assert_str(s.state).is_equal("replay")
	for i in 30:
		r.tick()
	# Un clic del ratolí (acció skip) talla la repetició i torna el servei de centre.
	_press_once(r, InputActions.SKIP)
	assert_float(s.rp_end).is_greater(0.0)
	for i in 30:
		r.tick()
	assert_str(s.state).is_not_equal("replay")
	r.stop()


func _press_once(r: MatchRunner, action: StringName) -> void:
	InputActions.ensure()
	Input.action_press(action)
	r.tick()
	Input.action_release(action)


# --- Navegació dels menús --------------------------------------------------------------


func test_les_accions_d_interficie_tenen_teclat_i_comandament() -> void:
	InputActions.ensure()
	for a: StringName in [
		&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel"
	]:
		var key := false
		var pad := false
		for e in InputMap.action_get_events(a):
			key = key or e is InputEventKey
			pad = pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		assert_bool(key and pad).override_failure_message(String(a)).is_true()


func test_menu_principal_navegable() -> void:
	InputActions.ensure()
	var menu := MainMenu.new()
	add_child(menu)
	_disarm_quit(menu)
	menu.open()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_reachable(menu, menu.get("_go"))
	# Teclat: la fletxa avall i Retorn; comandament: creu i A.
	var first: Button = menu.get("_go")
	first.grab_focus()
	var hits := [0]
	var target := first.find_valid_focus_neighbor(SIDE_BOTTOM) as Button
	assert_object(target).is_not_null()
	target.pressed.connect(func() -> void: hits[0] += 1)
	_key(KEY_DOWN)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(target)
	_joy(JOY_BUTTON_DPAD_UP)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(first)
	_joy(JOY_BUTTON_DPAD_DOWN)
	_joy(JOY_BUTTON_A)
	_key(KEY_ENTER)
	assert_int(hits[0]).is_equal(2)
	# Ratolí: un clic al centre del botó (quan la pantalla ja s'ha recol·locat).
	await get_tree().process_frame
	await get_tree().process_frame
	_click(target)
	assert_int(hits[0]).is_equal(3)
	menu.queue_free()


func test_opcions_navegables() -> void:
	InputActions.ensure()
	var o := OptionsScreen.new()
	o.persist = false
	add_child(o)
	o.open()
	for tab in 3:
		o.call(&"_show_tab", tab)
		await get_tree().process_frame
		await get_tree().process_frame
		var tabs: HBoxContainer = o.get("_tabs")
		_assert_reachable(o, tabs.get_child(tab))
	# Esc (o B) tanca les opcions.
	var closed := [0]
	o.closed.connect(func() -> void: closed[0] += 1)
	_joy(JOY_BUTTON_B)
	assert_int(closed[0]).is_equal(1)
	assert_bool(o.visible).is_false()
	o.queue_free()


func test_canviar_una_tecla_des_de_les_opcions() -> void:
	var o := OptionsScreen.new()
	o.persist = false
	add_child(o)
	o.open()
	o.call(&"_show_tab", 2)
	await get_tree().process_frame
	var slots: Dictionary = o.get("_slots")
	var b: Button = slots["pass:k:0"]
	b.pressed.emit()
	_key(KEY_U)
	assert_bool(_has_key(&"pass", KEY_U)).is_true()
	assert_str(b.text).is_equal("U")
	# Botó del comandament.
	var pb: Button = slots["sprint:p:0"]
	pb.pressed.emit()
	_joy(JOY_BUTTON_Y)
	assert_array(InputActions.current[&"sprint"]["pad"]).contains(["b%d" % JOY_BUTTON_Y])
	# Esc durant la captura només la cancel·la.
	b.pressed.emit()
	_key(KEY_ESCAPE)
	assert_bool(o.visible).is_true()
	assert_bool(_has_key(&"pass", KEY_U)).is_true()
	o.queue_free()


func test_pausa_i_descans_navegables() -> void:
	var hud := Hud.new()
	add_child(hud)
	hud.set_match_visible(true)
	var sim := MatchSim.new(5, 150.0, 0)
	hud.pause_screen.open(sim.s)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_reachable(hud.pause_screen, hud.pause_screen.get("_first"))
	hud.pause_screen.visible = false
	hud.break_screen.open(sim.s, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var first := get_viewport().gui_get_focus_owner()
	assert_object(first).is_not_null()
	_assert_reachable(hud.break_screen, first)
	sim.dispose()
	hud.queue_free()


## Tots els botons i lliscadors visibles de `root` s'han de poder assolir amb les fletxes
## des de `start` (teclat i comandament fan servir les mateixes accions ui_*), i s'hi ha
## de poder fer clic (mida i filtre del ratolí).
func _assert_reachable(root: Node, start: Control) -> void:
	var all: Array[Control] = []
	_collect(root, all)
	assert_int(all.size()).is_greater(0)
	var seen := {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var n := c.find_valid_focus_neighbor(side)
			if n and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for c in all:
		var label: String = (c as Button).text if c is Button else c.get_class()
		assert_bool(seen.has(c)).override_failure_message("no s'hi arriba: %s" % label).is_true()
		assert_bool(c.mouse_filter == Control.MOUSE_FILTER_STOP).is_true()
		assert_bool(c.size.x > 10.0 and c.size.y > 10.0).is_true()


func _collect(n: Node, out: Array[Control]) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if (n is BaseButton or n is Slider) and (n as Control).focus_mode != Control.FOCUS_NONE:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


## El botó Surt tancaria el procés de proves.
func _disarm_quit(n: Node) -> void:
	if n is Button and (n as Button).text == "Surt":
		for c in (n as Button).pressed.get_connections():
			(n as Button).pressed.disconnect(c["callable"])
	for ch in n.get_children():
		_disarm_quit(ch)


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		get_viewport().push_input(e)


func _joy(b: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pressed
		get_viewport().push_input(e)


func _click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		# Coordenades del llenç (les dels Control), no de la finestra.
		get_viewport().push_input(e, true)


func _has_key(action: StringName, k: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == k:
			return true
	return false
