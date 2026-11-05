## HUD mínim de la fase 2: marcador, quart i rellotge, rètols, indicacions, qui porta la
## pilota, barra de potència del xut i les pantalles de presentació, pausa, descans i
## final. Es construeix des del codi; la fase 5 el refarà amb escenes (ui/*.tscn).
## ref: línies 1870–1938 (updateHUD(), banner(), showBreak()) de reference/web/index.html
class_name Hud
extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested
signal next_quarter_requested
signal play_again_requested

const ORD: Array[String] = ["1r", "2n", "3r", "4t"]
const RESTART_NAMES := {
	&"free": "Cop franc",
	&"side": "Treta de banda",
	&"hitout": "Sortida",
	&"long": "Córner llarg",
	&"center": "Servei del centre",
}
const INK := UiKit.INK
const MUTE := UiKit.MUTE
const PANEL := UiKit.PANEL
const DIM := UiKit.DIM

var runner: MatchRunner

var _root: Control
var _score: Label
var _quarter: Label
var _clock: Label
var _banner: PanelContainer
var _banner_box: StyleBoxFlat
var _banner_title: Label
var _banner_sub: Label
var _banner_t := 0.0
var _hint: Label
var _carrier: Label
var _charge: ProgressBar
var _replay: Label
var _intro: Control
var _pause: Control
var _pause_sub: Label
var _pause_first: Button
var _break: Control
var _break_box: VBoxContainer


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_scoreboard()
	_build_banner()
	_hint = UiKit.label("", 26, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_place(_hint, Control.PRESET_CENTER_BOTTOM, 70)
	_carrier = UiKit.label("", 24, INK)
	_carrier.add_theme_constant_override("outline_size", 6)
	_carrier.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_place(_carrier, Control.PRESET_BOTTOM_LEFT, 28)
	_charge = ProgressBar.new()
	_charge.max_value = 1.0
	_charge.show_percentage = false
	_charge.custom_minimum_size = Vector2(320, 16)
	_place(_charge, Control.PRESET_CENTER_BOTTOM, 120)
	_replay = UiKit.label(tr("REPETICIÓ"), 28, Color("ffd34d"))
	_place(_replay, Control.PRESET_TOP_RIGHT, 28)
	_build_intro()
	_build_pause()
	_break = _overlay()
	_break_box = VBoxContainer.new()
	_break_box.add_theme_constant_override("separation", 14)
	_break.get_child(1).get_child(0).add_child(_break_box)
	set_match_visible(false)


## Mostra o amaga tot el HUD de partit (al menú no es veu).
func set_match_visible(on: bool) -> void:
	_root.visible = on
	if not on:
		_banner.visible = false
		_pause.visible = false
		_break.visible = false


func _process(delta: float) -> void:
	if not _root.visible or runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	_score.text = "%d–%d" % [s.score[0], s.score[1]]
	_quarter.text = "%dQ" % s.quarter
	_clock.text = fmt_clock(s.clock)
	var c := s.ball.owner
	_carrier.text = "%d · %s" % [c.num, c.name] if c else ""
	if c:
		# El color «mini» de cada equip és el que contrasta sobre la gespa (minimapa de la web).
		_carrier.add_theme_color_override("font_color", Color(c.team.def.mini))
	var human := s.human_idx >= 0
	_charge.visible = human and s.charge > 0.0
	_charge.value = s.charge
	_replay.visible = s.state == &"replay"
	_intro.visible = s.intro_t > 0.0
	_hint.text = hint_text(s)
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.visible = false


## Rètols a partir dels esdeveniments de la simulació. ref: banner()
func on_events(events: Array[Dictionary]) -> void:
	if runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	for e in events:
		var t: StringName = e["type"]
		# Al partit de demostració del menú només es mostren els gols (com a la web).
		if s.mode != &"match" and t != &"goal":
			continue
		if t == &"restart" and e["kind"] != &"center":
			var team := s.teams[e["team"]]
			var sub: String = team.def.name
			if e["reason"] == &"foul" and e["by"]:
				sub = tr("Falta de %s") % e["by"].name
			elif e["reason"] == &"no_circle":
				sub = tr("Gol anul·lat: no s'ha xutat des del cercle")
			show_banner(tr(RESTART_NAMES[e["kind"]]), sub, team, 1.5)
		elif t == &"pc":
			var team := s.teams[e["team"]]
			var sub: String = team.def.name
			if e["reason"] == &"foul_circle":
				sub = tr("Falta dins del cercle")
			elif e["reason"] == &"foot" and e["by"]:
				sub = tr("Bola al peu de %s") % e["by"].name
			show_banner(tr("Córner curt"), sub, team, 1.8)
		elif t == &"goal":
			var sc: Player = e["scorer"]
			show_banner(tr("Gol!"), "%d · %s" % [sc.num, sc.name], s.teams[e["team"]], 2.6)
		elif t == &"save":
			var gk: Player = e["player"]
			show_banner(tr("Aturada"), "%d · %s" % [gk.num, gk.name], gk.team, 1.1)


func show_banner(title: String, sub: String, team: Team, dur: float) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	var col := Color(team.def.color) if team else INK
	var ink := Color(team.def.ink) if team else Color("111111")
	_banner_box.bg_color = col
	_banner_title.add_theme_color_override("font_color", ink)
	_banner_sub.add_theme_color_override("font_color", ink)
	_banner.visible = true
	_banner_t = dur


## Indicacions per a l'humà a les represes i al penal córner. ref: updateRestart(), updatePC()
static func hint_text(s: MatchState) -> String:
	if s.human_idx < 0 or s.ctrl == null:
		return ""
	if s.state == &"restart" and s.restart_team == s.ctrl.team and s.ctrl == s.restart_taker:
		if s.state_t > 1.2:
			if s.restart_type == &"center":
				return TranslationServer.translate("PASSA per fer el servei")
			return TranslationServer.translate("PASSA o XUTA per treure · mou-te per conduir")
	if s.state == &"pc" and s.pc_team.human and s.ctrl == s.pc_inj and s.state_t > 0.4:
		return TranslationServer.translate("PASSA per injectar la bola")
	return ""


## ref: fmtClock()
static func fmt_clock(secs: float) -> String:
	var t := int(ceil(secs))
	return "%d:%02d" % [floori(t / 60.0), t % 60]


func show_pause(on: bool) -> void:
	_pause.visible = on
	if on and runner and runner.sim:
		var s := runner.sim.s
		_pause_sub.text = (
			"%s %d–%d %s · %dQ %s"
			% [
				s.teams[0].def.short,
				s.score[0],
				s.score[1],
				s.teams[1].def.short,
				s.quarter,
				fmt_clock(s.clock),
			]
		)
		_pause_first.grab_focus.call_deferred()


## Pantalla de descans o de final. ref: showBreak()
func show_break(full: bool) -> void:
	var s := runner.sim.s
	for c in _break_box.get_children():
		c.queue_free()
	var q := s.quarter
	var title := ""
	if full:
		var res := tr("Empat")
		if s.score[0] != s.score[1]:
			res = tr("Guanya l'Iluro HC") if s.score[0] > s.score[1] else tr("Guanya el Club Polo")
		title = tr("Final del partit") + " · " + res
	elif q == 2:
		title = tr("Mitja part")
	else:
		title = tr("Final del %s quart") % ORD[q - 1]
	_break_box.add_child(UiKit.label(title, 34, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var score := (
		"%s  %d–%d  %s" % [s.teams[0].def.short, s.score[0], s.score[1], s.teams[1].def.short]
	)
	_break_box.add_child(UiKit.label(score, 64, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var goals := GridContainer.new()
	goals.columns = 2
	goals.add_theme_constant_override("h_separation", 60)
	var home: Array[Dictionary] = []
	var away: Array[Dictionary] = []
	for g in s.goals:
		(home if g["team"] == 0 else away).append(g)
	for i in maxi(home.size(), away.size()):
		var a := "%d' %s" % [home[i]["minute"], home[i]["name"]] if i < home.size() else ""
		var b := "%s %d'" % [away[i]["name"], away[i]["minute"]] if i < away.size() else ""
		goals.add_child(UiKit.label(a, 20, MUTE, HORIZONTAL_ALIGNMENT_RIGHT))
		goals.add_child(UiKit.label(b, 20, MUTE))
	var gc := CenterContainer.new()
	gc.add_child(goals)
	_break_box.add_child(gc)
	_break_box.add_child(_stats_grid(s))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var first: Button
	if full:
		first = UiKit.button(tr("Torna a jugar"), play_again_requested.emit)
		row.add_child(first)
		row.add_child(UiKit.button(tr("Menú"), menu_requested.emit))
	else:
		first = UiKit.button(tr("Comença el %s quart") % ORD[q], next_quarter_requested.emit)
		row.add_child(first)
	_break_box.add_child(row)
	_banner.visible = false
	_break.visible = true
	first.grab_focus.call_deferred()


func hide_break() -> void:
	_break.visible = false


## Estadístiques del descans. ref: statsRows()
func _stats_grid(s: MatchState) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	var tp := s.stat_poss[0] + s.stat_poss[1]
	if tp <= 0.0:
		tp = 1.0
	var rows := [
		[
			tr("Possessió"),
			"%d%%" % roundi(s.stat_poss[0] / tp * 100.0),
			"%d%%" % roundi(s.stat_poss[1] / tp * 100.0)
		],
		[tr("Xuts des del cercle"), str(s.stat_shots[0]), str(s.stat_shots[1])],
		[tr("Xuts a porteria"), str(s.stat_on[0]), str(s.stat_on[1])],
		[tr("Córners curts"), str(s.stat_pcs[0]), str(s.stat_pcs[1])],
		[tr("Faltes"), str(s.stat_fouls[0]), str(s.stat_fouls[1])],
	]
	for r: Array in rows:
		grid.add_child(UiKit.label(r[1], 24, INK, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(UiKit.label(r[0], 20, MUTE, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(UiKit.label(r[2], 24, INK))
	var cc := CenterContainer.new()
	cc.add_child(grid)
	return cc


func _build_scoreboard() -> void:
	var board := UiKit.panel(PANEL, 6, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	board.add_child(row)
	row.add_child(_chip("ILU", Color("f07c1a"), Color("241002")))
	_score = UiKit.label("0–0", 34, INK)
	row.add_child(_score)
	row.add_child(_chip("POL", Color("14234b"), Color("ffffff")))
	row.add_child(VSeparator.new())
	_quarter = UiKit.label("1Q", 28, MUTE)
	row.add_child(_quarter)
	_clock = UiKit.label("15:00", 34, INK)
	row.add_child(_clock)
	_place(board, Control.PRESET_TOP_LEFT, 24)


func _build_banner() -> void:
	_banner = UiKit.panel(INK, 4, 18)
	_banner_box = _banner.get_theme_stylebox("panel") as StyleBoxFlat
	var box := VBoxContainer.new()
	_banner_title = UiKit.label("", 46, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub = UiKit.label("", 24, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_banner_title)
	box.add_child(_banner_sub)
	_banner.add_child(box)
	_banner.custom_minimum_size = Vector2(420, 0)
	_place(_banner, Control.PRESET_CENTER_TOP, 110)
	_banner.visible = false


func _build_intro() -> void:
	_intro = CenterContainer.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UiKit.panel(PANEL, 8, 28)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UiKit.label("Iluro HC  –  Club Polo", 56, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := tr("Campionat de Catalunya de Papis · Camp Municipal d'Hoquei de Mataró")
	box.add_child(UiKit.label(sub, 24, MUTE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(
		UiKit.label(tr("Prem PASSA per començar"), 22, Color("ffb066"), HORIZONTAL_ALIGNMENT_CENTER)
	)
	panel.add_child(box)
	_intro.add_child(panel)
	_root.add_child(_intro)


func _build_pause() -> void:
	_pause = _overlay()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(UiKit.label(tr("Pausa"), 48, INK, HORIZONTAL_ALIGNMENT_CENTER))
	_pause_sub = UiKit.label("", 24, MUTE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_pause_sub)
	_pause_first = UiKit.button(tr("Continua"), resume_requested.emit)
	box.add_child(_pause_first)
	box.add_child(UiKit.button(tr("Reinicia el partit"), restart_requested.emit))
	box.add_child(UiKit.button(tr("Menú"), menu_requested.emit))
	_pause.get_child(1).get_child(0).add_child(box)


## Capa a pantalla completa: fons enfosquit i un plafó centrat (fill 1 › fill 0).
func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(UiKit.panel(PANEL, 10, 32))
	o.add_child(center)
	o.visible = false
	_root.add_child(o)
	return o


func _place(c: Control, preset: Control.LayoutPreset, margin: int) -> void:
	_root.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if preset in [Control.PRESET_TOP_LEFT, Control.PRESET_BOTTOM_LEFT]:
		c.grow_horizontal = Control.GROW_DIRECTION_END
	elif preset == Control.PRESET_TOP_RIGHT:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_LEFT]:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _chip(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := UiKit.panel(bg, 4, 6)
	p.add_child(UiKit.label(text, 26, fg, HORIZONTAL_ALIGNMENT_CENTER))
	return p
