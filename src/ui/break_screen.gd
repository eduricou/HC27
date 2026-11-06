## Pantalla de descans i de final (#brk de la web): escuts i resultat, golejadors,
## estadístiques amb barres i els botons per continuar. ref: showBreak(), statsRows()
class_name BreakScreen
extends Control

signal next_quarter_requested
signal play_again_requested
signal menu_requested

const ORD: Array[String] = ["1r", "2n", "3r", "4t"]
const BAR_B := Color("dfe6f5")

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var o := UiKit.overlay(self)
	o.visible = true
	var c := UiKit.card(700.0)
	o.get_child(1).add_child(c[0])
	_box = c[1]
	visible = false


## Omple i mostra la targeta. full: final del partit.
func open(s: MatchState, full: bool) -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	var q := s.quarter
	var kick := tr("Final del %s quart") % ORD[q - 1]
	if full:
		var res := tr("Empat")
		if s.score[0] != s.score[1]:
			res = tr("Guanya l'Iluro HC") if s.score[0] > s.score[1] else tr("Guanya el Club Polo")
		kick = tr("Final del partit") + " · " + res
	elif q == 2:
		kick = tr("Mitja part")
	_box.add_child(UiKit.kicker(kick, 18, UiKit.ORANGE))
	_box.add_child(_score_line(s))
	var goals := _goals(s)
	if goals:
		_box.add_child(goals)
	_box.add_child(_stats(s))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var first: Button
	if full:
		first = UiKit.button(tr("Torna a jugar"), play_again_requested.emit, true)
		row.add_child(first)
		row.add_child(UiKit.button(tr("Menú"), menu_requested.emit))
	else:
		first = UiKit.button(tr("Comença el %s quart") % ORD[q], next_quarter_requested.emit, true)
		row.add_child(first)
	for b in row.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Control).custom_minimum_size.y = 58
	_box.add_child(row)
	visible = true
	first.grab_focus.call_deferred()


func _score_line(s: MatchState) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	for i in 2:
		var side := HBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
		side.add_theme_constant_override("separation", 10)
		var nm := UiKit.label(
			s.teams[i].def.name, 26, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, &"ui_bold"
		)
		var crest := UiKit.crest_rect(i, 46.0)
		if i == 0:
			side.add_child(crest)
			side.add_child(nm)
		else:
			side.add_child(nm)
			side.add_child(crest)
		line.add_child(side)
		if i == 0:
			var score := "%d–%d" % [s.score[0], s.score[1]]
			line.add_child(
				UiKit.label(score, 62, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, &"display")
			)
	return line


## Golejadors de cada equip, en dues columnes (.goals). Nul si encara no n'hi ha.
func _goals(s: MatchState) -> Control:
	if s.goals.is_empty():
		return null
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 2)
	var home: Array[Dictionary] = []
	var away: Array[Dictionary] = []
	for g in s.goals:
		(home if g["team"] == 0 else away).append(g)
	for i in maxi(home.size(), away.size()):
		var a := "%d' %s" % [home[i]["minute"], home[i]["name"]] if i < home.size() else ""
		var b := "%s %d'" % [away[i]["name"], away[i]["minute"]] if i < away.size() else ""
		var la := UiKit.label(a, 19, UiKit.MUTE, HORIZONTAL_ALIGNMENT_LEFT, &"ui_medium")
		var lb := UiKit.label(b, 19, UiKit.MUTE, HORIZONTAL_ALIGNMENT_RIGHT, &"ui_medium")
		la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(la)
		grid.add_child(lb)
	return grid


## Files d'estadístiques: valor, nom i valor, i una barra repartida. ref: statsRows()
static func stat_rows(s: MatchState) -> Array:
	var tp := s.stat_poss[0] + s.stat_poss[1]
	if tp <= 0.0:
		tp = 1.0
	var p0 := roundi(s.stat_poss[0] / tp * 100.0)
	var p1 := roundi(s.stat_poss[1] / tp * 100.0)
	return [
		["Possessió", "%d%%" % p0, "%d%%" % p1, s.stat_poss[0], s.stat_poss[1]],
		[
			"Xuts des del cercle",
			str(s.stat_shots[0]),
			str(s.stat_shots[1]),
			s.stat_shots[0],
			s.stat_shots[1]
		],
		["Xuts a porteria", str(s.stat_on[0]), str(s.stat_on[1]), s.stat_on[0], s.stat_on[1]],
		["Córners curts", str(s.stat_pcs[0]), str(s.stat_pcs[1]), s.stat_pcs[0], s.stat_pcs[1]],
		["Faltes", str(s.stat_fouls[0]), str(s.stat_fouls[1]), s.stat_fouls[0], s.stat_fouls[1]],
	]


func _stats(s: MatchState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	for r: Array in stat_rows(s):
		var row := HBoxContainer.new()
		var a := UiKit.label(r[1], 22, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, &"ui")
		var lab := UiKit.kicker(tr(r[0]), 15)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := UiKit.label(r[2], 22, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, &"ui")
		a.custom_minimum_size.x = 60
		b.custom_minimum_size.x = 60
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(lab)
		row.add_child(b)
		box.add_child(row)
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 3)
		var va := float(r[3])
		var vb := float(r[4])
		var tot := va + vb
		if tot <= 0.0:
			tot = 1.0
		for k in 2:
			var seg := ColorRect.new()
			seg.color = UiKit.ORANGE if k == 0 else BAR_B
			seg.custom_minimum_size.y = 5
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.size_flags_stretch_ratio = (va if k == 0 else vb) / tot + 0.001
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(seg)
		box.add_child(bar)
	return box
