## Sons de la interfície (bus Interfície): un toc en moure el focus amb el teclat o el
## comandament, un clic en prémer un botó i un altre en tornar enrere. UiKit hi connecta
## tots els botons que crea.
class_name UiSounds
extends Node

static var _inst: UiSounds

## Sense pantalla no sona res (vegeu MatchSound.silent).
var silent := DisplayServer.get_name() == "headless"

var _focus: AudioStreamPlayer
var _press: AudioStreamPlayer
var _back: AudioStreamPlayer


func _ready() -> void:
	_inst = self
	_focus = _player(&"ui/focus", -16.0)
	_press = _player(&"ui/press", -10.0)
	_back = _player(&"ui/back", -10.0)
	get_viewport().gui_focus_changed.connect(_on_focus)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _player(sound: StringName, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Interficie"
	p.stream = SfxBank.pick(sound)
	p.volume_db = db
	add_child(p)
	return p


static func press() -> void:
	if _inst and not _inst.silent:
		_inst._press.play()


static func back() -> void:
	if _inst and not _inst.silent:
		_inst._back.play()


func _on_focus(c: Control) -> void:
	# Amb el ratolí, el clic ja sona; el focus que canvia en fer-hi clic, no.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if (c is BaseButton or c is Slider) and not silent:
		_focus.play()
