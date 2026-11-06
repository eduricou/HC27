## Menú principal (#menu de la web), amb un partit de demostració de fons:
## - capçalera ESTIC i el lloc del partit;
## - la placa del partit: escuts, noms, equipacions en 3D i valoració de cada equip;
## - tria del costat (Iluro, Polo o només mirar), dificultat, durada del quart, hora i
##   càmera, i el botó «Al camp»; a més, Opcions, Controls i Surt.
## Les eleccions es desen a les opcions (GameSettings). Es pot fer servir només amb el
## teclat, només amb el ratolí o només amb el comandament.
## ref: #menu, OPTS i els .seg (línies 202–250 i 1974–1982)
class_name MainMenu
extends CanvasLayer

signal play_requested(side: int, diff: String, qlen: float)
signal night_changed(night: bool)
signal cam_changed(cam: String)
signal options_requested
signal changed

const SIDES := [[0, "Iluro HC"], [1, "Club Polo"], [-1, "Només mirar"]]
const DIFFS := [["facil", "Fàcil"], ["normal", "Normal"], ["dificil", "Difícil"]]
const QLENS := [[90.0, "1,5 min"], [150.0, "2,5 min"], [240.0, "4 min"]]
const TIMES := [[false, "Tarda"], [true, "Nit"]]
const CAMS := [["tv", "Televisió"], ["ampla", "Àmplia"]]
const META: Array[String] = ["Mataró · Papis +35", "Polo Rosso · Papis +35"]
const VENUE := (
	"Campionat de Catalunya de Papis · Camp Municipal d'Hoquei de Mataró · "
	+ "carrer Galícia, 180 · 4 quarts de 15:00"
)
const NOTE := (
	"Categoria Papis: tots els jugadors tenen més de 35 anys, com marca el reglament de la "
	+ "Federació Catalana d'Hockey. Un gol només val si es xuta des de dins del cercle. Falta "
	+ "d'un defensor dins del seu cercle: córner curt. Els escuts són dissenys originals amb "
	+ "els colors de cada club, i els jugadors són ficticis."
)

var settings: GameSettings
var night: bool:
	get:
		return settings.night if settings else true

var _root: Control
var _go: Button
var _diff_box: Control
var _help: Control
var _help_btn: Button
var _help_grid: GridContainer
var _segs := {}
var _previews: Array[KitPreview] = []


func _ready() -> void:
	layer = 2
	if settings == null:
		settings = GameSettings.new()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_root)
	var grad := Gradient.new()
	grad.set_color(0, Color(6 / 255.0, 11 / 255.0, 9 / 255.0, 0.45))
	grad.set_color(1, Color(6 / 255.0, 11 / 255.0, 9 / 255.0, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr_shade := TextureRect.new()
	tr_shade.texture = gt
	tr_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr_shade.stretch_mode = TextureRect.STRETCH_SCALE
	tr_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tr_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var sheet := PanelContainer.new()
	var ss := UiKit.style(UiKit.SHEET, 0, 26.0, UiKit.RULE, 1)
	ss.shadow_color = Color(0, 0, 0, 0.5)
	ss.shadow_size = 40
	ss.shadow_offset = Vector2(0, 18)
	sheet.add_theme_stylebox_override("panel", ss)
	sheet.custom_minimum_size.x = 1280
	center.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	sheet.add_child(col)
	col.add_child(_masthead())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	col.add_child(body)
	var plate := _plate()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = 1.4
	body.add_child(plate)
	var opts := _options()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(opts)
	_help = _help_panel()
	col.add_child(_help)
	_help.visible = false
	_refresh()


func open() -> void:
	visible = true
	for p in _previews:
		p.set_active(true)
	_refresh()
	_go.grab_focus.call_deferred()


func close() -> void:
	visible = false
	for p in _previews:
		p.set_active(false)


## Torna el focus al botó d'opcions en tancar-les.
func refocus() -> void:
	if visible:
		_go.grab_focus.call_deferred()


func _masthead() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var wm := VBoxContainer.new()
	wm.add_theme_constant_override("separation", 0)
	wm.add_child(UiKit.title("Estic", 96))
	var sub := UiKit.label(tr("Simulador d'hoquei herba").to_upper(), 19, UiKit.ORANGE)
	sub.add_theme_font_override("font", UiKit.tracked(&"ui", 4))
	wm.add_child(sub)
	row.add_child(wm)
	var venue := UiKit.label(tr(VENUE), 19, UiKit.MUTE, HORIZONTAL_ALIGNMENT_RIGHT, &"ui_medium")
	venue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	venue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	venue.size_flags_vertical = Control.SIZE_SHRINK_END
	venue.custom_minimum_size.x = 380
	row.add_child(venue)
	return row


## La placa del partit (.plate): taronja i blau marí partits en diagonal, amb VS al mig.
func _plate() -> Control:
	var plate := MenuPlate.new()
	plate.custom_minimum_size = Vector2(730, 360)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var defs: Array[TeamData] = [TeamData.load_default(0), TeamData.load_default(1)]
	for i in 2:
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", 2)
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ink := UiKit.ORANGE_INK if i == 0 else Color.WHITE
		var al := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 22 if i == 0 else 30)
		margin.add_theme_constant_override("margin_right", 30 if i == 0 else 22)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		head.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 0)
		names.add_child(UiKit.title(defs[i].name, 44, ink, al))
		var meta := UiKit.label(tr(META[i]).to_upper(), 17, Color(ink, 0.85), al)
		meta.add_theme_font_override("font", UiKit.tracked(&"ui", 1))
		names.add_child(meta)
		var crest := UiKit.crest_rect(i, 70.0)
		if i == 0:
			head.add_child(crest)
			head.add_child(names)
		else:
			head.add_child(names)
			head.add_child(crest)
		side.add_child(head)
		var kit := HBoxContainer.new()
		kit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		kit.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
		kit.add_theme_constant_override("separation", 6)
		var prev := KitPreview.new()
		prev.setup(i)
		_previews.append(prev)
		var ovr := VBoxContainer.new()
		ovr.size_flags_vertical = Control.SIZE_SHRINK_END
		ovr.custom_minimum_size.y = 90
		ovr.add_theme_constant_override("separation", -6)
		ovr.add_child(UiKit.label(str(defs[i].team_ovr()), 44, ink, al, &"display"))
		var ol := UiKit.label(tr("mitjana").to_upper(), 15, ink, al)
		ol.add_theme_font_override("font", UiKit.tracked(&"ui", 2))
		ovr.add_child(ol)
		# La valoració, a la banda de fora: la diagonal de la placa no la talla.
		if i == 0:
			kit.add_child(ovr)
			kit.add_child(prev)
		else:
			kit.add_child(prev)
			kit.add_child(ovr)
		side.add_child(kit)
		margin.add_child(side)
		row.add_child(margin)
	return plate


func _options() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_segs["side"] = _opt(box, tr("Jugues amb"), SIDES, settings.side, _set_side)
	_segs["diff"] = _opt(box, tr("Dificultat de la CPU"), DIFFS, settings.diff, _set_diff)
	_diff_box = (_segs["diff"] as Control).get_parent()
	_segs["qlen"] = _opt(box, tr("Durada real de cada quart"), QLENS, settings.qlen, _set_qlen)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 14)
	box.add_child(pair)
	_segs["time"] = _opt(pair, tr("Hora"), TIMES, settings.night, _set_time)
	_segs["cam"] = _opt(pair, tr("Càmera"), CAMS, settings.cam, _set_cam)
	for c in pair.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp := Control.new()
	sp.custom_minimum_size.y = 4
	box.add_child(sp)
	_go = UiKit.button(tr("Al camp"), _play, true)
	_go.custom_minimum_size.y = 64
	box.add_child(_go)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.button(tr("Opcions"), options_requested.emit))
	_help_btn = UiKit.button(tr("Controls"), _toggle_help)
	_help_btn.toggle_mode = true
	row.add_child(_help_btn)
	row.add_child(UiKit.button(tr("Surt"), get_tree().quit))
	for b in row.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Control).custom_minimum_size.y = 50
	box.add_child(row)
	return box


## Una opció del menú: etiqueta i botons de segment. Retorna el segment.
func _opt(
	parent: Control, label: String, options: Array, value: Variant, cb: Callable
) -> HBoxContainer:
	var o := VBoxContainer.new()
	o.add_theme_constant_override("separation", 6)
	o.add_child(UiKit.kicker(label, 16))
	var seg := UiKit.segment(options, value, cb)
	for b in seg.get_children():
		(b as Control).custom_minimum_size.y = 46
	o.add_child(seg)
	parent.add_child(o)
	return seg


## Taula de controls (.help), amb les tecles assignades ara.
func _help_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(HSeparator.new())
	_help_grid = GridContainer.new()
	_help_grid.columns = 3
	_help_grid.add_theme_constant_override("h_separation", 30)
	_help_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_help_grid)
	var note := UiKit.label(tr(NOTE), 16, UiKit.MUTE, HORIZONTAL_ALIGNMENT_LEFT, &"body")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 1200
	box.add_child(note)
	return box


func _fill_help() -> void:
	for c in _help_grid.get_children():
		_help_grid.remove_child(c)
		c.queue_free()
	for h: String in [tr("Acció"), tr("Teclat"), tr("Comandament")]:
		_help_grid.add_child(UiKit.kicker(h, 14))
	var rows := [
		[
			tr("Moure's"),
			[&"move_up", &"move_left", &"move_down", &"move_right"],
			tr("Palanca esquerra o creu")
		],
		[tr("Passar · canviar de jugador"), [&"pass"], ""],
		[tr("Xutar (mantén per potència) · entrada"), [&"shoot"], ""],
		[tr("Esprintar"), [&"sprint"], ""],
		[tr("Pausa"), [&"pause"], ""],
	]
	for r: Array in rows:
		_help_grid.add_child(UiKit.label(r[0], 19, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, &"body"))
		var keys: Array[String] = []
		for a: StringName in r[1]:
			var ks: Array = InputActions.current[a]["keys"]
			if not ks.is_empty():
				keys.append(InputActions.key_name(ks[0]))
		var extra: Array[String] = []
		if r[1].size() == 1:
			for k: int in InputActions.current[r[1][0]]["keys"].slice(1):
				extra.append(InputActions.key_name(k))
		var ktxt := " ".join(keys) if r[1].size() > 1 else " · ".join(keys + extra)
		_help_grid.add_child(UiKit.label(ktxt, 19, UiKit.INK))
		var pad: String = r[2]
		if pad == "":
			var names: Array[String] = []
			for code: String in InputActions.current[r[1][0]]["pad"]:
				names.append(InputActions.pad_name(code))
			pad = " · ".join(names)
		_help_grid.add_child(UiKit.label(pad, 19, UiKit.INK))


func _toggle_help() -> void:
	_help.visible = _help_btn.button_pressed
	if _help.visible:
		_fill_help()


func _play() -> void:
	play_requested.emit(settings.side, settings.diff, settings.qlen)


func _set_side(v: Variant) -> void:
	settings.side = int(v)
	_refresh()
	changed.emit()


func _set_diff(v: Variant) -> void:
	settings.diff = str(v)
	changed.emit()


func _set_qlen(v: Variant) -> void:
	settings.qlen = float(v)
	changed.emit()


func _set_time(v: Variant) -> void:
	settings.night = bool(v)
	night_changed.emit(settings.night)
	changed.emit()


func _set_cam(v: Variant) -> void:
	settings.cam = str(v)
	cam_changed.emit(settings.cam)
	changed.emit()


func _refresh() -> void:
	if _segs.is_empty():
		return
	UiKit.segment_select(_segs["side"], SIDES, settings.side)
	UiKit.segment_select(_segs["diff"], DIFFS, settings.diff)
	UiKit.segment_select(_segs["qlen"], QLENS, settings.qlen)
	UiKit.segment_select(_segs["time"], TIMES, settings.night)
	UiKit.segment_select(_segs["cam"], CAMS, settings.cam)
	# Si només es mira, la dificultat no compta (com a la web, s'esvaeix).
	_diff_box.modulate.a = 0.45 if settings.side < 0 else 1.0
	if _help and _help.visible:
		_fill_help()
