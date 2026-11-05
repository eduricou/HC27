## Accions d'entrada del joc i assignació per defecte de teclat i comandament.
## Es registren en temps d'execució (i no a project.godot) perquè la fase 5 les ha de
## poder reassignar i desar a user://. Les tecles van per codi físic, com e.code a la web.
## ref: línies 1090–1128 de reference/web/index.html (PASSK, SHOOTK, sampleInput())
class_name InputActions
extends RefCounted

const MOVE_DEADZONE := 0.2

## Acció → esdeveniments: ["key", tecla] · ["button", botó] · ["axis", eix, valor].
const DEFAULTS := {
	&"move_left":
	[
		["key", KEY_A],
		["key", KEY_LEFT],
		["axis", JOY_AXIS_LEFT_X, -1.0],
		["button", JOY_BUTTON_DPAD_LEFT],
	],
	&"move_right":
	[
		["key", KEY_D],
		["key", KEY_RIGHT],
		["axis", JOY_AXIS_LEFT_X, 1.0],
		["button", JOY_BUTTON_DPAD_RIGHT],
	],
	&"move_up":
	[
		["key", KEY_W],
		["key", KEY_UP],
		["axis", JOY_AXIS_LEFT_Y, -1.0],
		["button", JOY_BUTTON_DPAD_UP],
	],
	&"move_down":
	[
		["key", KEY_S],
		["key", KEY_DOWN],
		["axis", JOY_AXIS_LEFT_Y, 1.0],
		["button", JOY_BUTTON_DPAD_DOWN],
	],
	&"pass": [["key", KEY_SPACE], ["key", KEY_J], ["key", KEY_Z], ["button", JOY_BUTTON_A]],
	&"shoot": [["key", KEY_K], ["key", KEY_X], ["button", JOY_BUTTON_X], ["button", JOY_BUTTON_B]],
	&"sprint":
	[
		["key", KEY_SHIFT],
		["key", KEY_L],
		["button", JOY_BUTTON_RIGHT_SHOULDER],
		["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0],
	],
	&"pause": [["key", KEY_P], ["key", KEY_ESCAPE], ["button", JOY_BUTTON_START]],
}


## Registra les accions que encara no existeixen.
static func ensure() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, MOVE_DEADZONE)
		for spec: Array in DEFAULTS[action]:
			InputMap.action_add_event(action, make_event(spec))


static func make_event(spec: Array) -> InputEvent:
	if spec[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = spec[1]
		return k
	if spec[0] == "button":
		var b := InputEventJoypadButton.new()
		b.button_index = spec[1]
		return b
	var m := InputEventJoypadMotion.new()
	m.axis = spec[1]
	m.axis_value = spec[2]
	return m
