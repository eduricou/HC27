# Genera les textures del camp (assets/textures/stadium/) i els dígits dels dorsals
# (assets/textures/players/), en PNG. Parteix de les funcions
# que a la web les dibuixen amb canvas en arrencar: makeNoise(), makeLED(),
# makeClubhouse(), makeFacade() i makeLamp() (línies 1387–1467 de la
# referència). Aquí es fan una sola vegada i es desen, perquè Godot les importi amb
# mipmaps.
#
# Ús: bash tools/bake_textures.sh   (obre una finestra un moment: dibuixar text necessita
# la GPU, i en mode headless no es pot)
#
# Diferències amb la web, buscades (el camp és com el real, docs/decisions/0006):
# - No hi ha grada: el públic és un atles de persones dretes (people.png) per a un
#   MultiMesh al passeig. Tampoc hi ha el frontal ni el mur de la grada.
# - Els anuncis (led.png) són pancartes de la tanca, amb els píxels quadrats (a la web el
#   text queda estirat).
# - Els arbres ja no són imatges: es fan en 3D (src/game/stadium/tree_mesh.gd).
# - La resta té el doble de resolució que a la web, amb el mateix dibuix.
extends SceneTree

const OUT := "res://assets/textures"
const FONT_FILE := "C:/Windows/Fonts/bahnschrift.ttf"

## Mida d'una persona de l'atles (0,6 x 1,8 m) i nombre de columnes i files.
const CELL := Vector2i(64, 192)
const ATLAS := Vector2i(8, 2)
## Les últimes cel·les de l'atles són afició del Polo.
const AWAY_CELLS := 5

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
const JACKETS := ["#2b2f36", "#5a3d2b", "#3c4a5e", "#6e1f22", "#4a5040"]
const TROUSERS := ["#3b4f6e", "#2a2a2e", "#b8a888", "#6d6f73", "#33465f"]

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
	for sub in ["stadium", "players"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/" + sub))
	_font = _make_font()
	_rng.seed = 2027
	_save(_noise(), "stadium/noise")
	await _bake("stadium/people", Vector2i(CELL.x * ATLAS.x, CELL.y * ATLAS.y), _draw_people, true)
	await _bake("stadium/led", Vector2i(4096, 64), _draw_led)
	await _bake("stadium/clubhouse", Vector2i(1024, 256), _draw_clubhouse)
	await _bake("stadium/lamp", Vector2i(128, 64), _draw_lamp)
	await _bake("players/digits", Vector2i(640, 64), _draw_digits, true)
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


## Atles de persones dretes, vistes de cara (el públic del passeig). Cada cel·la és una
## persona diferent; les últimes AWAY_CELLS són del Polo. Inspirat en makeCrowd().
func _draw_people(c: CanvasItem) -> void:
	var count := ATLAS.x * ATLAS.y
	for k in count:
		var origin := Vector2((k % ATLAS.x) * CELL.x, (k / ATLAS.x) * CELL.y)
		var away := k >= count - AWAY_CELLS
		var shirt: String
		if away:
			shirt = AWAY_SHIRTS[_rng.randi() % AWAY_SHIRTS.size()]
		elif _rng.randf() < 0.5:
			shirt = HOME_SHIRTS[_rng.randi() % HOME_SHIRTS.size()]
		else:
			shirt = NEUTRAL_SHIRTS[_rng.randi() % NEUTRAL_SHIRTS.size()]
		var jacket: Variant = null
		if _rng.randf() < 0.35:
			jacket = Color(JACKETS[_rng.randi() % JACKETS.size()])
		var p := {
			"shirt": Color(shirt),
			"skin": Color(Constants.SKINS[_rng.randi() % Constants.SKINS.size()]),
			"hair": Color(Constants.HAIRS[_rng.randi() % Constants.HAIRS.size()]),
			"trousers": Color(TROUSERS[_rng.randi() % TROUSERS.size()]),
			"jacket": jacket,
			"scarf": not away and _rng.randf() < 0.25,
			"pockets": _rng.randf() < 0.4,
		}
		_person(c, origin, p)


func _person(c: CanvasItem, o: Vector2, p: Dictionary) -> void:
	var cx := o.x + 32.0
	var skin: Color = p["skin"]
	var shirt: Color = p["shirt"]
	var outer: Color = p["jacket"] if p["jacket"] != null else shirt
	# Cames i sabates.
	var legs: Color = p["trousers"]
	c.draw_rect(Rect2(cx - 17.0, o.y + 98.0, 16.0, 80.0), legs)
	c.draw_rect(Rect2(cx + 1.0, o.y + 98.0, 16.0, 80.0), legs)
	c.draw_rect(Rect2(cx - 19.0, o.y + 176.0, 18.0, 9.0), Color("1e1d1c"))
	c.draw_rect(Rect2(cx + 1.0, o.y + 176.0, 18.0, 9.0), Color("1e1d1c"))
	# Braços (amb les mans a les butxaques o no).
	var arm_end := 84.0 if p["pockets"] else 96.0
	c.draw_rect(Rect2(cx - 26.0, o.y + 40.0, 8.0, arm_end - 40.0), outer)
	c.draw_rect(Rect2(cx + 18.0, o.y + 40.0, 8.0, arm_end - 40.0), outer)
	if not p["pockets"]:
		c.draw_circle(Vector2(cx - 22.0, o.y + 99.0), 4.5, skin, true, -1.0, true)
		c.draw_circle(Vector2(cx + 22.0, o.y + 99.0), 4.5, skin, true, -1.0, true)
	# Tors amb les espatlles arrodonides.
	var top := o.y + 35.0
	var w := 38.0
	var body := PackedVector2Array()
	body.append(Vector2(cx - w * 0.5, o.y + 102.0))
	for i in range(0, 9):
		var a := PI + i * (PI * 0.5) / 8.0
		body.append(Vector2(cx - w * 0.5 + 9.0 + cos(a) * 9.0, top + 9.0 + sin(a) * 9.0))
	for i in range(0, 9):
		var a := PI * 1.5 + i * (PI * 0.5) / 8.0
		body.append(Vector2(cx + w * 0.5 - 9.0 + cos(a) * 9.0, top + 9.0 + sin(a) * 9.0))
	body.append(Vector2(cx + w * 0.5, o.y + 102.0))
	c.draw_colored_polygon(body, outer)
	if p["jacket"] != null:
		# Jaqueta oberta: es veu la samarreta al mig.
		c.draw_rect(Rect2(cx - 5.0, top + 2.0, 10.0, 65.0), shirt)
	# Ombra del costat dret.
	c.draw_rect(Rect2(cx + w * 0.5 - 11.0, top + 4.0, 11.0, 63.0), Color(0, 0, 0, 0.16))
	c.draw_rect(Rect2(cx + 1.0, o.y + 98.0, 16.0, 80.0), Color(0, 0, 0, 0.12))
	c.draw_rect(Rect2(cx - 4.0, top - 5.0, 8.0, 7.0), skin.darkened(0.12))
	if p["scarf"]:
		c.draw_rect(Rect2(cx - 15.0, top - 1.0, 30.0, 7.0), Color("f07c1a"))
		c.draw_rect(Rect2(cx - 4.0, top - 1.0, 8.0, 7.0), Color.WHITE)
		c.draw_rect(Rect2(cx + 4.0, top + 6.0, 7.0, 24.0), Color("f07c1a"))
	# Cap i cabell.
	var head := Vector2(cx, o.y + 22.0)
	c.draw_circle(head, 11.0, skin, true, -1.0, true)
	var hair_pts := PackedVector2Array()
	for i in range(0, 17):
		var a := PI * 1.02 + i * (PI * 0.96) / 16.0
		hair_pts.append(head + Vector2(cos(a), sin(a)) * 11.6 + Vector2(0.0, -1.5))
	c.draw_colored_polygon(hair_pts, p["hair"])


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


# --- Dorsals i focus ------------------------------------------------------------------


## Dígits dels dorsals (0–9 en una fila de caselles de 64x64), en blanc sobre transparent:
## el color el posa el shader de l'equipació. ref: drawPlayer() (dorsal a l'esquena)
func _draw_digits(c: CanvasItem) -> void:
	# Amplada normal (no estreta): els dorsals han de ser gruixuts.
	var condensed := _font
	if _font is FontVariation:
		var wide := (_font as FontVariation).duplicate() as FontVariation
		var ts := TextServerManager.get_primary_interface()
		wide.variation_opentype = {ts.name_to_tag("wght"): 700, ts.name_to_tag("wdth"): 100}
		_font = wide
	for d in 10:
		_text(c, str(d), Vector2(d * 64 + 32, 33), 62, Color.WHITE, 60.0)
	_font = condensed


## Capçal del focus amb 2x4 llums. ref: makeLamp()
func _draw_lamp(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 128, 64), Color("2a2e33"))
	for j in 2:
		for i in 4:
			c.draw_circle(
				Vector2(16 + i * 32, 16 + j * 32), 12.0, Color("fffbe6"), true, -1.0, true
			)
