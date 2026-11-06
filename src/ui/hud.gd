## HUD del partit, com el de la web (línies 50–80 del CSS i 1870–1938):
## - marcador amb escuts, rellotge, quart i l'etiqueta PAPIS; a sota, qui porta la pilota;
## - minimapa, indicador del jugador controlat (amb resistència i potència), indicacions;
## - rètols (GOL!, córner curt, represes...), etiqueta REPETICIÓ i franges de cinema;
## - presentació del partit, cortineta de transició i vinyeta;
## - pantalles de pausa, descans i final (PauseScreen, BreakScreen).
## El botó de pausa de dalt a la dreta és per jugar només amb el ratolí.
class_name Hud
extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested
signal next_quarter_requested
signal play_again_requested
signal options_requested
signal pause_requested

const RESTART_NAMES := {
	&"free": "Cop franc",
	&"side": "Treta de banda",
	&"hitout": "Sortida",
	&"long": "Córner llarg",
	&"center": "Servei del centre",
}
const CHIP := Color("f4f5f1")
const CHIP_INK := Color("121815")
const VIGNETTE := """
shader_type canvas_item;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.46)) / vec2(0.78, 0.72);
	COLOR = vec4(0.0, 0.0, 0.0, 0.34 * clamp((length(d) - 0.58) / 0.42, 0.0, 1.0));
}
"""
const LETTERBOX := 0.08

var runner: MatchRunner
var view: MatchView
var camera: Camera3D
## Partit de nit (per al text de la presentació).
var night := true
var pause_screen: PauseScreen
var break_screen: BreakScreen

var _root: Control
var _score: Label
var _score_box: StyleBoxFlat
var _quarter: Label
var _clock: Label
var _carrier: Label
var _carrier_dot: ColorRect
var _carrier_row: HBoxContainer
var _hint: PanelContainer
var _hint_label: Label
var _replay: PanelContainer
var _minimap: Minimap
var _marker: PlayerMarker
var _banner: VBoxContainer
var _banner_panel: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _intro: PanelContainer
var _intro_sub: Label
var _intro_shown := false
var _bars: Array[ColorRect] = []
var _bars_on := false
## 0: franges amagades · 1: franges a dins.
var _bars_k := 0.0
var _bars_tween: Tween
var _wipe: Wipe
var _flash: Tween


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_root)
	var vig := ColorRect.new()
	vig.name = "Vinyeta"
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	_root.add_child(vig)
	_marker = PlayerMarker.new()
	_marker.name = "Marcador"
	_root.add_child(_marker)
	_build_letterbox()
	_build_scoreboard()
	_build_corner()
	_build_hint()
	_minimap = Minimap.new()
	_minimap.name = "Minimapa"
	_place(_minimap, Control.PRESET_CENTER_BOTTOM, 14)
	_build_banner()
	_build_intro()
	_wipe = Wipe.new()
	_root.add_child(_wipe)
	pause_screen = PauseScreen.new()
	_root.add_child(pause_screen)
	pause_screen.resume_requested.connect(resume_requested.emit)
	pause_screen.restart_requested.connect(restart_requested.emit)
	pause_screen.options_requested.connect(options_requested.emit)
	pause_screen.menu_requested.connect(menu_requested.emit)
	break_screen = BreakScreen.new()
	_root.add_child(break_screen)
	break_screen.next_quarter_requested.connect(next_quarter_requested.emit)
	break_screen.play_again_requested.connect(play_again_requested.emit)
	break_screen.menu_requested.connect(menu_requested.emit)
	set_match_visible(false)


## Connecta el HUD amb la simulació, la vista i la càmera.
func bind(p_runner: MatchRunner, p_view: MatchView, p_camera: Camera3D) -> void:
	runner = p_runner
	view = p_view
	camera = p_camera
	_minimap.runner = runner
	_minimap.view = view
	_marker.runner = runner
	_marker.view = view
	_marker.camera = camera


## Mostra o amaga tot el HUD de partit (al menú no es veu). En un partit nou, ho deixa tot
## com a l'inici: presentació, sense rètols ni pantalles.
func set_match_visible(on: bool) -> void:
	_root.visible = on
	_banner.visible = false
	pause_screen.visible = false
	break_screen.visible = false
	_intro.visible = false
	_intro_shown = false
	_set_bars(false, true)


func _process(_delta: float) -> void:
	if not _root.visible or runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	_score.text = "%d–%d" % [s.score[0], s.score[1]]
	_quarter.text = "%dQ" % s.quarter
	_clock.text = fmt_clock(s.clock)
	var c := s.ball.owner
	_carrier_row.modulate.a = 1.0 if c else 0.0
	if c:
		_carrier.text = "%d · %s" % [c.num, c.name]
		_carrier_dot.color = Color(c.team.def.color)
	_replay.visible = s.state == &"replay"
	var intro := s.intro_t > 0.0
	if intro and not _intro_shown:
		_show_intro()
	elif not intro and _intro.visible:
		_intro.visible = false
	var hint := hint_text(s)
	_hint.visible = hint != ""
	_hint_label.text = hint
	var cinema := intro or s.state == &"replay"
	_set_bars(cinema)
	_layout_bars()
	# El minimapa tapa la porteria amb la càmera del córner curt.
	var pc_cam := camera is CameraRig and (camera as CameraRig).mode == CameraRig.Mode.PC
	_minimap.visible = not cinema and not pc_cam


## Rètols i efectes a partir dels esdeveniments de la simulació. ref: banner()
func on_events(events: Array[Dictionary]) -> void:
	if runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	for e in events:
		var t: StringName = e["type"]
		if t == &"wipe":
			if _root.visible:
				_wipe.play(int(e["team"]))
			continue
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
			show_banner(tr("Gol!"), "%d · %s" % [sc.num, sc.name], s.teams[e["team"]], 2.6, true)
			_flash_score()
		elif t == &"save":
			var gk: Player = e["player"]
			show_banner(tr("Aturada"), "%d · %s" % [gk.num, gk.name], gk.team, 1.1)


## Rètol central. goal: el gran, sobre el color de l'equip. ref: banner(), #banner.goal
func show_banner(title: String, sub: String, team: Team, dur: float, goal: bool = false) -> void:
	var col := Color(team.def.color) if team else UiKit.INK
	var ink := Color(team.def.ink) if team else Color("111111")
	_banner_title.text = title.to_upper()
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	var sb := _banner_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if goal:
		sb.bg_color = col
		sb.border_width_bottom = 0
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		_banner_title.add_theme_font_size_override("font_size", 136)
		_banner_title.add_theme_color_override("font_color", ink)
	else:
		sb.bg_color = UiKit.PANEL
		sb.border_color = col
		sb.border_width_bottom = 6
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		_banner_title.add_theme_font_size_override("font_size", 66)
		_banner_title.add_theme_color_override("font_color", UiKit.INK)
	_banner.visible = true
	_banner.reset_size()
	_banner.position.x = (_root.size.x - _banner.size.x) * 0.5
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner.position.y = _banner_y() - 12.0
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(_banner, "position:y", _banner_y(), 0.25)
	_banner_tween.chain().tween_interval(dur)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.18)
	_banner_tween.chain().tween_callback(func() -> void: _banner.visible = false)


func hide_banner() -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = false


func _banner_y() -> float:
	return _root.size.y * 0.2


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
	if on and runner and runner.sim:
		pause_screen.open(runner.sim.s)
	else:
		pause_screen.visible = false
		get_viewport().gui_release_focus()


## Pantalla de descans o de final. ref: showBreak()
func show_break(full: bool) -> void:
	hide_banner()
	_hint.visible = false
	break_screen.open(runner.sim.s, full)


func hide_break() -> void:
	break_screen.visible = false
	get_viewport().gui_release_focus()


# --- Construcció ------------------------------------------------------------------


func _build_scoreboard() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size.y = 46
	col.add_child(row)
	var font := UiKit.font(&"ui_bold")
	for i in 2:
		var chip := PanelContainer.new()
		var sb := UiKit.style(CHIP)
		sb.content_margin_left = 7 if i == 0 else 12
		sb.content_margin_right = 12 if i == 0 else 7
		if i == 0:
			sb.border_width_left = 6
			sb.border_color = UiKit.ORANGE
		else:
			sb.border_width_right = 6
			sb.border_color = UiKit.NAVY
		chip.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var crest := UiKit.crest_rect(i, 30.0)
		var nm := UiKit.label(["ILU", "POL"][i], 25, CHIP_INK)
		nm.add_theme_font_override("font", UiKit.tracked(&"ui_bold", 1))
		if i == 0:
			h.add_child(crest)
			h.add_child(nm)
		else:
			h.add_child(nm)
			h.add_child(crest)
		chip.add_child(h)
		row.add_child(chip)
		if i == 0:
			var score := PanelContainer.new()
			_score_box = UiKit.style(UiKit.PANEL)
			_score_box.content_margin_left = 12
			_score_box.content_margin_right = 12
			score.add_theme_stylebox_override("panel", _score_box)
			score.custom_minimum_size.x = 80
			_score = UiKit.label("0–0", 31, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
			_score.add_theme_font_override("font", font)
			score.add_child(_score)
			row.add_child(score)
	var clock := PanelContainer.new()
	var csb := UiKit.style(UiKit.PANEL2)
	csb.content_margin_left = 14
	csb.content_margin_right = 14
	clock.add_theme_stylebox_override("panel", csb)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 9)
	_quarter = UiKit.label("1Q", 25, UiKit.ORANGE, HORIZONTAL_ALIGNMENT_LEFT, &"ui_bold")
	_clock = UiKit.label("15:00", 25, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, &"ui_bold")
	ch.add_child(_quarter)
	ch.add_child(_clock)
	clock.add_child(ch)
	row.add_child(clock)
	var tag := PanelContainer.new()
	var tsb := UiKit.style(UiKit.ORANGE)
	tsb.content_margin_left = 11
	tsb.content_margin_right = 11
	tag.add_theme_stylebox_override("panel", tsb)
	var tl := UiKit.label("PAPIS", 18, UiKit.ORANGE_INK)
	tl.add_theme_font_override("font", UiKit.tracked(&"ui_bold", 3))
	tag.add_child(tl)
	row.add_child(tag)
	for ctl in row.get_children():
		(ctl as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carrier_row = HBoxContainer.new()
	_carrier_row.add_theme_constant_override("separation", 8)
	_carrier_dot = ColorRect.new()
	_carrier_dot.custom_minimum_size = Vector2(13, 13)
	_carrier_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_carrier = UiKit.with_shadow(UiKit.label("", 21, UiKit.INK))
	_carrier_row.add_child(_carrier_dot)
	_carrier_row.add_child(_carrier)
	col.add_child(_carrier_row)
	_place(col, Control.PRESET_TOP_LEFT, 16)


## Botó de pausa (ratolí) i etiqueta REPETICIÓ, a dalt a la dreta.
func _build_corner() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb := Button.new()
	pb.icon = _pause_icon()
	pb.custom_minimum_size = Vector2(54, 54)
	pb.focus_mode = Control.FOCUS_NONE
	pb.size_flags_horizontal = Control.SIZE_SHRINK_END
	pb.tooltip_text = tr("Pausa")
	pb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bs := UiKit.style(Color(10 / 255.0, 18 / 255.0, 15 / 255.0, 0.78), 10, 0.0, UiKit.RULE, 1)
	pb.add_theme_stylebox_override("normal", bs)
	var bh := bs.duplicate() as StyleBoxFlat
	bh.border_color = UiKit.MUTE
	pb.add_theme_stylebox_override("hover", bh)
	pb.add_theme_stylebox_override("pressed", bh)
	pb.pressed.connect(pause_requested.emit)
	col.add_child(pb)
	_replay = PanelContainer.new()
	var rs := UiKit.style(UiKit.RED)
	rs.content_margin_left = 13
	rs.content_margin_right = 13
	rs.content_margin_top = 4
	rs.content_margin_bottom = 4
	_replay.add_theme_stylebox_override("panel", rs)
	var rl := UiKit.label(tr("REPETICIÓ"), 20, Color.WHITE)
	rl.add_theme_font_override("font", UiKit.tracked(&"ui_bold", 3))
	_replay.add_child(rl)
	_replay.size_flags_horizontal = Control.SIZE_SHRINK_END
	_replay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_replay)
	_place(col, Control.PRESET_TOP_RIGHT, 16)


func _build_hint() -> void:
	_hint = PanelContainer.new()
	var sb := UiKit.style(Color(10 / 255.0, 18 / 255.0, 15 / 255.0, 0.82), 999, 0.0, UiKit.RULE, 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_hint.add_theme_stylebox_override("panel", sb)
	_hint_label = UiKit.label("", 21, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_child(_hint_label)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_hint, Control.PRESET_CENTER_TOP, 82)
	_hint.visible = false


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.add_theme_constant_override("separation", 8)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel = PanelContainer.new()
	var sb := UiKit.style(UiKit.PANEL)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 8
	_banner_panel.add_theme_stylebox_override("panel", sb)
	_banner_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = UiKit.label("", 66, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, &"display")
	_banner_panel.add_child(_banner_title)
	_banner.add_child(_banner_panel)
	_banner_sub = UiKit.with_shadow(UiKit.label("", 25, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_banner.add_child(_banner_sub)
	_root.add_child(_banner)
	_banner.visible = false


## Presentació (#intro): escuts, «Iluro HC vs Club Polo» i com començar.
func _build_intro() -> void:
	_intro = PanelContainer.new()
	var sb := UiKit.style(Color(12 / 255.0, 20 / 255.0, 16 / 255.0, 0.92))
	sb.border_width_top = 5
	sb.border_color = UiKit.ORANGE
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 10)
	_intro.add_theme_stylebox_override("panel", sb)
	_intro.custom_minimum_size.x = 860
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.add_child(UiKit.crest_rect(0, 66.0))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	var t := HBoxContainer.new()
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.add_theme_constant_override("separation", 14)
	t.add_child(UiKit.title("Iluro HC", 46))
	t.add_child(UiKit.title("vs", 32, UiKit.ORANGE))
	t.add_child(UiKit.title("Club Polo", 46))
	mid.add_child(t)
	_intro_sub = UiKit.label("", 19, UiKit.MUTE, HORIZONTAL_ALIGNMENT_CENTER)
	_intro_sub.add_theme_font_override("font", UiKit.tracked(&"ui", 1))
	mid.add_child(_intro_sub)
	var k := UiKit.kicker(tr("Prem una tecla o un botó per començar"), 15, Color(UiKit.INK, 0.55))
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(k)
	row.add_child(mid)
	row.add_child(UiKit.crest_rect(1, 66.0))
	_intro.add_child(row)
	_root.add_child(_intro)
	_intro.visible = false


func _show_intro() -> void:
	_intro_shown = true
	_intro_sub.text = (
		tr("Campionat de Catalunya de Papis · Mataró · %s")
		% (tr("partit de nit") if night else tr("partit de tarda"))
	)
	_intro.visible = true
	_intro.reset_size()
	var vp := _root.size
	var y := vp.y * (1.0 - LETTERBOX) - _intro.size.y - 18.0
	_intro.position = Vector2((vp.x - _intro.size.x) * 0.5, y + 30.0)
	_intro.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_intro, "position:y", y, 0.7)
	tw.tween_property(_intro, "modulate:a", 1.0, 0.7)


## Franges negres de dalt i de baix (#lbox), durant la presentació i la repetició.
func _build_letterbox() -> void:
	for i in 2:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(r)
		_bars.append(r)
	_set_bars(false, true)


func _set_bars(on: bool, instant: bool = false) -> void:
	if on == _bars_on and not instant:
		return
	_bars_on = on
	if _bars_tween:
		_bars_tween.kill()
	if instant:
		_bars_k = 1.0 if on else 0.0
	else:
		_bars_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_bars_tween.tween_property(self, "_bars_k", 1.0 if on else 0.0, 0.5)
	_layout_bars()


func _layout_bars() -> void:
	var sz := _root.size
	var h := sz.y * LETTERBOX
	for i in 2:
		_bars[i].size = Vector2(sz.x, h)
		_bars[i].visible = _bars_k > 0.0
	_bars[0].position = Vector2(0.0, -h * (1.0 - _bars_k))
	_bars[1].position = Vector2(0.0, sz.y - h * _bars_k)


## El resultat s'il·lumina de taronja en marcar. ref: .sb-num.flash
func _flash_score() -> void:
	if _flash:
		_flash.kill()
	_score_box.bg_color = UiKit.ORANGE
	_score.add_theme_color_override("font_color", UiKit.ORANGE_INK)
	_flash = create_tween()
	_flash.tween_interval(0.42)
	_flash.tween_property(_score_box, "bg_color", UiKit.PANEL, 0.98)
	_flash.parallel().tween_method(
		func(c: Color) -> void: _score.add_theme_color_override("font_color", c),
		UiKit.ORANGE_INK,
		UiKit.INK,
		0.98
	)


static func _pause_icon() -> ImageTexture:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(5, 4, 4, 14), UiKit.INK)
	img.fill_rect(Rect2i(13, 4, 4, 14), UiKit.INK)
	return ImageTexture.create_from_image(img)


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
