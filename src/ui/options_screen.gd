## Menú d'opcions, des del menú principal o des de la pausa. Tres pestanyes:
## - Pantalla: mode de finestra, resolució, VSync, límit de fps, qualitat, escala FSR 2.2 i
##   la càmera dels córners curts;
## - So: volums dels busos (AudioBuses) i vibració del comandament;
## - Tecles: fins a tres tecles i dos botons del comandament per acció (InputActions).
## Cada canvi s'aplica i es desa a l'acte (GameSettings). Esc o B tornen enrere.
class_name OptionsScreen
extends CanvasLayer

signal closed
## La qualitat o l'escala FSR han canviat (main.gd les aplica a l'estadi i al viewport).
signal graphics_changed
## Opcions del joc (càmera del córner curt, vibració).
signal game_changed

const TABS := [[0, "Pantalla"], [1, "So"], [2, "Tecles"]]
const MODES := [[0, "Finestra"], [1, "Pantalla completa"], [2, "Completa exclusiva"]]
const VSYNCS := [[0, "No"], [1, "Sí"], [2, "Adaptativa"]]
const QUALITIES := [
	["baixa", "Baixa"], ["mitjana", "Mitjana"], ["alta", "Alta"], ["ultra", "Ultra"]
]
const PC_CAMS := [[true, "Darrere de la porteria"], [false, "Televisió"]]
const YES_NO := [[true, "Sí"], [false, "No"]]

var settings: GameSettings
## Fals a les proves: no escriu a user://.
var persist := true

var _root: Control
var _tabs: HBoxContainer
var _pages: Array[Control] = []
var _tab := 0
var _back: Button
var _reset_keys: Button
var _res_box: Control
var _res_opts: Array = []
var _segs := {}
var _vol_labels := {}
var _sliders := {}
var _slots := {}
var _status: Label
## Captura de tecla en curs: {"action", "slot", "pad", "button"} (buit si no n'hi ha).
var _capture := {}


func _ready() -> void:
	layer = 3
	if settings == null:
		settings = GameSettings.new()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	add_child(_root)
	var o := UiKit.overlay(_root)
	o.visible = true
	var c := UiKit.card(1120.0)
	o.get_child(1).add_child(c[0])
	var box: VBoxContainer = c[1]
	box.add_child(UiKit.kicker(tr("Estic Hoquei Herba"), 17, UiKit.ORANGE))
	box.add_child(UiKit.title(tr("Opcions"), 50))
	_tabs = UiKit.segment(_tr_opts(TABS), 0, _show_tab)
	box.add_child(_tabs)
	var pages := Control.new()
	pages.custom_minimum_size = Vector2(0, 560)
	box.add_child(pages)
	for p in [_display_page(), _sound_page(), _keys_page()]:
		(p as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		pages.add_child(p)
		_pages.append(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_back = UiKit.button(tr("Torna"), close, true)
	_back.custom_minimum_size = Vector2(260, 58)
	row.add_child(_back)
	_reset_keys = UiKit.button(tr("Restaura les tecles"), _restore_keys)
	_reset_keys.custom_minimum_size.y = 58
	row.add_child(_reset_keys)
	box.add_child(row)
	visible = false


func open() -> void:
	visible = true
	_refresh()
	_show_tab(_tab)
	(_tabs.get_child(_tab) as Button).grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	_capture = {}
	visible = false
	closed.emit()


func _show_tab(i: Variant) -> void:
	_tab = int(i)
	UiKit.segment_select(_tabs, TABS, _tab)
	for k in _pages.size():
		_pages[k].visible = k == _tab
	_reset_keys.visible = _tab == 2
	_cancel_capture()


static func _tr_opts(opts: Array) -> Array:
	var out := []
	for o: Array in opts:
		out.append([o[0], TranslationServer.translate(str(o[1]))])
	return out


# --- Pantalla ------------------------------------------------------------------------


func _display_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 16)
	var screen := DisplayServer.screen_get_size()
	for r in GameSettings.resolutions_for(screen):
		_res_opts.append([r, "%d×%d" % [r.x, r.y]])
	var fps := []
	for f in GameSettings.FPS_LIMITS:
		fps.append([f, tr("Sense límit") if f == 0 else str(f)])
	var fsr := []
	for f in GameSettings.FSR_SCALES:
		fsr.append([f, tr("Desactivada") if f >= 0.999 else "%d %%" % roundi(f * 100.0)])
	_segs["mode"] = _row(grid, tr("Mode de finestra"), _tr_opts(MODES), _set_mode)
	_segs["res"] = _row(grid, tr("Resolució de la finestra"), _res_opts, _set_res)
	_res_box = _segs["res"]
	_segs["vsync"] = _row(grid, tr("Sincronia vertical (VSync)"), _tr_opts(VSYNCS), _set_vsync)
	_segs["fps"] = _row(grid, tr("Límit de fps"), fps, _set_fps)
	_segs["quality"] = _row(grid, tr("Qualitat gràfica"), _tr_opts(QUALITIES), _set_quality)
	_segs["fsr"] = _row(grid, tr("Escala FSR 2.2"), fsr, _set_fsr)
	_segs["pc_cam"] = _row(grid, tr("Càmera dels córners curts"), _tr_opts(PC_CAMS), _set_pc_cam)
	var note := UiKit.label(
		tr("L'escala FSR dibuixa el 3D a menys resolució i l'amplia: més fps amb poca pèrdua."),
		17,
		UiKit.MUTE,
		HORIZONTAL_ALIGNMENT_LEFT,
		&"body"
	)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 18)
	wrap.add_child(grid)
	wrap.add_child(note)
	return wrap


func _row(grid: GridContainer, label: String, opts: Array, cb: Callable) -> HBoxContainer:
	var l := UiKit.kicker(label, 16)
	l.custom_minimum_size.x = 300
	grid.add_child(l)
	var seg := UiKit.segment(opts, null, cb)
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in seg.get_children():
		(b as Control).custom_minimum_size.y = 44
	grid.add_child(seg)
	seg.set_meta(&"opts", opts)
	return seg


func _set_mode(v: Variant) -> void:
	settings.window_mode = int(v)
	settings.apply_window()
	_changed()


func _set_res(v: Variant) -> void:
	settings.resolution = v
	settings.apply_window()
	_changed()


func _set_vsync(v: Variant) -> void:
	settings.vsync = int(v)
	settings.apply_window()
	_changed()


func _set_fps(v: Variant) -> void:
	settings.fps_limit = int(v)
	settings.apply_window()
	_changed()


func _set_quality(v: Variant) -> void:
	settings.quality = str(v)
	graphics_changed.emit()
	_changed()


func _set_fsr(v: Variant) -> void:
	settings.fsr = float(v)
	graphics_changed.emit()
	_changed()


func _set_pc_cam(v: Variant) -> void:
	settings.pc_cam = bool(v)
	game_changed.emit()
	_changed()


# --- So ------------------------------------------------------------------------------


func _sound_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	for bus: StringName in AudioBuses.BUSES:
		var l := UiKit.kicker(tr(AudioBuses.NAMES[bus]), 16)
		l.custom_minimum_size.x = 300
		grid.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.custom_minimum_size = Vector2(560, 36)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(_set_volume.bind(bus))
		grid.add_child(s)
		_sliders[bus] = s
		var v := UiKit.label("", 22, UiKit.INK)
		v.custom_minimum_size.x = 80
		grid.add_child(v)
		_vol_labels[bus] = v
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 34)
	box.add_child(grid)
	var vib := GridContainer.new()
	vib.columns = 2
	vib.add_theme_constant_override("h_separation", 26)
	_segs["vibration"] = _row(vib, tr("Vibració del comandament"), _tr_opts(YES_NO), _set_vibration)
	(_segs["vibration"] as Control).custom_minimum_size.x = 560
	box.add_child(vib)
	return box


func _set_vibration(v: Variant) -> void:
	settings.vibration = bool(v)
	game_changed.emit()
	_changed()
	if settings.vibration:
		Rumble.pulse(0.4, 0.6, 0.2)


func _set_volume(v: float, bus: StringName) -> void:
	settings.volumes[bus] = v / 100.0
	AudioBuses.set_volume(bus, v / 100.0)
	(_vol_labels[bus] as Label).text = "%d %%" % roundi(v)
	if visible:
		_changed()


# --- Tecles ---------------------------------------------------------------------------


func _keys_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var grid := GridContainer.new()
	grid.columns = 1 + InputActions.KEY_SLOTS + InputActions.PAD_SLOTS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
	var heads := [tr("Acció")]
	for i in InputActions.KEY_SLOTS:
		heads.append(tr("Tecla %d") % (i + 1))
	for i in InputActions.PAD_SLOTS:
		heads.append(tr("Comandament %d") % (i + 1))
	for h: String in heads:
		grid.add_child(UiKit.kicker(h, 14))
	for action: StringName in InputActions.ACTIONS:
		var l := UiKit.label(tr(InputActions.NAMES[action]), 20, UiKit.INK)
		l.custom_minimum_size.x = 280
		grid.add_child(l)
		for i in InputActions.KEY_SLOTS:
			grid.add_child(_slot(action, i, false))
		for i in InputActions.PAD_SLOTS:
			if action in InputActions.PAD_FIXED:
				var txt := tr("Palanca esquerra i creu") if i == 0 else ""
				grid.add_child(UiKit.label(txt, 17, UiKit.MUTE, HORIZONTAL_ALIGNMENT_CENTER))
			else:
				grid.add_child(_slot(action, i, true))
	box.add_child(grid)
	_status = UiKit.label("", 18, UiKit.MUTE, HORIZONTAL_ALIGNMENT_LEFT, &"body")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	return box


func _slot(action: StringName, i: int, pad: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SlotButton"
	b.custom_minimum_size = Vector2(140, 46)
	b.clip_text = true
	b.pressed.connect(_start_capture.bind(action, i, pad, b))
	_slots["%s:%s:%d" % [action, "p" if pad else "k", i]] = b
	return b


func _start_capture(action: StringName, slot: int, pad: bool, b: Button) -> void:
	_capture = {"action": action, "slot": slot, "pad": pad, "button": b}
	b.text = "…"
	var what := tr(InputActions.NAMES[action])
	if pad:
		_status.text = (
			tr("Prem el botó nou del comandament per a «%s». Back cancel·la; Retrocés la buida.")
			% what
		)
	else:
		_status.text = tr("Prem la tecla nova per a «%s». Esc cancel·la; Retrocés la buida.") % what


func _cancel_capture() -> void:
	if _capture.is_empty():
		return
	_capture = {}
	_status.text = ""
	_refresh_keys()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture.is_empty():
		_capture_input(event)
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		UiSounds.back()
		close()


func _capture_input(event: InputEvent) -> void:
	var pressed := event.is_pressed() and not event.is_echo()
	if event is InputEventMouseMotion or not pressed:
		if not (event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var action: StringName = _capture["action"]
	var slot: int = _capture["slot"]
	var b: Button = _capture["button"]
	if event is InputEventMouseButton:
		_cancel_capture()
	elif event is InputEventKey:
		var k := event as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if code == KEY_ESCAPE:
			_cancel_capture()
		elif code == KEY_BACKSPACE or code == KEY_DELETE:
			_assign(action, slot, KEY_NONE, "")
		elif not _capture["pad"]:
			_assign(action, slot, code, "")
		else:
			return
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var code := InputActions.pad_code(event)
		if code == "":
			return
		if not _capture["pad"] or code == "b%d" % JOY_BUTTON_BACK:
			_cancel_capture()
		else:
			_assign(action, slot, KEY_NONE, code)
	b.grab_focus.call_deferred()


func _assign(action: StringName, slot: int, key: Key, pad_code: String) -> void:
	if _capture["pad"]:
		InputActions.set_pad(action, slot, pad_code)
	else:
		InputActions.set_key(action, slot, key)
	_capture = {}
	_status.text = ""
	settings.store_input()
	_refresh_keys()
	_changed()


func _restore_keys() -> void:
	InputActions.reset()
	settings.store_input()
	_refresh_keys()
	_changed()


func _refresh_keys() -> void:
	for action: StringName in InputActions.ACTIONS:
		var cur: Dictionary = InputActions.current[action]
		for i in InputActions.KEY_SLOTS:
			var b: Button = _slots.get("%s:k:%d" % [action, i])
			var keys: Array = cur["keys"]
			b.text = InputActions.key_name(keys[i]) if i < keys.size() else "—"
		for i in InputActions.PAD_SLOTS:
			var b: Button = _slots.get("%s:p:%d" % [action, i])
			if b:
				var pad: Array = cur["pad"]
				b.text = InputActions.pad_name(pad[i]) if i < pad.size() else "—"


# --- Comú ------------------------------------------------------------------------------


func _refresh() -> void:
	_select("mode", settings.window_mode)
	var res := settings.resolution
	if res == Vector2i.ZERO:
		res = DisplayServer.window_get_size()
	_select("res", res)
	_res_box.modulate.a = 1.0 if settings.window_mode == 0 else 0.45
	_select("vsync", settings.vsync)
	_select("fps", settings.fps_limit)
	_select("quality", settings.quality)
	_select("fsr", settings.fsr)
	_select("pc_cam", settings.pc_cam)
	for bus: StringName in _sliders:
		(_sliders[bus] as HSlider).set_value_no_signal(roundf(settings.volumes[bus] * 100.0))
		(_vol_labels[bus] as Label).text = "%d %%" % roundi(settings.volumes[bus] * 100.0)
	_select("vibration", settings.vibration)
	_refresh_keys()


func _select(key: String, value: Variant) -> void:
	var seg: HBoxContainer = _segs[key]
	UiKit.segment_select(seg, seg.get_meta(&"opts"), value)


func _changed() -> void:
	_refresh()
	if persist:
		settings.save_file()
