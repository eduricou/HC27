## Menú mínim: triar equip (o només mirar), dificultat, durada del quart i hora (tarda o
## nit; el partit de demostració del fons canvia a l'acte). De fons hi juga un partit de
## demostració, com a la web. La fase 5 el completarà (càmera, opcions) i el refarà amb
## escenes.
## ref: #menu i OPTS (línies 220–240 i 343) de reference/web/index.html
class_name MainMenu
extends CanvasLayer

signal play_requested(side: int, diff: String, qlen: float)
signal night_changed(night: bool)

const DIFFS := [["facil", "Fàcil"], ["normal", "Normal"], ["dificil", "Difícil"]]
const QLENS := [[90.0, "1,5 min"], [150.0, "2,5 min"], [240.0, "4 min"]]
const CONTROLS := (
	"Moure: fletxes o WASD · palanca o creu\n"
	+ "Passar (canviar de jugador sense pilota): Espai, J o Z · botó A\n"
	+ "Xutar (mantén per carregar; sense pilota, entrada): K o X · botons X o B\n"
	+ "Esprintar: Maj o L · RB o RT        Pausa: P o Esc · Start"
)

## Com a la web, per defecte el partit és de nit (OPTS.time = 'nit').
var night := true

var _diff_i := 1
var _qlen_i := 1
var _root: Control
var _first: Button
var _diff_btn: Button
var _qlen_btn: Button
var _time_btn: Button


func _ready() -> void:
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.04, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var panel := UiKit.panel(Color(0.067, 0.11, 0.09, 0.93), 10, 36)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.label("ESTIC HOQUEI HERBA", 60, Color("f07c1a")))
	var sub := tr("Iluro HC – Club Polo · Papis (+35) · Camp Municipal d'Hoquei de Mataró")
	box.add_child(UiKit.label(sub, 22, UiKit.MUTE))
	box.add_child(HSeparator.new())
	_first = UiKit.button(tr("Juga amb l'Iluro HC"), _play.bind(0))
	box.add_child(_first)
	box.add_child(UiKit.button(tr("Juga amb el Club Polo"), _play.bind(1)))
	box.add_child(UiKit.button(tr("Només mirar (CPU contra CPU)"), _play.bind(-1)))
	box.add_child(HSeparator.new())
	_diff_btn = UiKit.button("", _cycle_diff)
	box.add_child(_diff_btn)
	_qlen_btn = UiKit.button("", _cycle_qlen)
	box.add_child(_qlen_btn)
	_time_btn = UiKit.button("", _toggle_time)
	box.add_child(_time_btn)
	box.add_child(UiKit.button(tr("Surt"), get_tree().quit))
	box.add_child(HSeparator.new())
	box.add_child(UiKit.label(tr(CONTROLS), 18, UiKit.MUTE))
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 80
	)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_refresh()


func open() -> void:
	visible = true
	_first.grab_focus.call_deferred()


func close() -> void:
	visible = false


func _play(side: int) -> void:
	play_requested.emit(side, DIFFS[_diff_i][0], QLENS[_qlen_i][0])


func _cycle_diff() -> void:
	_diff_i = (_diff_i + 1) % DIFFS.size()
	_refresh()


func _cycle_qlen() -> void:
	_qlen_i = (_qlen_i + 1) % QLENS.size()
	_refresh()


func _toggle_time() -> void:
	night = not night
	_refresh()
	night_changed.emit(night)


func _refresh() -> void:
	_diff_btn.text = tr("Dificultat de la CPU: %s") % tr(DIFFS[_diff_i][1])
	_qlen_btn.text = tr("Durada real de cada quart: %s") % QLENS[_qlen_i][1]
	_time_btn.text = tr("Hora del partit: %s") % (tr("nit") if night else tr("tarda"))
