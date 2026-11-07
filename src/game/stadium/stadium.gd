## El camp de l'Iluro HC al carrer Galícia de Mataró, com el real (docs/decisions/0006):
## gespa amb el voral de formigó, el passeig amb les banquetes i el públic dret, tanques,
## la bardissa i el talús de l'est, sis torres de llum, les casetes del club, el carrer
## amb cotxes, i camps i muntanyes al fons, sense edificis (com el real, segons l'usuari).
## També porta la llum de tarda (sol amb ombres) o de nit (focus), el cel i l'entorn. Es
## construeix per codi amb StadiumLayout.
## ref: línies 1249–1579 de la web (gespa, cel, pins) i drawGlows()
class_name Stadium
extends Node3D

const L := preload("res://src/game/stadium/stadium_layout.gd")
const HL := Constants.HL
const HW := Constants.HW
const TEX := "res://assets/textures/stadium/%s.png"

const TURF_SHADER := preload("res://shaders/turf.gdshader")
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const NET_SHADER := preload("res://shaders/net.gdshader")
const CROWD_SHADER := preload("res://shaders/crowd.gdshader")
const FACADE_SHADER := preload("res://shaders/facade.gdshader")

const STEEL := Color("5d636a")
const CONCRETE := Color("a3a29b")
const FENCE_GREEN := Color(0.2, 0.3, 0.24, 1.0)
const CAR_COLORS: Array[Color] = [
	Color("e9e9e6"),
	Color("b9bcc0"),
	Color("1d1f22"),
	Color("26375c"),
	Color("8e2320"),
	Color("6c7075"),
	Color("f2f2f0"),
	Color("3f4a3c"),
]

## Llum de tarda i de nit (s'ajusta mirant les captures de tools/shot_views.sh).
const DAY := {
	"sun_energy": 2.1,
	"sun_color": Color(1.0, 0.95, 0.86),
	"ambient": 0.9,
	"sky_ambient": 1.0,
	"ambient_color": Color(0.5, 0.55, 0.6),
	"exposure": 1.0,
	"fog": Color(0.84, 0.83, 0.78),
}
const NIGHT := {
	"spot_energy": 22.0,
	"spot_color": Color(1.0, 0.97, 0.9),
	# De nit el cel és gairebé negre: la llum ambient ve sobretot d'un color fix (el
	# rebot dels focus), perquè els arbres i les casetes no siguin negres.
	"ambient": 1.0,
	"sky_ambient": 0.3,
	"ambient_color": Color(0.07, 0.085, 0.12),
	"exposure": 1.05,
	"fog": Color(0.07, 0.09, 0.14),
	"lamp": 9.0,
	"street_lamp": 5.0,
}
## Focus: obertura (graus) i abast. Cada torre il·lumina la meitat de l'altra banda.
const SPOT_ANGLE := 62.0
const SPOT_RANGE := 115.0
## Ordre en què els focus fan ombra quan el preset en limita el nombre (Quality,
## spot_shadows): primer les dues torres del mig del passeig, que il·luminen el centre i fan
## les ombres cap a la càmera TV.
const SPOT_SHADOW_ORDER: Array[int] = [1, 2, 0, 3, 4, 5]
## Capa de render de les coses fixes. Els focus de nit no en fan ombra (shadow_caster_mask):
## amb un con tan ample l'ombra surt a trossos, i així només la fan jugadors i porteries.
const STATIC_LAYER := 2

var night := true
var fx := StadiumFx.new()
var quality: Dictionary = {}

var _built := false
var _env: Environment
var _sky_mat: ShaderMaterial
var _turf_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _spots: Array[SpotLight3D] = []
var _lamp_mat: StandardMaterial3D
var _street_lamp_mat: StandardMaterial3D
var _flares: Array[MeshInstance3D] = []
var _textures := {}


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	_build_lighting()
	add_child(_ground())
	add_child(_east_slope())
	add_child(_fences())
	add_child(_banners())
	add_child(_hedge())
	add_child(_poles())
	add_child(_benches())
	add_child(_spectators())
	add_child(_huts())
	add_child(_street())
	add_child(_vegetation())
	for c in get_children():
		_set_layers(c)
	for side: int in [-1, 1]:
		var g := GoalView.new(side)
		g.fx = fx
		add_child(g)
	add_child(_spare_goals())
	set_night(night)
	apply_quality(quality if not quality.is_empty() else Quality.preset(Quality.DEFAULT))


## Efectes que depenen del partit (xarxa, públic): un pas de simulació.
func on_step(events: Array[Dictionary]) -> void:
	fx.step(events, Constants.STEP)


## Un cop per fotograma: el públic.
func update_frame() -> void:
	RenderingServer.global_shader_parameter_set(&"crowd_jump", fx.crowd_jump)


# --- Llum i entorn -----------------------------------------------------------------


## Tarda (sol) o nit (focus). ref: OPTS.time, uNight
## Amb resize_shadows = false no es toca la mida dels mapes d'ombres (escalfament de
## shaders: així no hi ha mai els dos mapes grans alhora).
func set_night(on: bool, resize_shadows := true) -> void:
	night = on
	RenderingServer.global_shader_parameter_set(&"night", 1.0 if on else 0.0)
	if not _built:
		return
	_sun.visible = not on
	for sp in _spots:
		sp.visible = on
	for f in _flares:
		f.visible = on
	var cfg: Dictionary = NIGHT if on else DAY
	_env.ambient_light_energy = cfg["ambient"]
	_env.ambient_light_sky_contribution = cfg["sky_ambient"]
	_env.ambient_light_color = cfg["ambient_color"]
	_env.tonemap_exposure = cfg["exposure"]
	_env.fog_light_color = cfg["fog"]
	_lamp_mat.emission_energy_multiplier = NIGHT["lamp"] if on else 0.0
	_street_lamp_mat.emission_energy_multiplier = NIGHT["street_lamp"] if on else 0.0
	_sky_mat.set_shader_parameter("sun_dir", L.sun_view())
	if resize_shadows and not quality.is_empty():
		Quality.apply_shadow_atlases(quality, get_viewport(), on)


func apply_quality(q: Dictionary) -> void:
	quality = q
	if not _built:
		return
	_sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		if q["sun_splits"] <= 2
		else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	)
	_sun.directional_shadow_max_distance = q["sun_dist"]
	for i in _spots.size():
		_spots[i].shadow_enabled = SPOT_SHADOW_ORDER.find(i) < int(q["spot_shadows"])
	_env.ssao_enabled = q["ssao"]
	_env.ssil_enabled = q["ssil"]
	_env.glow_enabled = q["glow"]
	Quality.apply_shadow_atlases(q, get_viewport(), night)


func _build_lighting() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.02
	_env.glow_hdr_threshold = 1.2
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = 110.0
	_env.fog_depth_end = 430.0
	_env.fog_density = 0.8
	_env.fog_sky_affect = 0.0
	_env.ssao_radius = 1.2
	_env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.name = "Entorn"
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sol"
	_sun.basis = Basis.looking_at(-L.sun_view(), Vector3.UP)
	_sun.light_color = DAY["sun_color"]
	_sun.light_energy = DAY["sun_energy"]
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.2
	_sun.directional_shadow_blend_splits = true
	add_child(_sun)

	for p in L.POLES:
		var sp := SpotLight3D.new()
		sp.name = "Focus"
		var head := _pole_head_pos(p)
		sp.position = head
		sp.basis = Basis.looking_at(_pole_aim(p) - head, Vector3.UP)
		sp.light_color = NIGHT["spot_color"]
		sp.light_energy = NIGHT["spot_energy"]
		sp.spot_range = SPOT_RANGE
		sp.spot_angle = SPOT_ANGLE
		sp.spot_angle_attenuation = 0.7
		sp.spot_attenuation = 1.0
		sp.shadow_enabled = true
		sp.shadow_caster_mask = ~STATIC_LAYER
		sp.shadow_blur = 1.5
		sp.light_specular = 0.35
		add_child(sp)
		_spots.append(sp)


## Centre del capçal dels focus de la torre p (coordenades de Godot).
static func _pole_head_pos(p: Vector2) -> Vector3:
	return Coords.to_view(p.x, p.y - 0.5 * signf(p.y), L.POLE_H + 0.8)


## Punt on apunten els focus de la torre p: la meitat del camp de l'altra banda.
static func _pole_aim(p: Vector2) -> Vector3:
	return Coords.to_view(p.x * 0.85, -signf(p.y) * 7.0, 0.0)


static func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = STATIC_LAYER
	for c in n.get_children():
		_set_layers(c)


# --- Materials ------------------------------------------------------------------------


func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(TEX % name)
	return _textures[name]


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _tex_mat(name: String, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(name)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _shader_mat(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


func _facade_mat(tex: String, cells: Vector2, lit: float) -> ShaderMaterial:
	return _shader_mat(FACADE_SHADER, {"tex": _tex(tex), "cells": cells, "lit_ratio": lit})


static func _emissive(c: Color) -> StandardMaterial3D:
	var m := _mat(c, 0.4)
	m.emission_enabled = true
	m.emission = c
	return m


# --- Terra ------------------------------------------------------------------------------


## Gespa, voral, carrer i terreny fins a l'horitzó, amb el shader de la web adaptat al
## camp real. ref: bGround, FS_GROUND
func _ground() -> MeshInstance3D:
	var huts := L.HUTS_AREA
	_turf_mat = _shader_mat(
		TURF_SHADER,
		{
			"noise_tex": _tex("noise"),
			"apron_x": L.APRON_X,
			"walk_y": L.WALK_Y,
			"east_y": L.EAST_Y,
			"sidewalk_y": L.SIDEWALK_Y,
			"street_y0": L.STREET_Y0,
			"street_y1": L.STREET_Y1,
			"houses_y": L.HOUSES_Y,
			"roundabout": L.ROUNDABOUT,
			"huts_area": Vector4(huts.position.x, huts.position.y, huts.end.x, huts.end.y),
		}
	)
	var mi := MeshInstance3D.new()
	mi.name = "Terra"
	var pm := PlaneMesh.new()
	pm.size = Vector2(520.0, 400.0)
	mi.mesh = pm
	mi.position = Coords.to_view(0.0, -60.0, 0.0)
	mi.material_override = _turf_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Talús de l'est amb la carretera de dalt i la bionda.
func _east_slope() -> Node3D:
	var root := Node3D.new()
	root.name = "Talus"
	var x0 := -150.0
	var x1 := 150.0
	var ground := MeshBuilder.new()
	var steps: Array[Vector2] = [
		Vector2(L.SLOPE_Y0, 0.0),
		Vector2(L.ROAD_Y0, L.ROAD_Z),
		Vector2(L.ROAD_Y1, L.ROAD_Z),
		L.SLOPE_TOP,
		Vector2(220.0, L.SLOPE_TOP.y),
	]
	for i in steps.size() - 1:
		if i == 1:
			continue  # la carretera
		var a := steps[i]
		var b := steps[i + 1]
		ground.quad(
			Vector3(x0, a.x, a.y),
			Vector3(x1, a.x, a.y),
			Vector3(x1, b.x, b.y),
			Vector3(x0, b.x, b.y),
			Vector3(0, -0.3, 1)
		)
	root.add_child(ground.to_instance("Terreny", _turf_mat, false))
	var road := MeshBuilder.new()
	var z := L.ROAD_Z + 0.02
	road.quad(
		Vector3(x0, L.ROAD_Y0, z),
		Vector3(x1, L.ROAD_Y0, z),
		Vector3(x1, L.ROAD_Y1, z),
		Vector3(x0, L.ROAD_Y1, z),
		Vector3(0, 0, 1)
	)
	root.add_child(road.to_instance("Carretera", _mat(Color("3a3b3d"), 0.9), false))
	var rail := MeshBuilder.new()
	var ry := L.ROAD_Y0 + 0.4
	rail.box(x0, x1, ry - 0.04, ry, z + 0.45, z + 0.75)
	var x := x0
	while x <= x1:
		rail.box(x - 0.05, x + 0.05, ry, ry + 0.1, z, z + 0.75)
		x += 4.0
	root.add_child(rail.to_instance("Bionda", _mat(Color("b8bcbf"), 0.4), false))
	return root


# --- Tanques, xarxes, pancartes i bardissa ------------------------------------------------


## Tram de reixa de a fins a b (simulació), de z0 a z0 + h, amb pals cada 2,5 m.
static func _fence_run(
	wire: MeshBuilder, steel: MeshBuilder, a: Vector2, b: Vector2, z0: float, h: float
) -> void:
	var len := a.distance_to(b)
	var along_x := absf(a.y - b.y) < 0.01
	var facing := Vector3(0, -signf(a.y), 0) if along_x else Vector3(-signf(a.x), 0, 0)
	wire.quad(
		Vector3(a.x, a.y, z0),
		Vector3(b.x, b.y, z0),
		Vector3(b.x, b.y, z0 + h),
		Vector3(a.x, a.y, z0 + h),
		facing,
		Vector2.ZERO,
		Vector2(len, h)
	)
	var posts := ceili(len / 2.5)
	for k in posts + 1:
		var p := a.lerp(b, float(k) / posts)
		steel.box(p.x - 0.03, p.x + 0.03, p.y - 0.03, p.y + 0.03, 0.0, z0 + h + 0.05)
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(0.025, 0.025)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(0.025, 0.025)
	steel.box(lo.x, hi.x, lo.y, hi.y, z0 + h, z0 + h + 0.05)


func _fences() -> Node3D:
	var root := Node3D.new()
	root.name = "Tanques"
	var steel := MeshBuilder.new()
	var wire := MeshBuilder.new()
	var ax := L.APRON_X
	# Passeig de l'oest: muret de formigó i reixa a sobre.
	var wall := MeshBuilder.new()
	wall.box(-ax, ax, L.WALK_Y - 0.22, L.WALK_Y, 0.0, 0.45)
	root.add_child(wall.to_instance("Muret", _mat(CONCRETE, 0.95)))
	var wy := L.WALK_Y - 0.1
	_fence_run(wire, steel, Vector2(-ax, wy), Vector2(ax, wy), 0.45, L.FENCE_H - 0.45)
	# Est i extrems: reixa més baixa.
	var h := L.EAST_FENCE_H
	_fence_run(wire, steel, Vector2(-ax, L.EAST_Y), Vector2(ax, L.EAST_Y), 0.0, h)
	for s: float in [-1.0, 1.0]:
		_fence_run(wire, steel, Vector2(s * ax, L.WALK_Y), Vector2(s * ax, L.EAST_Y), 0.0, h)
	var wire_mat := _shader_mat(
		NET_SHADER, {"cell": 0.07, "thread": 0.005, "haze": 0.04, "net_color": FENCE_GREEN}
	)
	root.add_child(wire.to_instance("Reixa", wire_mat, false))
	# Xarxes altes de darrere les porteries.
	var tall := MeshBuilder.new()
	for n: Dictionary in [L.SOUTH_NET, L.NORTH_NET]:
		var x: float = n["x"]
		var y0: float = n["y0"]
		var y1: float = n["y1"]
		var nh: float = n["h"]
		tall.quad(
			Vector3(x, y0, 0),
			Vector3(x, y1, 0),
			Vector3(x, y1, nh),
			Vector3(x, y0, nh),
			Vector3(-signf(x), 0, 0),
			Vector2.ZERO,
			Vector2(y1 - y0, nh)
		)
		var py := y0
		while py <= y1 + 0.01:
			steel.box(x - 0.07, x + 0.07, py - 0.07, py + 0.07, 0.0, nh + 0.2)
			py += 4.0
	var tall_mat := _shader_mat(
		NET_SHADER,
		{"cell": 0.12, "thread": 0.005, "haze": 0.0, "net_color": Color(0.72, 0.75, 0.74, 0.45)}
	)
	root.add_child(tall.to_instance("XarxesAltes", tall_mat, false))
	root.add_child(steel.to_instance("Pals", _mat(STEEL, 0.5)))
	return root


## Pancartes dels patrocinadors penjades a la tanca del passeig (a la web eren tanques LED).
## Cada una mostra un dels vuit anuncis de led.png. ref: makeLED()
func _banners() -> Node3D:
	var root := Node3D.new()
	root.name = "Pancartes"
	var mb := MeshBuilder.new()
	var y := L.WALK_Y + 0.02
	var xs: Array[float] = [-42.0, -34.5, -24.0, -17.5, 17.5, 24.0, 34.5, 42.0]
	for i in xs.size():
		var x0 := xs[i] - 3.2
		var x1 := xs[i] + 3.2
		mb.quad(
			Vector3(x0, y, 0.55),
			Vector3(x1, y, 0.55),
			Vector3(x1, y, 1.35),
			Vector3(x0, y, 1.35),
			Vector3(0, 1, 0),
			Vector2(i / 8.0, 0.0),
			Vector2((i + 1) / 8.0, 1.0)
		)
	root.add_child(mb.to_instance("Lones", _tex_mat("led", 0.75), false))
	return root


## Bardissa de l'est, de 3 m: un massís de fulles (com els arbres) amb el perfil arrodonit
## i irregular, una mica més alt o més baix per trams.
func _hedge() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Bardissa"
	mi.mesh = TreeMesh.hedge(-L.APRON_X - 8.0, L.APRON_X + 8.0, L.HEDGE_D, L.HEDGE_H, _foliage())
	mi.position = Coords.to_view(0.0, L.HEDGE_Y, 0.0)
	return mi


# --- Torres de llum ---------------------------------------------------------------------


func _poles() -> Node3D:
	var root := Node3D.new()
	root.name = "Torres"
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_texture = _tex("lamp")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission_texture = _tex("lamp")
	_lamp_mat.emission = Color(1.0, 0.95, 0.85)
	_lamp_mat.roughness = 0.4
	var pole_mat := _mat(STEEL, 0.5)
	var flare_mat := _flare_material()
	for p in L.POLES:
		var tower := Node3D.new()
		tower.name = "Torre"
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.14
		cm.bottom_radius = 0.26
		cm.height = L.POLE_H + 0.6
		cm.radial_segments = 10
		pole.mesh = cm
		pole.position = Coords.to_view(p.x, p.y, cm.height * 0.5)
		pole.material_override = pole_mat
		tower.add_child(pole)
		# Capçal orientat cap al camp, amb els focus a la cara de davant.
		var head := Node3D.new()
		var hp := _pole_head_pos(p)
		head.position = hp
		head.basis = Basis.looking_at(_pole_aim(p) - hp, Vector3.UP)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.4, 1.7, 0.25)
		box.mesh = bm
		box.material_override = pole_mat
		head.add_child(box)
		var lamps := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(3.2, 1.5)
		lamps.mesh = qm
		lamps.position = Vector3(0, 0, -0.14)
		lamps.rotation = Vector3(0, PI, 0)
		lamps.material_override = _lamp_mat
		head.add_child(lamps)
		var flare := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(10.0, 10.0)
		flare.mesh = fq
		flare.position = Vector3(0, 0, -0.8)
		flare.material_override = flare_mat
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(flare)
		_flares.append(flare)
		tower.add_child(head)
		root.add_child(tower)
	return root


## Halo dels focus de nit. ref: drawGlows()
static func _flare_material() -> StandardMaterial3D:
	var flare_tex := GradientTexture2D.new()
	flare_tex.fill = GradientTexture2D.FILL_RADIAL
	flare_tex.fill_from = Vector2(0.5, 0.5)
	flare_tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.97, 0.88, 0.75))
	grad.set_color(1, Color(1.0, 0.9, 0.75, 0.0))
	grad.add_point(0.25, Color(1.0, 0.93, 0.8, 0.25))
	flare_tex.gradient = grad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = flare_tex
	m.disable_fog = true
	return m


# --- Banquetes i públic -------------------------------------------------------------------


## Banquetes dels dos equips al passeig, a la línia del mig, amb la cabina de la taula al
## mig, com les reals (Dugout). Miren cap al camp.
func _benches() -> Node3D:
	var root := Dugout.build()
	root.position = Coords.to_view(0.0, L.BENCH_Y1, 0.0)
	return root


## Públic dret al passeig: un quad per persona (MultiMesh) amb l'atles people.png. Els del
## Polo, al sector del nord. ref: makeCrowd()
func _spectators() -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 35
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 1.8)
	quad.center_offset = Vector3(0.0, 0.9, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = L.SPECTATORS
	# Fins a mig metre més enllà de les banquetes.
	var bench_x := absf(L.BENCH_X[1]) + L.BENCH_W * 0.5 + 0.5
	for i in L.SPECTATORS:
		var x := rng.randf_range(-HL, HL)
		var y := rng.randf_range(L.WALK_Y + 0.4, L.WALK_Y + 1.8)
		if absf(x) < bench_x:
			# Darrere les banquetes hi ha poc lloc.
			y = rng.randf_range(L.WALK_Y + 0.4, L.BENCH_Y1 - 0.4)
		var away := x > 18.0 and rng.randf() < 0.8
		var cell := 11 + rng.randi() % 5 if away else rng.randi() % 11
		mm.set_instance_transform(i, Transform3D(Basis(), Coords.to_view(x, y, 0.0)))
		mm.set_instance_custom_data(i, Color(cell, rng.randf(), 0.0, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Public"
	mmi.multimesh = mm
	mmi.material_override = _shader_mat(
		CROWD_SHADER, {"atlas": _tex("people"), "grid": Vector2(8, 2)}
	)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


# --- Casetes del club i carrer ------------------------------------------------------


## Casetes del club al nord, darrere la porteria. ref: makeClubhouse() per al rètol
func _huts() -> Node3D:
	var root := Node3D.new()
	root.name = "CasetesClub"
	for i in L.HUTS.size():
		var hut: Array = L.HUTS[i]
		var r: Rect2 = hut[0]
		var h: float = hut[1]
		var walls := MeshBuilder.new()
		var wall_mat: Material
		if hut[2] == "club":
			walls.box(r.position.x, r.end.x, r.position.y, r.end.y, 0.0, h, 12.0, 1.0, false)
			wall_mat = _facade_mat("clubhouse", Vector2(9.0, 3.0), 0.7)
		else:
			walls.box(r.position.x, r.end.x, r.position.y, r.end.y, 0.0, h, 0.0, 1.0, false)
			wall_mat = _mat(Color(hut[2]), 0.85)
		root.add_child(walls.to_instance("Caseta%d" % i, wall_mat))
		var roof := MeshBuilder.new()
		roof.box(
			r.position.x - 0.25, r.end.x + 0.25, r.position.y - 0.25, r.end.y + 0.25, h, h + 0.22
		)
		root.add_child(roof.to_instance("Teulada%d" % i, _mat(Color(hut[3]), 0.7)))
	return root


## Carrer Galícia: cotxes aparcats, fanals i arbres. A l'altra banda no hi ha edificis:
## herba seca i matolls fins a les muntanyes del fons (el cel).
func _street() -> Node3D:
	var root := Node3D.new()
	root.name = "Carrer"
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	root.add_child(_cars(rng))
	# Fanals a la vorera.
	var poles := MeshBuilder.new()
	var heads := MeshBuilder.new()
	_street_lamp_mat = _emissive(Color(1.0, 0.8, 0.5))
	var lx := -70.0
	while lx <= 40.0:
		var ly := L.SIDEWALK_Y - 0.6
		poles.box(lx - 0.07, lx + 0.07, ly - 0.07, ly + 0.07, 0.0, 7.5)
		poles.box(lx - 0.05, lx + 0.05, ly - 1.4, ly, 7.4, 7.5)
		heads.box(lx - 0.3, lx + 0.3, ly - 1.7, ly - 1.1, 7.2, 7.4)
		lx += 22.0
	root.add_child(poles.to_instance("Fanals", _mat(STEEL, 0.5)))
	root.add_child(heads.to_instance("Llums", _street_lamp_mat, false))
	# Arbres de fulla a la franja de darrere la tanca.
	var spots: Array[Vector4] = []
	for t in L.street_trees():
		spots.append(Vector4(t.x, t.y, 0.0, 1.0))
	var kinds: Array[ArrayMesh] = []
	for i in 3:
		kinds.append(TreeMesh.broadleaf(51 + i, _foliage()))
	root.add_child(_forest("Arbres", kinds, spots, true))
	return root


## Cotxes aparcats al costat del camp: carrosseria (amb color) i vidres.
func _cars(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Cotxes"
	var body := MeshBuilder.new()
	body.box(-2.1, 2.1, -0.87, 0.87, 0.28, 1.0)
	var cabin := MeshBuilder.new()
	cabin.box(-1.2, 1.0, -0.78, 0.78, 1.0, 1.48)
	var spots: Array[Vector2] = []
	var cx := -80.0
	while cx < 40.0:
		if rng.randf() < 0.75:
			spots.append(Vector2(cx, L.STREET_Y0 - 1.2))
		cx += rng.randf_range(4.8, 6.5)
	var bodies := MultiMesh.new()
	bodies.transform_format = MultiMesh.TRANSFORM_3D
	bodies.use_colors = true
	bodies.mesh = body.to_mesh()
	bodies.instance_count = spots.size()
	var cabins := MultiMesh.new()
	cabins.transform_format = MultiMesh.TRANSFORM_3D
	cabins.mesh = cabin.to_mesh()
	cabins.instance_count = spots.size()
	for i in spots.size():
		var t := Transform3D(Basis(), Coords.to_view(spots[i].x, spots[i].y, 0.0))
		bodies.set_instance_transform(i, t)
		bodies.set_instance_color(i, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
		cabins.set_instance_transform(i, t)
	var car_mat := _mat(Color.WHITE, 0.3)
	car_mat.vertex_color_use_as_albedo = true
	car_mat.metallic = 0.4
	var bmi := MultiMeshInstance3D.new()
	bmi.name = "Carrosseries"
	bmi.multimesh = bodies
	bmi.material_override = car_mat
	root.add_child(bmi)
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "Vidres"
	cmi.multimesh = cabins
	cmi.material_override = _mat(Color("1a2028"), 0.15)
	root.add_child(cmi)
	return root


## Pins pinyers i arbustos al talús, al camp del sud i darrere les casetes (TreeMesh).
func _vegetation() -> Node3D:
	var root := Node3D.new()
	root.name = "Vegetacio"
	var veg := L.vegetation()
	var pines: Array[ArrayMesh] = []
	for i in 4:
		pines.append(TreeMesh.pine(11 + i, _foliage()))
	var bushes: Array[ArrayMesh] = []
	for i in 3:
		bushes.append(TreeMesh.bush(31 + i, _foliage()))
	root.add_child(_forest("Pins", pines, veg["pines"], true))
	root.add_child(_forest("Arbustos", bushes, veg["bushes"], false))
	return root


## Material del fullatge, compartit per tots els arbres.
func _foliage() -> ShaderMaterial:
	if not _textures.has("foliage"):
		_textures["foliage"] = TreeMesh.foliage_material(_tex("noise"))
	return _textures["foliage"]


## Arbres repetits: per a cada lloc (x, y, z, escala, en coordenades de la simulació), una
## de les variants `meshes`, girada a l'atzar (sempre igual). Un MultiMesh per variant.
func _forest(
	node_name: String, meshes: Array[ArrayMesh], spots: Array[Vector4], shadows: bool
) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var groups: Array[Array] = []
	for m in meshes:
		groups.append([])
	for i in spots.size():
		var t := spots[i]
		var yaw := fposmod(t.x * 12.9898 + t.y * 78.233, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * t.w)
		groups[i % meshes.size()].append(Transform3D(basis, Coords.to_view(t.x, t.y, t.z)))
	for v in meshes.size():
		if groups[v].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[v]
		mm.instance_count = groups[v].size()
		for k in groups[v].size():
			mm.set_instance_transform(k, groups[v][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%d" % [node_name, v]
		mmi.multimesh = mm
		mmi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		root.add_child(mmi)
	return root


## Dues porteries de recanvi al sud, entre la línia de fons i la xarxa alta (a la foto
## aèria es veuen al costat de l'est).
func _spare_goals() -> Node3D:
	var root := Node3D.new()
	root.name = "PorteriesRecanvi"
	for y: float in [11.0, 16.0]:
		var holder := Node3D.new()
		# GoalView es construeix a x = HL: es porta al seu lloc i es gira cap al camp.
		holder.transform = (
			Transform3D(Basis(Vector3.UP, PI), Coords.to_view(-HL - 5.6, y, 0.0))
			* Transform3D(Basis(), Vector3(-HL, 0.0, 0.0))
		)
		holder.add_child(GoalView.new(1))
		root.add_child(holder)
	return root
