## Pantalla de pausa (#pause de la web): resultat, quart i rellotge, i Continua, Reinicia,
## Opcions i Menú. Esc, P, Start o B la tanquen (B i Esc són ui_cancel). ref: togglePause()
class_name PauseScreen
extends Control

signal resume_requested
signal restart_requested
signal options_requested
signal menu_requested

var _title: Label
var _first: Button
var _last_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var o := UiKit.overlay(self)
	o.visible = true
	var c := UiKit.card(620.0)
	o.get_child(1).add_child(c[0])
	var box: VBoxContainer = c[1]
	box.add_child(UiKit.kicker(tr("Partit aturat"), 17, UiKit.ORANGE))
	_title = UiKit.title(tr("Pausa"), 46)
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_first = UiKit.button(tr("Continua"), resume_requested.emit, true)
	row.add_child(_first)
	row.add_child(UiKit.button(tr("Reinicia"), restart_requested.emit))
	row.add_child(UiKit.button(tr("Opcions"), _options))
	row.add_child(UiKit.button(tr("Menú"), menu_requested.emit))
	for b in row.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Control).custom_minimum_size.y = 58
	box.add_child(row)
	visible = false


func open(s: MatchState) -> void:
	_title.text = (
		"%s %d–%d %s · %dQ %s"
		% [
			s.teams[0].def.short,
			s.score[0],
			s.score[1],
			s.teams[1].def.short,
			s.quarter,
			Hud.fmt_clock(s.clock),
		]
	)
	visible = true
	_first.grab_focus.call_deferred()


## Torna el focus on era abans d'obrir les opcions.
func refocus() -> void:
	var target := _last_focus if is_instance_valid(_last_focus) else _first
	target.grab_focus.call_deferred()


func _options() -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	options_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel") or event.is_echo():
		return
	# Esc ja és la tecla de pausa (main.gd la tracta); aquí només B del comandament.
	if event.is_action(&"pause"):
		return
	get_viewport().set_input_as_handled()
	UiSounds.back()
	resume_requested.emit()
