# Genera les textures de l'estadi a assets/textures/stadium/ (PNG). És el port de les
# funcions que a la web les dibuixen amb canvas en arrencar: makeNoise(), makeCrowd(),
# makeLED(), makeFascia(), makeWall(), makeClubhouse(), makeFacade(), makePine() i
# makeLamp() (línies 1387–1467 de la referència). Aquí es fan una sola vegada i es
# desen, perquè Godot les importi amb mipmaps.
#
# Ús: bash tools/bake_textures.sh   (obre una finestra un moment: dibuixar text necessita
# la GPU, i en mode headless no es pot)
#
# Diferències amb la web, buscades:
# - La grada és en 3D: el públic és un atles de persones (crowd.png) per a un MultiMesh,
#   no una textura amb els seients pintats.
# - Les tanques LED tenen els píxels quadrats (a la web el text queda estirat) i la
#   quadrícula de LED la fa el shader.
# - La resta té el doble de resolució que a la web, amb el mateix dibuix.
extends SceneTree

const OUT := "res://assets/textures/stadium"
const FONT_FILE := "C:/Windows/Fonts/bahnschrift.ttf"

## Mida d'una persona de l'atles i nombre de columnes i files.
const CELL := Vector2i(64, 96)
const ATLAS := Vector2i(8, 8)
## Les últimes cel·les de l'atles són afició del Polo.
const AWAY_CELLS := 16

const LED_ADS := [
	["ILURO HC", "#f07c1a", "#ffffff"],
	["MATARÓ", "#ffffff", "#14234b"],
	["HOQUEI HERBA", "#0e1a14", "#c4e84a"],
	["EL MARESME", "#14234b", "#ffffff"],
	["CAMP MUNICIPAL", "#f07c1a", "#241002"],
	["FORÇA ILURO", "#111214", "#f07c1a"],
	["CLUB POLO", "#ffffff", "#c8102e"],
	["PAPIS +35", "#1d2a5a", "#f2c500"],
]
const HOME_SHIRTS := ["#f07c1a", "#ffffff", "#f07c1a", "#111214"]
const AWAY_SHIRTS := ["#f6f6f3", "#14234b", "#14234b", "#c8102e"]
const NEUTRAL_SHIRTS := [
	"#3a5a8c", "#8a2a2a", "#2f6b3a", "#d9c27a", "#454545", "#b8b8b8", "#7b4f9a", "#2a7f86"
]

var _font: Font
var _rng := RandomNumberGenerator.new()


class Painter:
	extends Node2D
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_font = _make_font()
	_rng.seed = 2027
	_save(_noise(), "noise")
	await _bake("crowd", Vector2i(CELL.x * ATLAS.x, CELL.y * ATLAS.y), _draw_crowd, true)
	await _bake("led", Vector2i(4096, 64), _draw_led)
	await _bake("fascia", Vector2i(2048, 64), _draw_fascia)
	await _bake("wall", Vector2i(256, 64), _draw_wall)
	await _bake("clubhouse", Vector2i(1024, 256), _draw_clubhouse)
	await _bake("facade_hospital", Vector2i(256, 256), _draw_facade.bind(Color("e9e7e0"), true))
	await _bake("facade_flats", Vector2i(256, 256), _draw_facade.bind(Color("c8b699"), false))
	await _bake("pine", Vector2i(256, 256), _draw_pine, true)
	await _bake("pine_top", Vector2i(128, 128), _draw_pine_top, true)
	await _bake("lamp", Vector2i(128, 64), _draw_lamp)
	print("Textures desades a %s" % OUT)
	quit(0)


func _make_font() -> Font:
	# Bahnschrift (Windows) en negreta estreta s'assembla a la Barlow Condensed de la web.
	if FileAccess.file_exists(FONT_FILE):
		var ff := FontFile.new()
		if ff.load_dynamic_font(FONT_FILE) == OK:
			var fv := FontVariation.new()
			fv.base_font = ff
			var ts := TextServerManager.get_primary_interface()
			fv.variation_opentype = {ts.name_to_tag("wght"): 700, ts.name_to_tag("wdth"): 75}
			return fv
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Arial Narrow", "Arial"])
	sf.font_weight = 700
	return sf


## Dibuixa amb `fn` en un SubViewport de mida `size` i desa la imatge.
func _bake(name: String, size: Vector2i, fn: Callable, transparent: bool = false) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var p := Painter.new()
	p.fn = fn
	vp.add_child(p)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if transparent:
		_unpremultiply(img)
	_save(img, name)
	vp.queue_free()


func _save(img: Image, name: String) -> void:
	var path := "%s/%s.png" % [OUT, name]
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("No he pogut desar %s (%d)" % [path, err])
	else:
		print("  %s (%dx%d)" % [path, img.get_width(), img.get_height()])


## El viewport transparent desa el color multiplicat per l'alfa: es desfà perquè les
## vores no surtin fosques.
static func _unpremultiply(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.a < 1.0:
				img.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, c.a))


# --- Soroll -------------------------------------------------------------------------


## Tres capes de soroll de valor que es repeteixen sense costures. ref: makeNoise()
## R: soroll fi (gra de la gespa) · G: taques mitjanes · B: taques grans.
func _noise() -> Image:
	var n := 256
	var g1 := _grid(32)
	var g2 := _grid(8)
	var g3 := _grid(64)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var u := float(i) / n
			var v := float(j) / n
			var r := _rng.randf() * 0.6 + _sample(g3, 64, u, v) * 0.4
			img.set_pixel(i, j, Color(r, _sample(g1, 32, u, v), _sample(g2, 8, u, v), 1.0))
	return img


func _grid(g: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(g * g)
	for i in a.size():
		a[i] = _rng.randf()
	return a


static func _sample(a: PackedFloat32Array, g: int, u: float, v: float) -> float:
	var fx := u * g
	var fy := v * g
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sy := ty * ty * (3.0 - 2.0 * ty)
	var at := func(i: int, j: int) -> float: return a[posmod(j, g) * g + posmod(i, g)]
	return lerpf(
		lerpf(at.call(x0, y0), at.call(x0 + 1, y0), sx),
		lerpf(at.call(x0, y0 + 1), at.call(x0 + 1, y0 + 1), sx),
		sy
	)


# --- Públic -------------------------------------------------------------------------


## Atles de persones assegudes, vistes de cara. Cada cel·la és una persona diferent;
## les últimes AWAY_CELLS són del Polo. ref: makeCrowd()
func _draw_crowd(c: CanvasItem) -> void:
	var count := ATLAS.x * ATLAS.y
	for k in count:
		var origin := Vector2((k % ATLAS.x) * CELL.x, (k / ATLAS.x) * CELL.y)
		var away := k >= count - AWAY_CELLS
		var shirt: String
		if away:
			shirt = AWAY_SHIRTS[_rng.randi() % AWAY_SHIRTS.size()]
		elif _rng.randf() < 0.55:
			shirt = HOME_SHIRTS[_rng.randi() % HOME_SHIRTS.size()]
		else:
			shirt = NEUTRAL_SHIRTS[_rng.randi() % NEUTRAL_SHIRTS.size()]
		var skin := Color(Constants.SKINS[_rng.randi() % Constants.SKINS.size()])
		var hair := Color(Constants.HAIRS[_rng.randi() % Constants.HAIRS.size()])
		var arms := _rng.randf() < 0.14
		var scarf := not away and _rng.randf() < 0.18
		_person(c, origin, Color(shirt), skin, hair, arms, scarf)


func _person(
	c: CanvasItem, o: Vector2, shirt: Color, skin: Color, hair: Color, arms: bool, scarf: bool
) -> void:
	var cx := o.x + 32.0
	var w := 44.0
	if arms:
		# Braços enlaire.
		c.draw_rect(Rect2(cx - w * 0.5, o.y + 8.0, 8.0, 46.0), skin)
		c.draw_rect(Rect2(cx + w * 0.5 - 8.0, o.y + 8.0, 8.0, 46.0), skin)
		c.draw_rect(Rect2(cx - w * 0.5 - 1.0, o.y + 40.0, 10.0, 16.0), shirt)
		c.draw_rect(Rect2(cx + w * 0.5 - 9.0, o.y + 40.0, 10.0, 16.0), shirt)
	# Tors: rectangle amb les espatlles arrodonides.
	var top := o.y + 50.0
	var body := PackedVector2Array()
	body.append(Vector2(cx - w * 0.5, o.y + CELL.y))
	for i in range(0, 9):
		var a := PI + i * (PI * 0.5) / 8.0
		body.append(Vector2(cx - w * 0.5 + 12.0 + cos(a) * 12.0, top + 12.0 + sin(a) * 12.0))
	for i in range(0, 9):
		var a := PI * 1.5 + i * (PI * 0.5) / 8.0
		body.append(Vector2(cx + w * 0.5 - 12.0 + cos(a) * 12.0, top + 12.0 + sin(a) * 12.0))
	body.append(Vector2(cx + w * 0.5, o.y + CELL.y))
	c.draw_colored_polygon(body, shirt)
	# Ombra del costat dret.
	c.draw_rect(Rect2(cx + w * 0.5 - 14.0, top + 4.0, 14.0, CELL.y - 54.0), Color(0, 0, 0, 0.18))
	# Coll.
	c.draw_rect(Rect2(cx - 5.0, top - 6.0, 10.0, 8.0), skin.darkened(0.12))
	if scarf:
		c.draw_rect(Rect2(cx - w * 0.5 - 2.0, top + 2.0, w + 4.0, 8.0), Color("f07c1a"))
		c.draw_rect(Rect2(cx - 8.0, top + 2.0, 10.0, 8.0), Color.WHITE)
		c.draw_rect(Rect2(cx + 6.0, top + 10.0, 8.0, 20.0), Color("f07c1a"))
	# Cap i cabell.
	var head := Vector2(cx, top - 16.0)
	c.draw_circle(head, 13.0, skin, true, -1.0, true)
	var hair_pts := PackedVector2Array()
	for i in range(0, 17):
		var a := PI * 1.02 + i * (PI * 0.96) / 16.0
		hair_pts.append(head + Vector2(cos(a), sin(a)) * 13.6 + Vector2(0.0, -2.0))
	c.draw_colored_polygon(hair_pts, hair)


# --- Rètols i façanes ---------------------------------------------------------------


func _text(
	c: CanvasItem, text: String, center: Vector2, size: int, color: Color, max_w: float = 0.0
) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var sx := 1.0 if max_w <= 0.0 or tw <= max_w else max_w / tw
	var base := center.y + (_font.get_ascent(size) - _font.get_descent(size)) * 0.5
	c.draw_set_transform(Vector2(center.x - tw * sx * 0.5, base), 0.0, Vector2(sx, 1.0))
	c.draw_string(_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	c.draw_set_transform(Vector2.ZERO)


## Vuit anuncis de 512x64. ref: makeLED()
func _draw_led(c: CanvasItem) -> void:
	for i in LED_ADS.size():
		var ad: Array = LED_ADS[i]
		c.draw_rect(Rect2(i * 512, 0, 512, 64), Color(ad[1]))
		_text(c, ad[0], Vector2(i * 512 + 256, 33), 50, Color(ad[2]), 470.0)


## ref: makeFascia()
func _draw_fascia(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 2048, 64), Color("16201c"))
	c.draw_rect(Rect2(0, 52, 2048, 12), Color("f07c1a"))
	_text(c, "CAMP MUNICIPAL D'HOQUEI · MATARÓ", Vector2(1024, 26), 40, Color("eef2ec"))


## Mur de davant de la grada. ref: makeWall()
func _draw_wall(c: CanvasItem) -> void:
	for y in 64:
		var k := y / 63.0
		c.draw_rect(Rect2(0, y, 256, 1), Color("a3a69f").lerp(Color("83867f"), k))
	c.draw_rect(Rect2(0, 8, 256, 7), Color("f07c1a"))
	for x in range(0, 256, 64):
		c.draw_rect(Rect2(x, 0, 2, 64), Color(0, 0, 0, 0.15))


## Façana de la casa del club (el doble de la web). ref: makeClubhouse()
func _draw_clubhouse(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 1024, 256), Color("ecebe4"))
	c.draw_rect(Rect2(0, 0, 1024, 32), Color("f07c1a"))
	_text(c, "ILURO HC", Vector2(70, 17), 26, Color.WHITE)
	for i in 9:
		c.draw_rect(Rect2(44 + i * 108, 72, 68, 60), Color("2f55e0"))
		c.draw_rect(Rect2(44 + i * 108, 128, 68, 6), Color("d9d7cf"))
	c.draw_rect(Rect2(472, 164, 80, 92), Color("5b4a3c"))
	c.draw_rect(Rect2(44, 176, 180, 52), Color("2f55e0"))
	c.draw_rect(Rect2(800, 176, 180, 52), Color("2f55e0"))


## Façana d'edifici amb 8x10 finestres (blau = vidre; de nit se n'encenen algunes).
## ref: makeFacade()
func _draw_facade(c: CanvasItem, base: Color, big: bool) -> void:
	c.draw_rect(Rect2(0, 0, 256, 256), base)
	for j in 10:
		for i in 8:
			var size := Vector2(22, 15) if big else Vector2(18, 13)
			c.draw_rect(Rect2(Vector2(6 + i * 32, 8 + j * 25.6), size), Color("2f55e0"))
	for j in 10:
		c.draw_rect(Rect2(0, j * 25.6, 256, 2), Color(0, 0, 0, 0.08))


# --- Pi pinyer i focus ----------------------------------------------------------------


static func _quad_curve(
	a: Vector2, ctrl: Vector2, b: Vector2, steps: int = 16
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


static func _ellipse(c: CanvasItem, center: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	c.draw_colored_polygon(pts, color)


## Pi pinyer amb la copa plana. ref: makePine()
func _draw_pine(c: CanvasItem) -> void:
	var trunk := Color("5a3d28")
	var t := _quad_curve(Vector2(128, 256), Vector2(118, 170), Vector2(132, 92))
	c.draw_polyline(t, trunk, 12.0, true)
	c.draw_polyline(
		_quad_curve(Vector2(130, 120), Vector2(100, 100), Vector2(74, 86)), trunk, 5.0, true
	)
	c.draw_polyline(
		_quad_curve(Vector2(131, 110), Vector2(160, 96), Vector2(186, 84)), trunk, 5.0, true
	)
	for i in 26:
		var k := i / 25.0
		var cx := 30.0 + k * 196.0 + (_rng.randf() - 0.5) * 12.0
		var cy := 78.0 - sin(k * PI) * 22.0 + (_rng.randf() - 0.5) * 10.0
		_ellipse(c, Vector2(cx, cy + 6.0), Vector2(26, 14), Color("1c3218"))
	for i in 30:
		var k := i / 29.0
		var cx := 34.0 + k * 188.0 + (_rng.randf() - 0.5) * 10.0
		var cy := 70.0 - sin(k * PI) * 24.0 + (_rng.randf() - 0.5) * 8.0
		_ellipse(
			c,
			Vector2(cx, cy),
			Vector2(22, 12),
			Color("2c4a24") if _rng.randf() < 0.5 else Color("33552a")
		)
	for i in 16:
		var k := _rng.randf()
		var cx := 50.0 + k * 156.0
		var cy := 60.0 - sin(k * PI) * 24.0
		_ellipse(c, Vector2(cx, cy), Vector2(12, 6), Color("46703a"))


## Copa del pi vista des de dalt (no hi és a la web): taques dels mateixos verds dins
## d'un cercle, per a les vistes altes.
func _draw_pine_top(c: CanvasItem) -> void:
	var center := Vector2(64, 64)
	for layer: Array in [
		[30, 20.0, 50.0, Color("1c3218")],
		[34, 17.0, 44.0, Color("2c4a24")],
		[18, 11.0, 36.0, Color("46703a")]
	]:
		for i in int(layer[0]):
			var a := _rng.randf() * TAU
			var d: float = sqrt(_rng.randf()) * float(layer[2])
			var r: float = float(layer[1]) * (0.7 + _rng.randf() * 0.5)
			var col: Color = layer[3]
			if layer[3] == Color("2c4a24") and _rng.randf() < 0.5:
				col = Color("33552a")
			_ellipse(c, center + Vector2(cos(a), sin(a)) * d, Vector2(r, r * 0.85), col)


## Capçal del focus amb 2x4 llums. ref: makeLamp()
func _draw_lamp(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 128, 64), Color("2a2e33"))
	for j in 2:
		for i in 4:
			c.draw_circle(
				Vector2(16 + i * 32, 16 + j * 32), 12.0, Color("fffbe6"), true, -1.0, true
			)
