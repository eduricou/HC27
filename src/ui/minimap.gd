## Minimapa del partit: el camp amb les línies, els jugadors (el controlat, més gran i
## amb anella blanca) i la pilota. Fa servir les posicions que es veuen (interpolades).
## El camp es dibuixa una sola vegada (un fill a part) i els punts són una textura petita
## pintada amb el color de cada jugador: a cada fotograma només es redibuixen 23 quadrats.
## ref: drawMini() (línia 1854)
class_name Minimap
extends Control

const HL := Constants.HL
const HW := Constants.HW
const PAD := 7.0
const DOT := 3.6
const DOT_CTRL := 4.9
const DOT_PX := 32
const EDGE: Array[Color] = [Color("241002"), Color("14234b")]
const BALL := Color("ffe14a")

var runner: MatchRunner
var view: MatchView

var _dot: ImageTexture
var _ring: ImageTexture
## Colors de cada jugador del partit actual (es calculen un cop per partit).
var _cols := PackedColorArray()
var _bound: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(210, 210 * Constants.FW / Constants.FL)
	_dot = _disc(DOT_PX, 0.0)
	_ring = _disc(DOT_PX, 0.72)
	var field := MinimapField.new()
	field.show_behind_parent = true
	add_child(field)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if runner == null or runner.sim == null or view == null:
		return
	var st := runner.sim.s
	if st.players.is_empty():
		return
	if st.players[0] != _bound:
		_bound = st.players[0]
		_cols.resize(st.players.size())
		for i in st.players.size():
			var p := st.players[i]
			_cols[i] = Color(p.team.def.gk_kit["shirt"]) if p.is_gk else Color(p.team.def.mini)
	var sx := (size.x - PAD * 2.0) / Constants.FL
	var sy := (size.y - PAD * 2.0) / Constants.FW
	var match_mode := st.mode == &"match"
	for i in st.players.size():
		var p := st.players[i]
		var pos := view.player_sim_pos(i)
		var c := to_map(pos.x, pos.y, sx, sy)
		var ctrl := p == st.ctrl and match_mode
		var r := DOT_CTRL if ctrl else DOT
		_disc_at(_dot, c, r + 1.1, EDGE[p.team.idx])
		_disc_at(_dot, c, r, _cols[i])
		if ctrl and p.team.human:
			_disc_at(_ring, c, 8.0, Color.WHITE)
	var b := view.ball_sim_pos()
	_disc_at(_dot, to_map(b.x, b.y, sx, sy), 3.3, BALL)


func _disc_at(tex: Texture2D, c: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## Posició al minimapa d'un punt del camp (coordenades de la simulació).
static func to_map(x: float, y: float, sx: float, sy: float) -> Vector2:
	return Vector2(PAD + (x + HL) * sx, PAD + (y + HW) * sy)


## Disc blanc amb la vora suavitzada (hole > 0: anella, amb el forat en fracció del radi).
static func _disc(d: int, hole: float) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			if hole > 0.0:
				a = minf(a, clampf(dist - r * hole, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## El camp del minimapa: fons i línies, dibuixats un sol cop.
class MinimapField:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(18.0 / 255.0, 56.0 / 255.0, 32.0 / 255.0, 0.88))
		var sx := (size.x - Minimap.PAD * 2.0) / Constants.FL
		var sy := (size.y - Minimap.PAD * 2.0) / Constants.FW
		var line := Color(1, 1, 1, 0.55)
		var corner := Minimap.to_map(-Minimap.HL, -Minimap.HW, sx, sy)
		draw_rect(Rect2(corner, Vector2(Constants.FL * sx, Constants.FW * sy)), line, false, 1.2)
		for x: float in [0.0, -Constants.L23, Constants.L23]:
			draw_line(
				Minimap.to_map(x, -Minimap.HW, sx, sy),
				Minimap.to_map(x, Minimap.HW, sx, sy),
				line,
				1.2
			)
		for s: float in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 25:
				var a := PI * 0.5 + PI * i / 24.0
				if s < 0.0:
					a -= PI
				var x := s * Minimap.HL + cos(a) * Constants.CR
				var y := sin(a) * (Constants.CR + Constants.GHW)
				pts.append(Minimap.to_map(x, y, sx, sy))
			draw_polyline(pts, line, 1.2, true)
