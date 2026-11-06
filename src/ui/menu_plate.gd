## Fons de la placa del partit del menú: taronja (Iluro) i blau marí (Polo) partits per
## una diagonal, i el cercle VS al mig. ref: .plate, .vs (linear-gradient(101deg, ...))
class_name MenuPlate
extends Control

const TILT := 0.194  # tan(11°)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := w * 0.5 + TILT * h * 0.5
	var bot := w * 0.5 - TILT * h * 0.5
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(top, 0), Vector2(bot, h), Vector2(0, h)]),
		UiKit.ORANGE
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(top, 0), Vector2(w, 0), Vector2(w, h), Vector2(bot, h)]),
		UiKit.NAVY
	)
	var c := Vector2(w * 0.5, h * 0.5)
	draw_circle(c, 31.0, Color(1, 1, 1, 0.9), true, -1.0, true)
	draw_circle(c, 28.0, UiKit.DARK, true, -1.0, true)
	var f := UiKit.font(&"display")
	var fs := 24
	var tw := f.get_string_size("VS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(
		f, c + Vector2(-tw.x * 0.5, fs * 0.36), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
