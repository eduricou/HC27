## Peces comunes de la interfície: paleta i lletres de la web, escuts, el tema (botons,
## botons de segment, lliscadors i el focus taronja per navegar amb teclat i comandament) i
## constructors de controls. Les pantalles es construeixen des del codi (docs/decisions/0008).
## Paleta de la web: --ink, --panel, --panel2, --rule, --chalk, --mute, --orange, --navy, --red.
## Lletres (OFL, assets/fonts/): Big Shoulders Display (títols), Barlow Condensed (interfície)
## i Barlow (text).
class_name UiKit
extends RefCounted

const INK := Color("eef2ec")
const DARK := Color("0a120f")
const PANEL := Color("111c17")
const PANEL2 := Color("18261f")
const SHEET := Color(0.055, 0.09, 0.075, 0.95)
const RULE := Color("2a3b32")
const MUTE := Color("94a69c")
const ORANGE := Color("f07c1a")
const ORANGE_INK := Color("241002")
const NAVY := Color("14234b")
const RED := Color("c8102e")
const DIM := Color(0.024, 0.043, 0.035, 0.72)
const CRESTS: Array[String] = ["res://assets/crests/iluro.svg", "res://assets/crests/polo.svg"]
const FONT_FILES := {
	&"display": "res://assets/fonts/BigShouldersDisplay-Variable.ttf",
	&"ui": "res://assets/fonts/BarlowCondensed-SemiBold.ttf",
	&"ui_bold": "res://assets/fonts/BarlowCondensed-Bold.ttf",
	&"ui_medium": "res://assets/fonts/BarlowCondensed-Medium.ttf",
	&"body": "res://assets/fonts/Barlow-Regular.ttf",
	&"body_medium": "res://assets/fonts/Barlow-Medium.ttf",
}

static var _fonts := {}
static var _theme: Theme
static var _tracked := {}


## Lletra per tipus: display (títols, gruix 900), ui, ui_bold, ui_medium, body, body_medium.
static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	if kind == &"display":
		var fv := FontVariation.new()
		fv.base_font = load(FONT_FILES[&"display"])
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): 900}
		f = fv
	else:
		f = load(FONT_FILES.get(kind, FONT_FILES[&"ui"]))
	_fonts[kind] = f
	return f


## Lletra amb els caràcters més espaiats (letter-spacing de la web), en píxels.
static func tracked(kind: StringName, px: int) -> Font:
	var key := "%s:%d" % [kind, px]
	if _tracked.has(key):
		return _tracked[key]
	var fv := FontVariation.new()
	fv.base_font = font(kind)
	fv.spacing_glyph = px
	_tracked[key] = fv
	return fv


## Escut del club (0 Iluro, 1 Polo).
static func crest(idx: int) -> Texture2D:
	return load(CRESTS[clampi(idx, 0, 1)])


static func crest_rect(idx: int, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = crest(idx)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size * 1.2)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func label(
	text: String,
	size: int,
	color: Color = INK,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	kind: StringName = &"ui"
) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Títol en majúscules amb la lletra de rètol.
static func title(
	text: String, size: int, color: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	return label(text.to_upper(), size, color, align, &"display")


## Etiqueta petita en majúscules i espaiada (.olabel, .kicker de la web).
static func kicker(text: String, size: int = 16, color: Color = MUTE) -> Label:
	var l := label(text.to_upper(), size, color)
	l.add_theme_font_override("font", tracked(&"ui", 2))
	return l


static func with_shadow(l: Label, alpha: float = 0.85) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, alpha))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l


static func style(
	bg: Color, radius: int = 0, pad: float = 0.0, border: Color = Color(0, 0, 0, 0), bw: int = 0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.anti_aliasing = radius > 0
	return sb


static func panel(color: Color, radius: int = 0, pad: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, radius, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text.to_upper() if primary else text
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(cb)
	return b


## Grup de botons excloents (.seg de la web). `options`: [[valor, text], ...]. Crida
## cb(valor) quan se'n tria un. Retorna l'HBox; els botons en són els fills.
static func segment(options: Array, selected: Variant, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for o: Array in options:
		var b := Button.new()
		b.text = str(o[1])
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"SegButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(same(o[0], selected))
		var v: Variant = o[0]
		b.pressed.connect(func() -> void: cb.call(v))
		row.add_child(b)
	return row


## Marca el botó del segment que correspon a `value`.
static func segment_select(row: HBoxContainer, options: Array, value: Variant) -> void:
	for i in mini(row.get_child_count(), options.size()):
		(row.get_child(i) as Button).set_pressed_no_signal(same(options[i][0], value))


## Igualtat que no falla si els tipus són diferents (p. ex. un valor nul).
static func same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


## Tema de tota la interfície.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(&"ui")
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	# Botons (.row-btns button)
	var focus := style(Color(0, 0, 0, 0), 5, 0.0, ORANGE, 3)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	for type: String in ["Button", "SegButton", "PrimaryButton", "SlotButton"]:
		t.set_stylebox("focus", type, focus)
	t.set_font("font", "Button", font(&"ui_bold"))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("normal", "Button", style(Color(1, 1, 1, 0.02), 4, 0.0, RULE, 1))
	t.set_stylebox("hover", "Button", style(Color(1, 1, 1, 0.09), 4, 0.0, MUTE, 1))
	t.set_stylebox("pressed", "Button", style(Color(1, 1, 1, 0.16), 4, 0.0, INK, 1))
	t.set_stylebox("hover_pressed", "Button", style(Color(1, 1, 1, 0.16), 4, 0.0, INK, 1))
	t.set_stylebox("disabled", "Button", style(Color(0, 0, 0, 0), 4, 0.0, RULE, 1))
	for sn: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = t.get_stylebox(sn, "Button")
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(MUTE, 0.45))
	t.set_constant("h_separation", "Button", 8)
	# Segments: el triat, en blanc amb el text fosc (.seg button[aria-pressed=true]).
	t.set_type_variation("SegButton", "Button")
	t.set_font("font", "SegButton", font(&"ui"))
	t.set_font_size("font_size", "SegButton", 20)
	var seg_on := style(INK, 4, 0.0, INK, 1)
	t.set_stylebox("pressed", "SegButton", seg_on)
	t.set_stylebox("hover_pressed", "SegButton", seg_on)
	t.set_color("font_pressed_color", "SegButton", DARK)
	t.set_color("font_hover_pressed_color", "SegButton", DARK)
	for sn: String in ["pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = t.get_stylebox(sn, "SegButton")
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
	# Botó principal (.go): taronja, lletra de rètol.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_font("font", "PrimaryButton", font(&"display"))
	t.set_font_size("font_size", "PrimaryButton", 32)
	t.set_stylebox("normal", "PrimaryButton", style(ORANGE, 4, 10.0))
	t.set_stylebox("hover", "PrimaryButton", style(ORANGE.lightened(0.1), 4, 10.0))
	t.set_stylebox("pressed", "PrimaryButton", style(ORANGE.darkened(0.1), 4, 10.0))
	t.set_stylebox("hover_pressed", "PrimaryButton", style(ORANGE.darkened(0.1), 4, 10.0))
	for c: String in [
		"font_color",
		"font_hover_color",
		"font_focus_color",
		"font_pressed_color",
		"font_hover_pressed_color"
	]:
		t.set_color(c, "PrimaryButton", ORANGE_INK)
	var pfocus := focus.duplicate() as StyleBoxFlat
	pfocus.border_color = INK
	t.set_stylebox("focus", "PrimaryButton", pfocus)
	# Caselles de tecles (opcions)
	t.set_type_variation("SlotButton", "Button")
	t.set_font("font", "SlotButton", font(&"ui"))
	t.set_font_size("font_size", "SlotButton", 19)
	# Lliscadors (volums)
	t.set_stylebox("slider", "HSlider", style(RULE, 3, 0.0))
	var sl := t.get_stylebox("slider", "HSlider") as StyleBoxFlat
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	var area := style(ORANGE, 3, 0.0)
	area.content_margin_top = 3
	area.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area)
	var sfocus := focus.duplicate() as StyleBoxFlat
	sfocus.set_expand_margin_all(8)
	t.set_stylebox("focus", "HSlider", sfocus)
	t.set_icon("grabber", "HSlider", _dot(22, INK))
	t.set_icon("grabber_highlight", "HSlider", _dot(22, Color.WHITE))
	# Separadors
	var line := StyleBoxLine.new()
	line.color = RULE
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 10)
	# Barres de desplaçament (taula de tecles)
	t.set_stylebox("scroll", "VScrollBar", style(Color(1, 1, 1, 0.04), 3))
	t.set_stylebox("grabber", "VScrollBar", style(RULE, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", style(MUTE, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", style(INK, 3))
	_theme = t
	return t


## Cercle ple (agafador dels lliscadors).
static func _dot(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(c, clampf(r - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Capa a pantalla completa: fons enfosquit (.overlay) i un contenidor centrat.
static func overlay(parent: Control) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(center)
	o.visible = false
	parent.add_child(o)
	return o


## Targeta (.card): plafó fosc amb vora, i la columna on van els continguts.
static func card(width: float) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(SHEET, 0, 26.0, RULE, 1))
	p.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	return [p, box]
