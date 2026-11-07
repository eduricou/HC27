## Jugador amb esquelet i animacions (fase 4): el cos base de Quaternius (CC0) amb
## l'equipació pintada (KitMesh i shaders/player_kit.gdshader) i la complexió de cada
## jugador, cabells i barba, sabatilles, l'equip del porter, el pal i les animacions de la
## UAL passades a aquest esquelet (tools/build_player_anims.gd). La postura (ajupit o dret,
## segons la jugada) va per sobre de l'animació; el pal i les mans els col·loca StickPlacer
## i les dues mans l'agafen amb IK (TwoBoneIK3D) i GripModifier3D. Decisions:
## docs/decisions/0007 i 0011.
## Coordenades locals: el jugador mira cap a −Z i el +X és el costat del pal (com
## PlayerView); el model mira cap a +Z i per això va girat 180°.
class_name PlayerRig
extends Node3D

const BODY_SCENE := preload("res://assets/models/players/Superhero_Male_FullBody.gltf")
const ANIMS := preload("res://assets/models/animations/players.res")
const KIT_SHADER := preload("res://shaders/player_kit.gdshader")
const HAIR_SHADER := preload("res://shaders/hair.gdshader")
const TEX := "res://assets/models/players/%s.png"
const DIGITS := "res://assets/textures/players/digits.png"
const HAIR_SCENES: Array[String] = [
	"res://assets/models/players/hair/Hair_Buzzed.gltf",
	"res://assets/models/players/hair/Hair_SimpleParted.gltf",
	"res://assets/models/players/hair/Hair_Long.gltf",
]
const BEARD_SCENE := "res://assets/models/players/hair/Hair_Beard.gltf"
## Pentinat per a cada valor de p.hs (0–4): índex de HAIR_SCENES, o −1 si és calb.
const HAIRSTYLE: Array[int] = [0, 1, 2, -1, 0]

## Locomoció: caminar, córrer i esprintar es mesclen segons la velocitat, sincronitzats
## (els tres cicles estirats a 1 s i començant amb el peu esquerre a terra; vegeu
## tools/build_player_anims.gd). El ritme, en cicles per segon, és la velocitat dividida
## per la passa: així el peu de suport va enrere tan de pressa com avança el jugador i no
## rellisca. El repòs es barreja a part, a velocitats de caminar o menys.
## Arbre: output ← shot (OneShot: action) ← move (Blend2: idle | rate ← loco).
const GAIT: Array[String] = ["walk", "jog", "sprint"]

## Complexions dels Papis: [alçada (escala), gruix (m), panxa (m), músculs llisos (0–1)].
## El model és un superheroi: tots en perden el relleu i les espatlles (shaders/player_kit).
const BUILDS: Array[Vector4] = [
	Vector4(1.04, -0.012, 0.015, 1.0),  # prim i alt
	Vector4(1.0, -0.002, 0.05, 0.95),  # normal
	Vector4(0.96, 0.012, 0.075, 0.9),  # baix i fort
	Vector4(0.99, 0.01, 0.13, 1.0),  # panxut
	Vector4(1.04, 0.024, 0.1, 0.95),  # gran
	Vector4(1.01, -0.005, 0.02, 0.6),  # atlètic
	Vector4(0.95, -0.009, 0.04, 1.0),  # baix i prim
]

## Recursos compartits entre tots els jugadors (textura de dades, materials, malles).
static var _cache := {}

var is_gk := false
## Alçada respecte al model (escala del cos).
var height := 1.0
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var tree: AnimationTree
var posture: PostureModifier3D
## IK dels braços (les mans al pal) i de les cames (els peus a terra amb els genolls
## flexionats).
var ik: TwoBoneIK3D
var leg_ik: TwoBoneIK3D
var grip: GripModifier3D
## El pal i on l'agafen les mans (modificador de l'esquelet).
var placer: StickPlacer
var stick: MeshInstance3D
## Objectius de la IK dels braços: canells [esquerre, dret] i colzes.
var grips: Array[Marker3D] = []
## Postura de joc (0: dret, amb el pal aixecat; 1: ajupit, amb el pal a terra), suavitzada.
## −1 fins al primer fotograma.
var low := -1.0

var _body: Node3D
var _action: AnimationNodeAnimation
var _action_left := 0.0
var _last_stun := 0.0


func setup(p: Player, def: TeamData) -> void:
	is_gk = p.is_gk
	_body = BODY_SCENE.instantiate()
	_body.name = "Cos"
	_body.rotation.y = PI
	add_child(_body)
	skeleton = _body.get_node("Armature/Skeleton3D")
	body_mesh = skeleton.get_node("SuperHero_Male")
	body_mesh.material_override = _kit_material(def, is_gk)
	body_mesh.set_instance_shader_parameter("skin_tone", skin_tone(Color(Constants.SKINS[p.skin])))
	body_mesh.set_instance_shader_parameter("number", p.num)
	var b := build_of(p)
	height = b.x
	_body.scale = Vector3.ONE * height
	body_mesh.set_instance_shader_parameter("girth", b.y)
	body_mesh.set_instance_shader_parameter("belly", b.z)
	body_mesh.set_instance_shader_parameter("soft", b.w)
	var hair := Color(Constants.HAIRS[p.hair])
	var brows := skeleton.get_node_or_null("Eyebrows") as MeshInstance3D
	if brows:
		brows.material_override = _hair_material(_hair_parts(HAIR_SCENES[0])[2])
		brows.set_instance_shader_parameter("hair_color", hair)
	if is_gk:
		_gk_gear(def)
	else:
		_attach_shoes(p)
		var style := HAIRSTYLE[p.hs % HAIRSTYLE.size()]
		if style >= 0:
			_attach_hair(HAIR_SCENES[style], hair)
		if has_beard(p):
			_attach_hair(BEARD_SCENE, hair)
	_build_stick(def)
	_build_animation()
	_build_ik()


## Complexió de `p` (una de BUILDS, sempre la mateixa per a cada jugador, i l'alçada una
## mica diferent dins de cada complexió): [alçada, gruix, panxa, músculs llisos].
static func build_of(p: Player) -> Vector4:
	var b := BUILDS[(p.num * 3 + p.team.idx * 2) % BUILDS.size()]
	b.x += ((p.num * 7 + p.team.idx) % 5 - 2) * 0.012
	return b


## Dels Papis, quatre de cada deu porten barba (sempre els mateixos).
static func has_beard(p: Player) -> bool:
	return (p.num * 7 + p.team.idx * 3) % 10 < 4


## De 0 (pell clara) a 1 (fosca), per barrejar les dues textures del model.
static func skin_tone(c: Color) -> float:
	return clampf((0.82 - c.get_luminance()) / 0.42, 0.0, 1.0)


# --- Animació --------------------------------------------------------------------------


func _build_animation() -> void:
	tree = AnimationTree.new()
	tree.name = "Animacio"
	_body.add_child(tree)
	tree.root_node = NodePath("..")
	tree.add_animation_library(&"", ANIMS)
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 12.0
	loco.sync = true
	for g in GAIT:
		var an := AnimationNodeAnimation.new()
		an.animation = g
		an.use_custom_timeline = true
		an.timeline_length = 1.0
		an.stretch_time_scale = true
		an.loop_mode = Animation.LOOP_LINEAR
		loco.add_blend_point(an, _gs(g), -1, StringName(g))
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"idle"
	var bt := AnimationNodeBlendTree.new()
	bt.add_node(&"loco", loco)
	bt.add_node(&"rate", AnimationNodeTimeScale.new())
	bt.add_node(&"idle", idle)
	bt.add_node(&"move", AnimationNodeBlend2.new())
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.12
	shot.fadeout_time = 0.25
	bt.add_node(&"shot", shot)
	_action = AnimationNodeAnimation.new()
	_action.animation = &"celebrate"
	bt.add_node(&"action", _action)
	bt.connect_node(&"rate", 0, &"loco")
	bt.connect_node(&"move", 0, &"idle")
	bt.connect_node(&"move", 1, &"rate")
	bt.connect_node(&"shot", 0, &"move")
	bt.connect_node(&"shot", 1, &"action")
	bt.connect_node(&"output", 0, &"shot")
	tree.tree_root = bt
	tree.active = true


## Velocitat de terra d'una animació de córrer (m/s), mesurada en convertir-la.
static func _gs(anim: String) -> float:
	return float(ANIMS.get_animation(anim).get_meta(&"ground_speed", 1.0))


## Passa (metres per cicle) a la velocitat `v`, interpolada com la mescla de l'espai 1D.
static func stride_at(v: float) -> float:
	var g0 := GAIT[0]
	if v <= _gs(g0):
		return float(ANIMS.get_animation(g0).get_meta(&"stride", 1.0))
	for i in GAIT.size() - 1:
		var a := GAIT[i]
		var b := GAIT[i + 1]
		if v <= _gs(b):
			var w := (v - _gs(a)) / (_gs(b) - _gs(a))
			return lerpf(
				float(ANIMS.get_animation(a).get_meta(&"stride")),
				float(ANIMS.get_animation(b).get_meta(&"stride")),
				w
			)
	return float(ANIMS.get_animation(GAIT[-1]).get_meta(&"stride", 1.0))


## Cicles per segon de la locomoció a la velocitat `v` (m/s). Per sota de caminar, es
## manté un ritme mínim (els passets mentre es barreja amb el repòs).
static func gait_rate(v: float) -> float:
	var walk := _gs(GAIT[0])
	return maxf(v, walk * 0.6) / stride_at(v)


## Un fotograma: `speed` és la velocitat del jugador a la vista (m/s); `ball`, on es veu
## la pilota (global) si la porta aquest jugador (si no, Vector3.INF); i `engaged`, si és
## a la jugada (MatchView.engagement(): 1, ajupit i amb el pal a terra; 0, dret).
func animate(p: Player, speed: float, delta: float, ball := Vector3.INF, engaged := 1.0) -> void:
	if low < 0.0 or delta <= 0.0:
		low = engaged
	else:
		low = lerpf(low, engaged, 1.0 - exp(-delta * 5.0))
	# Les animacions són del model a mida real: un jugador més alt fa la passa més llarga.
	speed /= height
	tree.set(&"parameters/loco/blend_position", speed)
	tree.set(&"parameters/rate/scale", gait_rate(speed))
	tree.set(&"parameters/move/blend_amount", smoothstep(0.15, _gs(GAIT[0]), speed))
	if p.stun > 0.3 and _last_stun <= 0.0:
		trigger(&"hit")
	_last_stun = p.stun
	_action_left -= delta
	var free := _action_left > 0.0
	ik.influence = move_toward(ik.influence, 0.0 if free else 1.0, delta * 6.0)
	# Ajupit (a la jugada) o més dret (lluny), segons `low`. Les animacions de córrer ja
	# porten el cos endavant: com més de pressa, menys postura hi afegim.
	var run := clampf(speed / 6.0, 0.0, 1.0)
	# A la jugada, també corrent: amb la pilota a 72 cm, si no, les mans no arriben al pal.
	var lean := lerpf(0.25, 0.12, run) if is_gk else lerpf(0.32, 0.28, run)
	var hip := lerpf(0.3, 0.12, run) if is_gk else lerpf(0.6, 0.45, run)
	var drop := lerpf(0.2, 0.08, run) if is_gk else lerpf(0.24, 0.2, run)
	var twist := 0.2
	var roll := lerpf(0.25, 0.1, run)
	lean = lerpf(lerpf(0.1, 0.04, run), lean, low)
	hip = lerpf(lerpf(0.1, 0.04, run), hip, low)
	drop = lerpf(lerpf(0.03, 0.0, run), drop, low)
	twist = lerpf(0.08, twist, low)
	roll = lerpf(lerpf(0.06, 0.03, run), roll, low)
	var k := 1.0 - exp(-delta * 8.0)
	posture.lean = lerpf(posture.lean, 0.0 if free else lean, k)
	posture.hip = lerpf(posture.hip, 0.0 if free else hip, k)
	posture.drop = lerpf(posture.drop, 0.0 if free else drop, k)
	# El tronc gira una mica cap a l'esquerra i baixa l'espatlla dreta, cap al pal.
	posture.twist = lerpf(posture.twist, 0.0 if free else twist, k)
	posture.roll = lerpf(posture.roll, 0.0 if free else roll, k)
	# El pal es col·loca en actualitzar l'esquelet (StickPlacer), amb la postura ja feta.
	placer.args = [p.swing, ik.influence, ball, delta]


## Partit nou (es reaprofita el jugador): talla l'acció que feia.
func reset() -> void:
	tree.set(&"parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	placer.reset()
	low = -1.0
	_action_left = 0.0
	_last_stun = 0.0
	ik.influence = 1.0


## Acció d'una sola vegada (celebrar, protestar, trontollar...). Si `hands_free`, les mans
## deixen el pal durant l'animació.
func trigger(action: StringName, hands_free: bool = true) -> void:
	if not ANIMS.has_animation(action):
		return
	_action.animation = action
	tree.set(&"parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if hands_free:
		_action_left = ANIMS.get_animation(action).length


# --- Pal i mans ------------------------------------------------------------------------


func _build_ik() -> void:
	posture = PostureModifier3D.new()
	posture.name = "Postura"
	skeleton.add_child(posture)
	# Cames: els peus on els deixa l'animació (ho fa la postura) i els genolls endavant.
	var feet: Array[Node3D] = []
	for i in 4:
		var m := Marker3D.new()
		m.name = ["PeuEsquerre", "PeuDret", "GenollEsquerre", "GenollDret"][i]
		add_child(m)
		feet.append(m)
	feet[2].position = Vector3(-0.15, 0.5, -1.0)
	feet[3].position = Vector3(0.15, 0.5, -1.0)
	posture.foot_targets = [feet[0], feet[1]]
	leg_ik = TwoBoneIK3D.new()
	leg_ik.name = "Cames"
	skeleton.add_child(leg_ik)
	leg_ik.setting_count = 2
	for i in 2:
		var s := "l" if i == 0 else "r"
		leg_ik.set_root_bone_name(i, "thigh_" + s)
		leg_ik.set_middle_bone_name(i, "calf_" + s)
		leg_ik.set_end_bone_name(i, "foot_" + s)
		leg_ik.set_target_node(i, leg_ik.get_path_to(feet[i]))
		leg_ik.set_pole_node(i, leg_ik.get_path_to(feet[i + 2]))
	placer = StickPlacer.new()
	placer.name = "ColocaPal"
	placer.rig = self
	placer.stick = stick
	skeleton.add_child(placer)
	for i in 4:
		var m := Marker3D.new()
		m.name = ["MaEsquerra", "MaDreta", "ColzeEsquerre", "ColzeDret"][i]
		add_child(m)
		grips.append(m)
	grips[2].position = Vector3(-0.75, 0.7, 0.25)
	grips[3].position = Vector3(0.75, 0.6, 0.15)
	ik = TwoBoneIK3D.new()
	ik.name = "Mans"
	skeleton.add_child(ik)
	ik.setting_count = 2
	for i in 2:
		var s := "l" if i == 0 else "r"
		ik.set_root_bone_name(i, "upperarm_" + s)
		ik.set_middle_bone_name(i, "lowerarm_" + s)
		ik.set_end_bone_name(i, "hand_" + s)
		ik.set_target_node(i, ik.get_path_to(grips[i]))
		ik.set_pole_node(i, ik.get_path_to(grips[i + 2]))
	grip = GripModifier3D.new()
	grip.name = "Puny"
	grip.rig = self
	skeleton.add_child(grip)
	placer.grips = grips
	placer.grip = grip


func _build_stick(def: TeamData) -> void:
	stick = MeshInstance3D.new()
	stick.name = "Pal"
	stick.mesh = StickMesh.build(Color(def.color))
	add_child(stick)


# --- Equipació, cabells i porter ------------------------------------------------------


## Material de l'equipació (un per equip i un per porter).
func _kit_material(def: TeamData, gk: bool) -> ShaderMaterial:
	var key := "kit:%s:%s" % [def.id, gk]
	if _cache.has(key):
		return _cache[key]
	if not _cache.has("vdata"):
		_cache["vdata"] = KitMesh.data_texture(body_mesh.mesh, body_mesh.skin, skeleton)
		_cache["vshape"] = KitMesh.shape_texture(body_mesh.mesh)
		_cache["landmarks"] = KitMesh.landmarks(skeleton)
	var lm: Dictionary = _cache["landmarks"]
	var kit: Dictionary = def.gk_kit if gk else def.kit
	var m := ShaderMaterial.new()
	m.shader = KIT_SHADER
	m.set_shader_parameter("vdata", _cache["vdata"])
	m.set_shader_parameter("vshape", _cache["vshape"])
	m.set_shader_parameter("skin_light", load(TEX % "T_Superhero_Male_Light"))
	m.set_shader_parameter("skin_dark", load(TEX % "T_Superhero_Male_Dark"))
	m.set_shader_parameter("normal_tex", load(TEX % "T_Superhero_Male_Normal"))
	m.set_shader_parameter("digits", load(DIGITS))
	for h: String in lm:
		m.set_shader_parameter(h, lm[h])
	var style := {"iluro": 0, "polo": 1}.get(kit.get("style", ""), 2) as int
	m.set_shader_parameter("style", style)
	m.set_shader_parameter("shirt", Color(kit["shirt"]))
	m.set_shader_parameter("shirt2", Color(kit["shirt2"]))
	m.set_shader_parameter("band", Color(kit.get("band", kit["shirt2"])))
	m.set_shader_parameter("collar", Color(kit.get("collar", kit["shirt2"])))
	m.set_shader_parameter("shorts", Color(kit["shorts"]))
	m.set_shader_parameter("socks", Color(kit["socks"]))
	# El peu de sota les sabatilles (o les xuteres) va del color del mitjó: si en surt
	# un tros pel coll de la sabatilla, no es nota.
	m.set_shader_parameter("shoes", Color(kit["socks"]))
	m.set_shader_parameter("gloves", Color(kit.get("pads", "#f2f2ef")))
	m.set_shader_parameter("num_color", Color(kit["num"]))
	_cache[key] = m
	return m


## Malla, pell i textura d'un pentinat (es carrega una sola vegada).
static func _hair_parts(path: String) -> Array:
	var key := "hair:" + path
	if not _cache.has(key):
		var scene: Node = (load(path) as PackedScene).instantiate()
		var mi := scene.find_child("*", true, false) as MeshInstance3D
		for n in scene.find_children("*", "MeshInstance3D", true, false):
			mi = n
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		_cache[key] = [mi.mesh, mi.skin, mat.albedo_texture if mat else null]
		scene.free()
	return _cache[key]


static func _hair_material(tex: Texture2D) -> ShaderMaterial:
	var key := "hairmat:%s" % (tex.resource_path if tex else "")
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = HAIR_SHADER
		m.set_shader_parameter("tex", tex)
		_cache[key] = m
	return _cache[key]


func _attach_hair(path: String, color: Color) -> void:
	var parts := _hair_parts(path)
	var mi := MeshInstance3D.new()
	mi.name = path.get_file().get_basename()
	mi.mesh = parts[0]
	mi.skin = parts[1]
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.material_override = _hair_material(parts[2])
	mi.set_instance_shader_parameter("hair_color", color)


## Sabatilles (ShoeMesh): es mouen amb els ossos del peu, com el cos, i cada jugador les
## porta d'uns colors. No fan ombra (ja la fa el peu de sota).
func _attach_shoes(p: Player) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Sabatilles"
	mi.mesh = ShoeMesh.build(body_mesh.skin, skeleton)
	mi.skin = body_mesh.skin
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	var c := ShoeMesh.colors_for(p)
	mi.set_instance_shader_parameter("upper", c[0])
	mi.set_instance_shader_parameter("accent", c[1])
	mi.set_instance_shader_parameter("sole", c[2])


## Casc amb reixa, guardes, xuteres i guants del porter (GkGear), enganxats als ossos.
## Els ribets i les franges són del color de la samarreta que més contrasta.
func _gk_gear(def: TeamData) -> void:
	var gk: Dictionary = def.gk_kit
	var pads := Color(gk["pads"])
	var shell := Color(gk["helmet"])
	var kit: Array[Color] = [Color(gk["shirt"]), Color(gk["shirt2"])]
	var accent := GkGear.contrast(pads, kit)
	_gear("Head", GkGear.helmet(shell, GkGear.contrast(shell, kit), pads))
	for side: String in ["l", "r"]:
		var sgn := 1.0 if side == "l" else -1.0
		_gear("calf_" + side, GkGear.leg_guard(sgn, pads, accent))
		_gear("foot_" + side, GkGear.kicker(sgn, pads, accent))
		var hand: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side)).origin
		# Mà dreta, la que porta el pal; l'esquerra, el protector gran.
		var half := Vector3(0.085, 0.065, 0.065) if side == "r" else Vector3(0.06, 0.11, 0.1)
		_gear(
			"hand_" + side,
			GkGear.glove(half, pads),
			Transform3D(Basis(), hand + Vector3(sgn * 0.07, 0, 0))
		)


## Enganxa `mesh` (feta a l'espai del model en repòs, posada amb `model_xf`) a l'os `bone`.
func _gear(bone: String, mesh: Mesh, model_xf := Transform3D.IDENTITY) -> void:
	var b := skeleton.find_bone(bone)
	var att := BoneAttachment3D.new()
	att.name = "Equip_" + bone
	skeleton.add_child(att)
	att.bone_name = bone
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = skeleton.get_bone_global_rest(b).affine_inverse() * model_xf
	att.add_child(mi)
