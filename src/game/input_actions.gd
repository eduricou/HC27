## Accions d'entrada del joc, assignació per defecte de teclat i comandament, i
## reassignació (menú d'opcions, desada a user:// per GameSettings). Es registren en temps
## d'execució i no a project.godot. Les tecles van per codi físic, com e.code a la web.
## Cada acció té fins a KEY_SLOTS tecles i PAD_SLOTS botons del comandament; el moviment
## amb el comandament (palanca esquerra i creu) és fix.
## ref: línies 1090–1128 de reference/web/index.html (PASSK, SHOOTK, sampleInput())
class_name InputActions
extends RefCounted

const MOVE_DEADZONE := 0.2
const KEY_SLOTS := 3
const PAD_SLOTS := 2
## Acció que salta la presentació i la repetició (clic, Retorn); no es pot reassignar.
const SKIP := &"skip"

## Accions en l'ordre del menú de tecles.
const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"pass",
	&"shoot",
	&"sprint",
	&"pause",
]
const NAMES := {
	&"move_up": "Amunt",
	&"move_down": "Avall",
	&"move_left": "Esquerra",
	&"move_right": "Dreta",
	&"pass": "Passar · canviar de jugador",
	&"shoot": "Xutar (mantén) · entrada",
	&"sprint": "Esprintar",
	&"pause": "Pausa",
}

## Acció → {"keys": codis físics, "pad": codis del comandament}. Codis del comandament:
## "b<botó>" (JOY_BUTTON_*) o "a<eix><+|->" (JOY_AXIS_*: palanques i gatells).
const DEFAULTS := {
	&"move_up": {"keys": [KEY_W, KEY_UP], "pad": ["a1-", "b11"]},
	&"move_down": {"keys": [KEY_S, KEY_DOWN], "pad": ["a1+", "b12"]},
	&"move_left": {"keys": [KEY_A, KEY_LEFT], "pad": ["a0-", "b13"]},
	&"move_right": {"keys": [KEY_D, KEY_RIGHT], "pad": ["a0+", "b14"]},
	&"pass": {"keys": [KEY_SPACE, KEY_J, KEY_Z], "pad": ["b0"]},
	&"shoot": {"keys": [KEY_K, KEY_X], "pad": ["b2", "b1"]},
	&"sprint": {"keys": [KEY_SHIFT, KEY_L], "pad": ["b10", "a5+"]},
	&"pause": {"keys": [KEY_P, KEY_ESCAPE], "pad": ["b6"]},
}
const PAD_FIXED: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]
const PAD_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guia",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Creu ↑",
	JOY_BUTTON_DPAD_DOWN: "Creu ↓",
	JOY_BUTTON_DPAD_LEFT: "Creu ←",
	JOY_BUTTON_DPAD_RIGHT: "Creu →",
}

## Noms en català de les tecles que OS.get_keycode_string() dona en anglès.
const KEY_NAMES := {
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_SPACE: "Espai",
	KEY_ESCAPE: "Esc",
	KEY_SHIFT: "Maj",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_ENTER: "Retorn",
	KEY_KP_ENTER: "Retorn (teclat numèric)",
	KEY_TAB: "Tab",
	KEY_BACKSPACE: "Retrocés",
	KEY_DELETE: "Supr",
	KEY_INSERT: "Insert",
	KEY_HOME: "Inici",
	KEY_END: "Fi",
	KEY_PAGEUP: "Re Pàg",
	KEY_PAGEDOWN: "Av Pàg",
	KEY_CAPSLOCK: "Bloq Maj",
}

## Assignació activa (la que es desa): acció → {"keys": [...], "pad": [...]}.
static var current := {}


## Registra les accions (amb l'assignació per defecte) si encara no existeixen.
static func ensure() -> void:
	if current.is_empty():
		current = defaults()
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, MOVE_DEADZONE)
			_fill(action)
	# Godot no hi posa el comandament: A accepta i B torna enrere als menús.
	_ensure_pad(&"ui_accept", JOY_BUTTON_A)
	_ensure_pad(&"ui_cancel", JOY_BUTTON_B)
	if not InputMap.has_action(SKIP):
		InputMap.add_action(SKIP)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(SKIP, click)
		for k: Key in [KEY_ENTER, KEY_KP_ENTER]:
			InputMap.action_add_event(SKIP, key_event(k))


static func _ensure_pad(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var b := InputEventJoypadButton.new()
	b.button_index = button
	InputMap.action_add_event(action, b)


static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


## Aplica una assignació (p. ex. la desada). Les accions que hi falten o que no tenen cap
## tecla es queden amb la de per defecte.
static func apply(bindings: Dictionary) -> void:
	current = defaults()
	for action: StringName in ACTIONS:
		var b: Variant = bindings.get(action, bindings.get(String(action)))
		if b is Dictionary:
			var keys := _clean_keys(b.get("keys", []))
			var pad := _clean_pad(b.get("pad", []))
			if not keys.is_empty():
				current[action]["keys"] = keys
			if action not in PAD_FIXED:
				current[action]["pad"] = pad
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			_fill(action)
	ensure()


## Assigna una tecla (codi físic) a la casella `slot` de l'acció. Si una altra acció ja la
## feia servir, se li treu. KEY_NONE buida la casella.
static func set_key(action: StringName, slot: int, key: Key) -> void:
	if key != KEY_NONE:
		for other: StringName in ACTIONS:
			current[other]["keys"].erase(key)
	var keys: Array = current[action]["keys"]
	if key == KEY_NONE:
		if slot < keys.size():
			keys.remove_at(slot)
	elif slot < keys.size():
		keys[slot] = key
	else:
		keys.append(key)
	_fill_all()


## Igual que set_key() per al comandament (codi "b<botó>" o "a<eix><signe>"; "" buida).
static func set_pad(action: StringName, slot: int, code: String) -> void:
	if action in PAD_FIXED:
		return
	if code != "":
		for other: StringName in ACTIONS:
			if other not in PAD_FIXED:
				current[other]["pad"].erase(code)
	var pad: Array = current[action]["pad"]
	if code == "":
		if slot < pad.size():
			pad.remove_at(slot)
	elif slot < pad.size():
		pad[slot] = code
	else:
		pad.append(code)
	_fill_all()


static func reset() -> void:
	apply({})


static func key_event(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


## Esdeveniment de Godot per a un codi del comandament.
static func pad_event(code: String) -> InputEvent:
	if code.begins_with("a"):
		var m := InputEventJoypadMotion.new()
		m.axis = int(code.substr(1, code.length() - 2)) as JoyAxis
		m.axis_value = -1.0 if code.ends_with("-") else 1.0
		return m
	var b := InputEventJoypadButton.new()
	b.button_index = int(code.substr(1)) as JoyButton
	return b


## Codi del comandament d'un esdeveniment premut ("" si no ho és o si és la palanca a mitges).
static func pad_code(e: InputEvent) -> String:
	if e is InputEventJoypadButton and e.pressed:
		return "b%d" % e.button_index
	if e is InputEventJoypadMotion and absf(e.axis_value) > 0.6:
		return "a%d%s" % [e.axis, "+" if e.axis_value > 0.0 else "-"]
	return ""


## Nom d'una tecla tal com surt al teclat de l'usuari.
static func key_name(k: int) -> String:
	if k == KEY_NONE:
		return "—"
	if KEY_NAMES.has(k):
		return KEY_NAMES[k]
	var shown := DisplayServer.keyboard_get_keycode_from_physical(k as Key)
	return OS.get_keycode_string(shown if shown != KEY_NONE else k as Key)


static func pad_name(code: String) -> String:
	if code == "":
		return "—"
	if code.begins_with("a"):
		var axis := int(code.substr(1, code.length() - 2))
		var plus := code.ends_with("+")
		match axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X:
				return "Palanca E " + ("→" if plus else "←")
			JOY_AXIS_LEFT_Y:
				return "Palanca E " + ("↓" if plus else "↑")
			JOY_AXIS_RIGHT_X:
				return "Palanca D " + ("→" if plus else "←")
			JOY_AXIS_RIGHT_Y:
				return "Palanca D " + ("↓" if plus else "↑")
		return "Eix %d%s" % [axis, "+" if plus else "−"]
	var b := int(code.substr(1))
	return PAD_NAMES.get(b, "Botó %d" % b)


static func _fill_all() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			_fill(action)


static func _fill(action: StringName) -> void:
	InputMap.action_erase_events(action)
	for k: int in current[action]["keys"]:
		InputMap.action_add_event(action, key_event(k as Key))
	for code: String in current[action]["pad"]:
		InputMap.action_add_event(action, pad_event(code))


static func _clean_keys(src: Variant) -> Array:
	var out := []
	if src is Array:
		for k: Variant in src:
			if (k is int or k is float) and int(k) > 0 and int(k) not in out:
				out.append(int(k))
	return out.slice(0, KEY_SLOTS)


static func _clean_pad(src: Variant) -> Array:
	var out := []
	if src is Array:
		for c: Variant in src:
			var code := str(c)
			var ok := code.length() >= 2 and (code[0] == "b" or code[0] == "a")
			if ok and code not in out:
				out.append(code)
	return out.slice(0, PAD_SLOTS)
