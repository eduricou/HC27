## Colors i peces d'interfície comunes al HUD i al menú (fase 2, construïts des del codi).
## Paleta de la web: --ink, --panel, --chalk, --mute, --orange, --navy.
class_name UiKit
extends RefCounted

const INK := Color("eef2ec")
const MUTE := Color("94a69c")
const PANEL := Color(0.067, 0.11, 0.09, 0.92)
const DIM := Color(0.02, 0.04, 0.03, 0.55)
const ORANGE := Color("f07c1a")
const NAVY := Color("14234b")


static func label(
	text: String, size: int, color: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(color: Color, radius: int, pad: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b
