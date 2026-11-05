## Estadi: el Camp Municipal d'Hoquei de Mataró, amb la grada i el públic, les tanques
## LED, les banquetes, les torres de llum, la casa del club, els pins i la ciutat al fons.
## També porta la llum de tarda (sol amb ombres) o de nit (quatre focus), el cel i l'entorn.
## Es construeix per codi a partir de StadiumLayout (les mesures de glInit() a la web).
## ref: línies 1249–1579 (WebGL: estadi, gespa i cel) i drawGlows()
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
const LED_SHADER := preload("res://shaders/led.gdshader")
const FACADE_SHADER := preload("res://shaders/facade.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")

## Colors de la web (texSolid i altres).
const STEEL := Color("5d636a")
const DARK := Color("2a2f35")
const ROOF := Color("40464d")
const CONCRETE := Color("9b9e98")
const FLAT_ROOF := Color("8f8f88")
const SEAT_ORANGE := Color("e2711c")
const SEAT_WHITE := Color("f2f2ee")

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
	"spot_energy": 46.0,
	"spot_color": Color(1.0, 0.97, 0.9),
	# De nit el cel és gairebé negre: la llum ambient ve sobretot d'un color fix (el
	# rebot dels focus i la ciutat), perquè els arbres i la casa del club no siguin negres.
	"ambient": 1.0,
	"sky_ambient": 0.3,
	"ambient_color": Color(0.07, 0.085, 0.12),
	"exposure": 1.05,
	"fog": Color(0.07, 0.09, 0.14),
	"lamp": 9.0,
}
## Obertura dels focus (graus): tots apunten al centre del camp i la vora del con
## esmorteeix la llum a prop de la torre, perquè el camp quedi il·luminat igual.
const SPOT_ANGLE := 55.0
const SPOT_RANGE := 190.0
## Capa de render de l'estadi fix. Els focus de nit no en fan ombra (shadow_caster_mask):
## amb un con tan ample l'ombra surt a trossos, i així només la fan jugadors i porteries.
const STATIC_LAYER := 2
## Passadissos de la grada (x) i amplada.
const AISLES: Array[float] = [-15.5, 0.0, 15.5]
const AISLE_W := 1.3
const SEAT_PITCH := 0.5
const OCCUPANCY := 0.74
## Sector de l'afició del Polo.
const AWAY_X := Vector2(14.0, 30.5)

var night := true
var fx := StadiumFx.new()
var quality: Dictionary = {}

var _built := false
var _env: Environment
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _spots: Array[SpotLight3D] = []
var _lamp_mat: StandardMaterial3D
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
	add_child(_stand())
	add_child(_crowd())
	add_child(_led())
	add_child(_fences())
	add_child(_towers())
	add_child(_benches())
	add_child(_clubhouse())
	add_child(_city())
	add_child(_pines())
	for c in get_children():
		_set_layers(c)
	for side: int in [-1, 1]:
		var g := GoalView.new(side)
		g.fx = fx
		add_child(g)
	set_night(night)
	apply_quality(quality if not quality.is_empty() else Quality.preset(Quality.DEFAULT))


## Efectes que depenen del partit (xarxa, públic): un pas de simulació.
func on_step(events: Array[Dictionary]) -> void:
	fx.step(events, Constants.STEP)


## Un cop per fotograma: el públic i les tanques LED. `t`: temps del partit (s).
func update_frame(t: float) -> void:
	RenderingServer.global_shader_parameter_set(&"crowd_jump", fx.crowd_jump)
	RenderingServer.global_shader_parameter_set(&"led_scroll", StadiumFx.led_scroll(t))


# --- Llum i entorn -----------------------------------------------------------------


## Tarda (sol) o nit (focus). ref: OPTS.time, uNight
func set_night(on: bool) -> void:
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
	# El cel ha de refer el mapa de reflexos amb els colors nous.
	_sky_mat.set_shader_parameter("sun_dir", L.sun_view())


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
	for sp in _spots:
		sp.shadow_enabled = q["spot_shadows"]
	_env.ssao_enabled = q["ssao"]
	_env.ssil_enabled = q["ssil"]
	_env.glow_enabled = q["glow"]


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

	for t in L.TOWERS:
		var sp := SpotLight3D.new()
		sp.name = "Focus"
		var head := _tower_head_pos(t)
		sp.position = head
		sp.basis = Basis.looking_at(_tower_aim(t) - head, Vector3.UP)
		sp.light_color = NIGHT["spot_color"]
		sp.light_energy = NIGHT["spot_energy"]
		sp.spot_range = SPOT_RANGE
		sp.spot_angle = SPOT_ANGLE
		sp.spot_angle_attenuation = 0.6
		sp.spot_attenuation = 1.0
		sp.shadow_enabled = true
		sp.shadow_caster_mask = ~STATIC_LAYER
		sp.shadow_blur = 1.5
		sp.light_specular = 0.35
		add_child(sp)
		_spots.append(sp)


static func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = STATIC_LAYER
	for c in n.get_children():
		_set_layers(c)


## Centre del capçal dels focus de la torre t (coordenades de Godot).
static func _tower_head_pos(t: Vector2) -> Vector3:
	return Coords.to_view(t.x, t.y + (0.7 if t.y < 0.0 else -0.7), L.TOWER_H + 1.8)


## Punt on apunten els focus de la torre t: el centre del camp.
static func _tower_aim(_t: Vector2) -> Vector3:
	return Vector3.ZERO


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


# --- Terra ------------------------------------------------------------------------------


## Gespa, voral i herba fins a l'horitzó, amb el shader de la web. ref: bGround, FS_GROUND
func _ground() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Terra"
	var pm := PlaneMesh.new()
	pm.size = Vector2(520.0, 400.0)
	mi.mesh = pm
	mi.position = Coords.to_view(0.0, -60.0, 0.0)
	mi.material_override = _shader_mat(TURF_SHADER, {"noise_tex": _tex("noise")})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- Grada ------------------------------------------------------------------------------


func _stand() -> Node3D:
	var root := Node3D.new()
	root.name = "Grada"
	var x0 := L.STAND_X0
	var x1 := L.STAND_X1
	var yf := L.STAND_YF
	var yb := L.STAND_YB
	var conc := MeshBuilder.new()
	# Graons: petja i contrapetja de cada fila.
	for r in L.STAND_ROWS:
		var z := L.row_z(r)
		var ya := L.row_y(r)
		var yn := L.row_y(r + 1)
		conc.quad(
			Vector3(x0, ya, z),
			Vector3(x1, ya, z),
			Vector3(x1, yn, z),
			Vector3(x0, yn, z),
			Vector3(0, 0, 1)
		)
		if r > 0:
			var zp := L.row_z(r - 1)
			conc.quad(
				Vector3(x0, ya, zp),
				Vector3(x1, ya, zp),
				Vector3(x1, ya, z),
				Vector3(x0, ya, z),
				Vector3(0, 1, 0)
			)
	# Laterals (amb gruix) i mur del darrere.
	for s: float in [-1.0, 1.0]:
		var xi := x0 if s < 0.0 else x1
		var xo := xi + s * 0.3
		for xx: float in [xi, xo]:
			var pts: Array[Vector3] = [
				Vector3(xx, yf - 0.25, 0.0),
				Vector3(xx, yb - 0.3, 0.0),
				Vector3(xx, yb - 0.3, L.STAND_BACK_H),
				Vector3(xx, yf - 0.25, L.STAND_Z0),
			]
			conc.polygon(pts, Vector3(s if xx == xo else -s, 0, 0))
		var e := Vector3(0, 0, 1)
		conc.quad(
			Vector3(xi, yf - 0.25, L.STAND_Z0),
			Vector3(xo, yf - 0.25, L.STAND_Z0),
			Vector3(xo, yb - 0.3, L.STAND_BACK_H),
			Vector3(xi, yb - 0.3, L.STAND_BACK_H),
			e
		)
		conc.quad(
			Vector3(xi, yf - 0.25, 0.0),
			Vector3(xo, yf - 0.25, 0.0),
			Vector3(xo, yf - 0.25, L.STAND_Z0),
			Vector3(xi, yf - 0.25, L.STAND_Z0),
			Vector3(0, 1, 0)
		)
	conc.box(x0, x1, yb - 0.3, yb, 0.0, L.STAND_BACK_H)
	root.add_child(conc.to_instance("Formigo", _mat(CONCRETE, 0.95)))
	# Mur de davant amb la franja taronja. ref: makeWall()
	var wall := MeshBuilder.new()
	wall.box(x0, x1, yf - 0.25, yf, 0.0, L.STAND_Z0, 8.0)
	root.add_child(wall.to_instance("Mur", _tex_mat("wall")))
	# Part de dalt del mur del darrere, fosca. ref: T.dark
	var dark := MeshBuilder.new()
	dark.quad(
		Vector3(x0, yb + 0.01, L.STAND_Z1),
		Vector3(x1, yb + 0.01, L.STAND_Z1),
		Vector3(x1, yb + 0.01, L.STAND_BACK_H),
		Vector3(x0, yb + 0.01, L.STAND_BACK_H),
		Vector3(0, 1, 0)
	)
	root.add_child(dark.to_instance("Fons", _mat(DARK), false))
	# Coberta inclinada, amb gruix.
	var roof := MeshBuilder.new()
	var rf := L.ROOF_FRONT
	var rb := L.ROOF_BACK
	var t := 0.3
	roof.quad(
		Vector3(x0 - 1, rf.x, rf.y + t),
		Vector3(x1 + 1, rf.x, rf.y + t),
		Vector3(x1 + 1, rb.x, rb.y + t),
		Vector3(x0 - 1, rb.x, rb.y + t),
		Vector3(0, 0, 1)
	)
	roof.quad(
		Vector3(x0 - 1, rf.x, rf.y),
		Vector3(x1 + 1, rf.x, rf.y),
		Vector3(x1 + 1, rb.x, rb.y),
		Vector3(x0 - 1, rb.x, rb.y),
		Vector3(0, 0, -1)
	)
	roof.quad(
		Vector3(x0 - 1, rb.x, rb.y),
		Vector3(x1 + 1, rb.x, rb.y),
		Vector3(x1 + 1, rb.x, rb.y + t),
		Vector3(x0 - 1, rb.x, rb.y + t),
		Vector3(0, -1, 0)
	)
	for s: float in [-1.0, 1.0]:
		var xx := (x0 - 1) if s < 0.0 else (x1 + 1)
		roof.quad(
			Vector3(xx, rf.x, rf.y),
			Vector3(xx, rb.x, rb.y),
			Vector3(xx, rb.x, rb.y + t),
			Vector3(xx, rf.x, rf.y + t),
			Vector3(s, 0, 0)
		)
	root.add_child(roof.to_instance("Coberta", _mat(ROOF, 0.7)))
	# Frontal de la coberta amb el nom del camp. ref: makeFascia()
	var fascia := MeshBuilder.new()
	var fy := rf.x
	fascia.quad(
		Vector3(x0 - 1, fy + 0.02, 11.2),
		Vector3(x1 + 1, fy + 0.02, 11.2),
		Vector3(x1 + 1, fy + 0.02, rf.y + t + 0.05),
		Vector3(x0 - 1, fy + 0.02, rf.y + t + 0.05),
		Vector3(0, 1, 0),
		Vector2.ZERO,
		Vector2(2, 1)
	)
	var fm := _tex_mat("fascia", 0.6)
	root.add_child(fascia.to_instance("Frontal", fm))
	var fback := MeshBuilder.new()
	fback.box(x0 - 1, x1 + 1, fy - 0.2, fy, 11.2, rf.y + t + 0.05, 0.0, 1.0, true)
	root.add_child(fback.to_instance("FrontalDarrere", _mat(DARK)))
	# Pilars.
	var steel := MeshBuilder.new()
	for cx in L.STAND_COLUMNS:
		steel.box(cx - 0.18, cx + 0.18, yf + 0.42, yf + 0.78, 0.0, rf.y)
	# Sense ombra: de nit els focus en farien unes falques fosques sobre el públic.
	root.add_child(steel.to_instance("Pilars", _mat(STEEL, 0.5), false))
	return root


## Seients i públic (MultiMesh). ref: makeCrowd()
func _crowd() -> Node3D:
	var root := Node3D.new()
	root.name = "Public"
	var rng := RandomNumberGenerator.new()
	rng.seed = 35
	var seats: Array[Vector3] = []
	var seat_cols: Array[Color] = []
	var people: Array[Vector3] = []
	var cells: Array[int] = []
	var n_seats := int((L.STAND_X1 - L.STAND_X0) / SEAT_PITCH)
	for r in L.STAND_ROWS:
		var z := L.row_z(r)
		var y := L.row_y(r) - 0.95
		for i in n_seats:
			var x := L.STAND_X0 + SEAT_PITCH * (i + 0.5)
			var aisle := false
			for a in AISLES:
				aisle = aisle or absf(x - a) < AISLE_W * 0.5
			if aisle:
				continue
			seats.append(Vector3(x, y, z))
			seat_cols.append(SEAT_WHITE if (i + r) % 9 == 0 else SEAT_ORANGE)
			if rng.randf() < OCCUPANCY:
				var away := x > AWAY_X.x and x < AWAY_X.y and rng.randf() < 0.85
				var cell := 48 + rng.randi() % 16 if away else rng.randi() % 48
				people.append(Vector3(x + rng.randf_range(-0.05, 0.05), y + 0.12, z))
				cells.append(cell)
	# Seients.
	var seat_mesh := MeshBuilder.new()
	seat_mesh.box(-0.21, 0.21, -0.12, 0.22, 0.38, 0.45)
	seat_mesh.box(-0.21, 0.21, -0.2, -0.12, 0.45, 0.85)
	seat_mesh.box(-0.04, 0.04, -0.05, 0.05, 0.0, 0.38, 0.0, 1.0, false)
	var sm := _mat(Color.WHITE, 0.6)
	sm.vertex_color_use_as_albedo = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = seat_mesh.to_mesh()
	mm.instance_count = seats.size()
	for i in seats.size():
		var p := seats[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Coords.to_view(p.x, p.y, p.z)))
		mm.set_instance_color(i, seat_cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Seients"
	mmi.multimesh = mm
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	# Persones: quads de 0,53 x 0,8 m mirant al camp, amb una cel·la de l'atles.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.533, 0.8)
	quad.center_offset = Vector3(0.0, 0.4, 0.0)
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_custom_data = true
	pm.mesh = quad
	pm.instance_count = people.size()
	for i in people.size():
		var p := people[i]
		pm.set_instance_transform(i, Transform3D(Basis(), Coords.to_view(p.x, p.y, p.z + 0.42)))
		pm.set_instance_custom_data(i, Color(cells[i], rng.randf(), 0.0, 0.0))
	var pmi := MultiMeshInstance3D.new()
	pmi.name = "Persones"
	pmi.multimesh = pm
	pmi.material_override = _shader_mat(CROWD_SHADER, {"atlas": _tex("crowd")})
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pmi)
	return root


# --- Tanques LED -------------------------------------------------------------------------


## ref: T.led i el seu marc fosc (línies 1510–1513)
func _led() -> Node3D:
	var root := Node3D.new()
	root.name = "LED"
	var scr := MeshBuilder.new()
	var frame := MeshBuilder.new()
	var y := L.LED_Y
	scr.quad(
		Vector3(-L.LED_X, y, 0.05),
		Vector3(L.LED_X, y, 0.05),
		Vector3(L.LED_X, y, 0.95),
		Vector3(-L.LED_X, y, 0.95),
		Vector3(0, 1, 0),
		Vector2.ZERO,
		Vector2(L.LED_X * 2.0 / 64.0, 1.0)
	)
	frame.box(-L.LED_X - 0.1, L.LED_X + 0.1, y - 0.25, y - 0.005, 0.0, 1.0)
	for s: float in [-1.0, 1.0]:
		var x := s * L.LED_END_X
		for span in L.LED_END_SPANS:
			var len := (span.y - span.x) / 64.0
			var u0 := Vector2(0.0 if s > 0.0 else len, 0.0)
			var u1 := Vector2(len if s > 0.0 else 0.0, 1.0)
			scr.quad(
				Vector3(x, span.x, 0.05),
				Vector3(x, span.y, 0.05),
				Vector3(x, span.y, 0.95),
				Vector3(x, span.x, 0.95),
				Vector3(-s, 0, 0),
				u0,
				u1
			)
			frame.box(
				minf(x + s * 0.005, x + s * 0.25),
				maxf(x + s * 0.005, x + s * 0.25),
				span.x - 0.1,
				span.y + 0.1,
				0.0,
				1.0
			)
	root.add_child(
		scr.to_instance("Pantalles", _shader_mat(LED_SHADER, {"ads": _tex("led")}), false)
	)
	root.add_child(frame.to_instance("Marcs", _mat(DARK)))
	return root


# --- Tanques i xarxes -----------------------------------------------------------------


func _fences() -> Node3D:
	var root := Node3D.new()
	root.name = "Tanques"
	var steel := MeshBuilder.new()
	# Xarxes altes darrere de les porteries. ref: T.net (línies 1540–1542)
	var tall := MeshBuilder.new()
	for s: float in [-1.0, 1.0]:
		var x := s * L.BACKNET_X
		var h := L.BACKNET_H
		var w := L.BACKNET_Y
		tall.quad(
			Vector3(x, -w, 0),
			Vector3(x, w, 0),
			Vector3(x, w, h),
			Vector3(x, -w, h),
			Vector3(-s, 0, 0),
			Vector2.ZERO,
			Vector2(w * 2.0, h)
		)
		for py: float in [-16.0, -8.0, 0.0, 8.0, 16.0]:
			steel.box(x - 0.06, x + 0.06, py - 0.06, py + 0.06, 0.0, h + 0.2)
	var tall_mat := _shader_mat(
		NET_SHADER,
		{"cell": 0.25, "thread": 0.008, "haze": 0.0, "net_color": Color(0.75, 0.78, 0.76, 0.7)}
	)
	root.add_child(tall.to_instance("XarxesFons", tall_mat, false))
	# Tanca baixa de reixa al voltant del voral (no hi és a la web).
	var low := MeshBuilder.new()
	var hx := L.APRON_X
	var y0 := L.APRON_Y0
	var y1 := L.APRON_Y1
	var runs: Array = [
		[Vector2(-hx, y1), Vector2(hx, y1)],
		[Vector2(-hx, y0), Vector2(-hx, y1)],
		[Vector2(hx, y0), Vector2(hx, y1)],
		[Vector2(-hx, y0), Vector2(L.STAND_X0 - 0.3, y0)],
		[Vector2(L.STAND_X1 + 0.3, y0), Vector2(hx, y0)],
	]
	var fh := 1.1
	for run: Array in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var len := a.distance_to(b)
		var facing := (
			Vector3(0, -signf(a.y), 0) if absf(a.y - b.y) < 0.01 else Vector3(-signf(a.x), 0, 0)
		)
		low.quad(
			Vector3(a.x, a.y, 0),
			Vector3(b.x, b.y, 0),
			Vector3(b.x, b.y, fh),
			Vector3(a.x, a.y, fh),
			facing,
			Vector2.ZERO,
			Vector2(len, fh)
		)
		var posts := ceili(len / 2.5)
		for k in posts + 1:
			var p := a.lerp(b, float(k) / posts)
			steel.box(p.x - 0.03, p.x + 0.03, p.y - 0.03, p.y + 0.03, 0.0, fh + 0.05)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(0.025, 0.025)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(0.025, 0.025)
		steel.box(lo.x, hi.x, lo.y, hi.y, fh, fh + 0.05)
	var low_mat := _shader_mat(
		NET_SHADER,
		{"cell": 0.07, "thread": 0.005, "haze": 0.04, "net_color": Color(0.32, 0.4, 0.35, 1.0)}
	)
	root.add_child(low.to_instance("Reixa", low_mat, false))
	root.add_child(steel.to_instance("Pals", _mat(STEEL, 0.5)))
	return root


# --- Torres de llum ---------------------------------------------------------------------


func _towers() -> Node3D:
	var root := Node3D.new()
	root.name = "Torres"
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_texture = _tex("lamp")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission_texture = _tex("lamp")
	_lamp_mat.emission = Color(1.0, 0.95, 0.85)
	_lamp_mat.roughness = 0.4
	var pole_mat := _mat(STEEL, 0.5)
	var back_mat := _mat(STEEL, 0.5)
	var flare_tex := GradientTexture2D.new()
	flare_tex.fill = GradientTexture2D.FILL_RADIAL
	flare_tex.fill_from = Vector2(0.5, 0.5)
	flare_tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.97, 0.88, 0.75))
	grad.set_color(1, Color(1.0, 0.9, 0.75, 0.0))
	grad.add_point(0.25, Color(1.0, 0.93, 0.8, 0.25))
	flare_tex.gradient = grad
	var flare_mat := StandardMaterial3D.new()
	flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flare_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flare_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flare_mat.albedo_texture = flare_tex
	flare_mat.no_depth_test = false
	flare_mat.disable_fog = true
	for t in L.TOWERS:
		var tower := Node3D.new()
		tower.name = "Torre"
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.42
		cm.height = L.TOWER_H + 1.2
		cm.radial_segments = 12
		pole.mesh = cm
		pole.position = Coords.to_view(t.x, t.y, cm.height * 0.5)
		pole.material_override = pole_mat
		tower.add_child(pole)
		# Capçal orientat cap al camp, amb els focus a la cara de davant.
		var head := Node3D.new()
		var hp := _tower_head_pos(t)
		var aim := _tower_aim(t)
		head.position = hp
		head.basis = Basis.looking_at(aim - hp, Vector3.UP)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(5.8, 3.0, 0.3)
		box.mesh = bm
		box.material_override = back_mat
		head.add_child(box)
		var lamps := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(5.6, 2.8)
		lamps.mesh = qm
		lamps.position = Vector3(0, 0, -0.16)
		lamps.rotation = Vector3(0, PI, 0)
		lamps.material_override = _lamp_mat
		head.add_child(lamps)
		var deck := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(6.2, 0.12, 1.4)
		deck.mesh = dm
		deck.position = Vector3(0, -1.7, 0.1)
		deck.material_override = pole_mat
		head.add_child(deck)
		var flare := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(16.0, 16.0)
		flare.mesh = fq
		flare.position = Vector3(0, 0, -1.0)
		flare.material_override = flare_mat
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(flare)
		_flares.append(flare)
		tower.add_child(head)
		root.add_child(tower)
	return root


# --- Banquetes --------------------------------------------------------------------------


## Banquetes dels dos equips, al costat de la càmera (no hi són a la web).
func _benches() -> Node3D:
	var root := Node3D.new()
	root.name = "Banquetes"
	var shell := MeshBuilder.new()
	var seat := MeshBuilder.new()
	var roof := MeshBuilder.new()
	var colors := [Color("f07c1a"), Color("14234b")]
	var front := L.BENCH_Y0
	var back := L.BENCH_Y1
	# Sentit de darrere cap a davant (cap al camp).
	var f := signf(front - back)
	var h := L.BENCH_H
	for i in L.BENCH_X.size():
		var cx: float = L.BENCH_X[i]
		var x0 := cx - L.BENCH_W * 0.5
		var x1 := cx + L.BENCH_W * 0.5
		_ybox(shell, x0, x1, back - f * 0.08, back, 0.0, h)
		_ybox(shell, x0 - 0.08, x0, back, front, 0.0, h)
		_ybox(shell, x1, x1 + 0.08, back, front, 0.0, h)
		_ybox(roof, x0 - 0.1, x1 + 0.1, back - f * 0.1, front + f * 0.3, h, h + 0.06)
		_ybox(seat, x0 + 0.2, x1 - 0.2, back + f * 0.05, back + f * 0.5, 0.42, 0.5)
		_ybox(seat, x0 + 0.2, x1 - 0.2, back + f * 0.02, back + f * 0.1, 0.5, 0.95)
		var band := MeshBuilder.new()
		_ybox(band, x0 - 0.1, x1 + 0.1, front + f * 0.3, front + f * 0.36, h - 0.18, h + 0.1)
		root.add_child(band.to_instance("Franja%d" % i, _mat(colors[i], 0.5)))
	root.add_child(shell.to_instance("Estructura", _mat(Color("dfe3e6"), 0.4)))
	root.add_child(seat.to_instance("Bancs", _mat(Color("3a3f45"), 0.6)))
	# Sostre de policarbonat fumat.
	var rm := _mat(Color(0.55, 0.62, 0.68, 0.45), 0.2)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	root.add_child(roof.to_instance("Sostre", rm))
	return root


## Caixa amb els límits de y en qualsevol ordre.
static func _ybox(
	b: MeshBuilder, x0: float, x1: float, ya: float, yb: float, z0: float, z1: float
) -> void:
	b.box(x0, x1, minf(ya, yb), maxf(ya, yb), z0, z1)


# --- Casa del club, ciutat i pins -------------------------------------------------------


func _facade_mat(tex: String, cells: Vector2, lit: float) -> ShaderMaterial:
	return _shader_mat(FACADE_SHADER, {"tex": _tex(tex), "cells": cells, "lit_ratio": lit})


## ref: makeClubhouse() i box(cw, ...) (línia 1518)
func _clubhouse() -> Node3D:
	var root := Node3D.new()
	root.name = "CasaClub"
	var r := L.CLUBHOUSE
	var walls := MeshBuilder.new()
	walls.box(r.position.x, r.end.x, r.position.y, r.end.y, 0.0, L.CLUBHOUSE_H, 15.0, 1.0, false)
	root.add_child(walls.to_instance("Parets", _facade_mat("clubhouse", Vector2(9.0, 3.0), 0.7)))
	var roof := MeshBuilder.new()
	roof.box(
		r.position.x - 0.3,
		r.end.x + 0.3,
		r.position.y - 0.3,
		r.end.y + 0.3,
		L.CLUBHOUSE_H,
		L.CLUBHOUSE_H + 0.35
	)
	root.add_child(roof.to_instance("Teulada", _mat(ROOF, 0.8)))
	return root


## Hospital i blocs de pisos al fons. ref: línies 1520–1524
func _city() -> Node3D:
	var root := Node3D.new()
	root.name = "Ciutat"
	var hosp := MeshBuilder.new()
	var roofs := MeshBuilder.new()
	var h := L.HOSPITAL
	hosp.box(
		h.position.x,
		h.end.x,
		h.position.y,
		h.end.y,
		0.0,
		L.HOSPITAL_H,
		24.0,
		L.HOSPITAL_H / 30.0,
		false
	)
	roofs.quad(
		Vector3(h.position.x, h.end.y, L.HOSPITAL_H),
		Vector3(h.end.x, h.end.y, L.HOSPITAL_H),
		Vector3(h.end.x, h.position.y, L.HOSPITAL_H),
		Vector3(h.position.x, h.position.y, L.HOSPITAL_H),
		Vector3(0, 0, 1)
	)
	root.add_child(
		hosp.to_instance(
			"Hospital", _facade_mat("facade_hospital", Vector2(8.0, 10.0), 0.55), false
		)
	)
	var flats := MeshBuilder.new()
	var rnd := StadiumLayout.ParkMiller.new()
	for blk: Array in L.city_blocks(rnd):
		var b: Rect2 = blk[0]
		var bh: float = blk[1]
		flats.box(b.position.x, b.end.x, b.position.y, b.end.y, 0.0, bh, 24.0, bh / 30.0, false)
		roofs.quad(
			Vector3(b.position.x, b.end.y, bh),
			Vector3(b.end.x, b.end.y, bh),
			Vector3(b.end.x, b.position.y, bh),
			Vector3(b.position.x, b.position.y, bh),
			Vector3(0, 0, 1)
		)
	root.add_child(
		flats.to_instance("Pisos", _facade_mat("facade_flats", Vector2(8.0, 10.0), 0.62), false)
	)
	root.add_child(roofs.to_instance("Terrats", _mat(FLAT_ROOF, 0.9), false))
	return root


## Pins pinyers: quads creuats (com a la web) i una copa plana per veure'ls des de dalt.
## ref: línies 1525–1539
func _pines() -> Node3D:
	var root := Node3D.new()
	root.name = "Pins"
	var rnd := StadiumLayout.ParkMiller.new()
	L.city_blocks(rnd)
	var side := MeshBuilder.new()
	var top := MeshBuilder.new()
	for t in L.pines(rnd):
		var w := 11.0 * t.z
		var h := 12.0 * t.z
		side.cross_quad(t.x, t.y, w, 0.0, h)
		var r := w * 0.36
		var zc := h * 0.72
		top.quad(
			Vector3(t.x - r, t.y + r, zc),
			Vector3(t.x + r, t.y + r, zc),
			Vector3(t.x + r, t.y - r, zc),
			Vector3(t.x - r, t.y - r, zc),
			Vector3(0, 0, 1)
		)
	root.add_child(side.to_instance("Arbres", _shader_mat(FOLIAGE_SHADER, {"tex": _tex("pine")})))
	root.add_child(
		top.to_instance(
			"Copes", _shader_mat(FOLIAGE_SHADER, {"tex": _tex("pine_top"), "sway": 0.0})
		)
	)
	return root
