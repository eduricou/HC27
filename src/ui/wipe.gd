## Cortineta de transició: una franja inclinada taronja i blau marí amb l'escut de l'equip
## que travessa la pantalla en 0,8 s. Tapa la pantalla entre el 44 % i el 56 % del temps,
## que és quan la simulació canvia a la repetició o en surt (esdeveniment «wipe»).
## ref: wipe() i #wipe (CSS, línies 29–34)
class_name Wipe
extends Control

const DURATION := 0.8
const SKEW := 0.2493  # tan(14°)
const CREST := 190.0

var _t := -1.0
var _team := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func play(team_idx: int) -> void:
	_team = team_idx
	_t = 0.0
	visible = true


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t >= DURATION:
		_t = -1.0
		visible = false
	queue_redraw()


## Desplaçament horitzontal (en amplades de la franja) en el moment u (0–1).
static func offset_at(u: float) -> float:
	if u < 0.44:
		return lerpf(-1.6, 0.0, ease_curve(u / 0.44))
	if u < 0.56:
		return 0.0
	return lerpf(0.0, 1.6, ease_curve((u - 0.56) / 0.44))


## cubic-bezier(.75, 0, .25, 1) de la web.
static func ease_curve(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var t := x
	for i in 8:
		var bx := _bez(t, 0.75, 0.25) - x
		var d := _bez_d(t, 0.75, 0.25)
		if absf(d) < 1e-5:
			break
		t = clampf(t - bx / d, 0.0, 1.0)
	return _bez(t, 0.0, 1.0)


static func _bez(t: float, p1: float, p2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t


static func _bez_d(t: float, p1: float, p2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * p1 + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (1.0 - p2)


func _draw() -> void:
	if _t < 0.0:
		return
	var w := size.x
	var h := size.y
	var bw := w * 1.7
	var left := -0.35 * w + offset_at(_t / DURATION) * bw
	var top := -0.2 * h
	var bh := h * 1.4
	var cy := top + bh * 0.5
	_band(left, left + bw * 0.52, top, bh, cy, UiKit.ORANGE)
	_band(left + bw * 0.52, left + bw, top, bh, cy, UiKit.NAVY)
	_band(left + bw * 0.51, left + bw * 0.53, top, bh, cy, Color.WHITE)
	var c := Vector2(left + bw * 0.5, cy)
	var tex := UiKit.crest(_team)
	var r := Rect2(c - Vector2(CREST * 0.5, CREST * 0.6), Vector2(CREST, CREST * 1.2))
	draw_texture_rect(tex, Rect2(r.position + Vector2(0, 8), r.size), false, Color(0, 0, 0, 0.35))
	draw_texture_rect(tex, r, false)


## Franja vertical de x0 a x1, inclinada com skewX(−14°) al voltant del centre.
func _band(x0: float, x1: float, top: float, bh: float, cy: float, col: Color) -> void:
	var y1 := top + bh
	var pts := PackedVector2Array(
		[
			Vector2(x0 - SKEW * (top - cy), top),
			Vector2(x1 - SKEW * (top - cy), top),
			Vector2(x1 - SKEW * (y1 - cy), y1),
			Vector2(x0 - SKEW * (y1 - cy), y1),
		]
	)
	draw_colored_polygon(pts, col)
