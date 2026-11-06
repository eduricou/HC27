## Jugador amb esquelet i animacions (fase 4): el cos base de Quaternius (CC0) amb
## l'equipació pintada (KitMesh i shaders/player_kit.gdshader), cabells i barba, l'equip
## del porter, el pal i les animacions de la UAL passades a aquest esquelet
## (tools/build_player_anims.gd). Les dues mans agafen el pal amb IK (TwoBoneIK3D), i la
## pala del pal és sempre al punt de control de la simulació (stickPt), de manera que el
## contacte amb la pilota quadra. Decisions: docs/decisions/0007.
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
const SHOES := Color("17191c")

## Pal: llargada (de la pala a dalt) i punt de control en repòs. ref: stickPt(), stickWorld()
const STICK_LEN := 0.97
const STICK_F := 0.72
const STICK_SIDE := 0.3
## On va la mà de dalt (esquerra) quan no hi ha cop, en coordenades locals.
const TOP_HAND := Vector3(-0.05, 1.0, -0.38)

## Locomoció: caminar, córrer i esprintar es mesclen segons la velocitat, sincronitzats
## (els tres cicles estirats a 1 s i començant amb el peu esquerre a terra; vegeu
## tools/build_player_anims.gd). El ritme, en cicles per segon, és la velocitat dividida
## per la passa: així el peu de suport va enrere tan de pressa com avança el jugador i no
## rellisca. El repòs es barreja a part, a velocitats de caminar o menys.
## Arbre: output ← shot (OneShot: action) ← move (Blend2: idle | rate ← loco).
const GAIT: Array[String] = ["walk", "jog", "sprint"]

## Recursos compartits entre tots els jugadors (textura de dades, materials, malles).
static var _cache := {}

var is_gk := false
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var tree: AnimationTree
var posture: PostureModifier3D
## IK dels braços (les mans al pal) i de les cames (els peus a terra amb els genolls
## flexionats).
var ik: TwoBoneIK3D
var leg_ik: TwoBoneIK3D
var stick: MeshInstance3D
## Posició de la pala i de les mans (coordenades locals), per a les proves.
var blade := Vector3.ZERO
var grips: Array[Marker3D] = []

var _body: Node3D
var _action: AnimationNodeAnimation
var _action_left := 0.0
var _last_stun := 0.0
var _hand_r := -1


func setup(p: Player, def: TeamData) -> void:
	is_gk = p.is_gk
	_body = BODY_SCENE.instantiate()
	_body.name = "Cos"
	_body.rotation.y = PI
	add_child(_body)
	skeleton = _body.get_node("Armature/Skeleton3D")
	_hand_r = skeleton.find_bone("hand_r")
	body_mesh = skeleton.get_node("SuperHero_Male")
	body_mesh.material_override = _kit_material(def, is_gk)
	body_mesh.set_instance_shader_parameter("skin_tone", skin_tone(Color(Constants.SKINS[p.skin])))
	body_mesh.set_instance_shader_parameter("number", p.num)
	var hair := Color(Constants.HAIRS[p.hair])
	var brows := skeleton.get_node_or_null("Eyebrows") as MeshInstance3D
	if brows:
		brows.material_override = _hair_material(_hair_parts(HAIR_SCENES[0])[2])
		brows.set_instance_shader_parameter("hair_color", hair)
	if is_gk:
		_gk_gear(def)
	else:
		var style := HAIRSTYLE[p.hs % HAIRSTYLE.size()]
		if style >= 0:
			_attach_hair(HAIR_SCENES[style], hair)
		if has_beard(p):
			_attach_hair(BEARD_SCENE, hair)
	_build_stick(def)
	_build_animation()
	_build_ik()


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


## Un fotograma: `speed` és la velocitat del jugador a la vista (m/s).
func animate(p: Player, speed: float, delta: float) -> void:
	tree.set(&"parameters/loco/blend_position", speed)
	tree.set(&"parameters/rate/scale", gait_rate(speed))
	tree.set(&"parameters/move/blend_amount", smoothstep(0.15, _gs(GAIT[0]), speed))
	if p.stun > 0.3 and _last_stun <= 0.0:
		trigger(&"hit")
	_last_stun = p.stun
	_action_left -= delta
	var free := _action_left > 0.0
	ik.influence = move_toward(ik.influence, 0.0 if free else 1.0, delta * 6.0)
	# Les animacions de córrer ja porten el cos endavant: com més de pressa, menys postura
	# hi afegim.
	var run := clampf(speed / 6.0, 0.0, 1.0)
	var lean := lerpf(0.25, 0.12, run) if is_gk else lerpf(0.32, 0.1, run)
	var hip := lerpf(0.3, 0.12, run) if is_gk else lerpf(0.5, 0.12, run)
	var drop := lerpf(0.2, 0.08, run) if is_gk else lerpf(0.17, 0.03, run)
	var k := 1.0 - exp(-delta * 8.0)
	posture.lean = lerpf(posture.lean, 0.0 if free else lean, k)
	posture.hip = lerpf(posture.hip, 0.0 if free else hip, k)
	posture.drop = lerpf(posture.drop, 0.0 if free else drop, k)
	# El tronc gira una mica cap a l'esquerra i baixa l'espatlla dreta, cap al pal.
	posture.twist = lerpf(posture.twist, 0.0 if free else 0.2, k)
	posture.roll = lerpf(posture.roll, 0.0 if free else lerpf(0.25, 0.1, run), k)
	_place_stick(p.swing, ik.influence)


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


## Pala al punt de control de la simulació (ref: stickWorld(): amb el cop, el pal va enrere,
## a la dreta i amunt) i el mànec cap a la mà de dalt. Si les mans són lliures, el pal va
## amb la mà dreta.
func _place_stick(swing: float, hold: float) -> void:
	var k := sin((swing / 0.25) * PI) if swing > 0.0 else 0.0
	var f := STICK_F - k * 0.55
	var sv := STICK_SIDE + k * 0.35
	blade = Vector3(sv, k * 0.75, -f)
	var top_want := TOP_HAND + Vector3(0.25, 0.35, 0.2) * k
	var dir := (top_want - blade).normalized()
	var held := _stick_basis(dir)
	var top := blade + dir * STICK_LEN
	grips[0].position = top - dir * 0.04
	grips[1].position = blade + dir * (STICK_LEN * 0.88)
	var xf := Transform3D(held, blade)
	if hold < 0.999:
		# Amb la mà dreta: el pal amunt, agafat per dalt.
		var hand := _body.transform * skeleton.get_bone_global_pose(_hand_r)
		var up := Vector3(0.15, 1.0, 0.1).normalized()
		var free_xf := Transform3D(_stick_basis(-up), hand.origin + up * (STICK_LEN - 0.08))
		xf = free_xf.interpolate_with(xf, hold)
	stick.transform = xf


## Base del pal: Y pel mànec (de la pala amunt) i Z cap endavant (on mira la pala).
static func _stick_basis(dir: Vector3) -> Basis:
	var fwd := Vector3(0.0, 0.0, -1.0)
	fwd = (fwd - dir * fwd.dot(dir)).normalized()
	if fwd.length_squared() < 0.5:
		fwd = Vector3(1.0, 0.0, 0.0)
	return Basis(dir.cross(fwd), dir, fwd)


func _build_stick(def: TeamData) -> void:
	stick = MeshInstance3D.new()
	stick.name = "Pal"
	stick.mesh = stick_mesh(Color(def.color))
	add_child(stick)


## Pal d'hoquei (origen a la pala, mànec cap a +Y, ganxo cap a +Z): mànec fosc, cinta
## blanca a baix, franja del color de l'equip i puny negre. ref: drawStick()
static func stick_mesh(team: Color) -> ArrayMesh:
	var key := "stick:" + team.to_html()
	if _cache.has(key):
		return _cache[key]
	var mesh := ArrayMesh.new()
	var dark := Color("1c1f23")
	# [mida, centre, gir al voltant de X, color]
	var parts := [
		[Vector3(0.032, 0.84, 0.024), Vector3(0, 0.55, 0), 0.0, dark],
		[Vector3(0.036, 0.16, 0.028), Vector3(0, 0.89, 0), 0.0, Color("0d0e10")],
		[Vector3(0.035, 0.12, 0.027), Vector3(0, 0.47, 0), 0.0, team],
		[Vector3(0.034, 0.08, 0.026), Vector3(0, 0.15, 0), 0.0, Color("e9ece6")],
		[Vector3(0.03, 0.14, 0.024), Vector3(0, 0.07, 0.025), 0.4, Color("e9ece6")],
		[Vector3(0.03, 0.035, 0.11), Vector3(0, 0.02, 0.08), 0.0, dark],
	]
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		var arrays := box.get_mesh_arrays()
		var xf := Transform3D(Basis(Vector3.RIGHT, part[2]), part[1])
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in v.size():
			v[i] = xf * v[i]
			n[i] = xf.basis * n[i]
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TANGENT] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := StandardMaterial3D.new()
		m.albedo_color = part[3]
		m.roughness = 0.45
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	_cache[key] = mesh
	return mesh


# --- Equipació, cabells i porter ------------------------------------------------------


## Material de l'equipació (un per equip i un per porter).
func _kit_material(def: TeamData, gk: bool) -> ShaderMaterial:
	var key := "kit:%s:%s" % [def.id, gk]
	if _cache.has(key):
		return _cache[key]
	if not _cache.has("vdata"):
		_cache["vdata"] = KitMesh.data_texture(body_mesh.mesh, body_mesh.skin, skeleton)
		_cache["landmarks"] = KitMesh.landmarks(skeleton)
	var lm: Dictionary = _cache["landmarks"]
	var kit: Dictionary = def.gk_kit if gk else def.kit
	var m := ShaderMaterial.new()
	m.shader = KIT_SHADER
	m.set_shader_parameter("vdata", _cache["vdata"])
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
	m.set_shader_parameter("shoes", SHOES)
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


## Casc amb reixa, guardes, xuteres i guants del porter, enganxats als ossos.
func _gk_gear(def: TeamData) -> void:
	var gk: Dictionary = def.gk_kit
	var pads := _plain(Color(gk["pads"]))
	var helmet := _plain(Color(gk["helmet"]))
	var cage := _plain(Color("3a3f45"))
	var head: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin
	var sphere := SphereMesh.new()
	sphere.radius = 0.145
	sphere.height = 0.29
	_gear(
		"Head",
		sphere,
		Transform3D(Basis.from_scale(Vector3(1.0, 0.95, 1.12)), head + Vector3(0, 0.1, -0.005)),
		helmet
	)
	for i in 3:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.2, 0.012, 0.012)
		_gear("Head", bar, Transform3D(Basis(), head + Vector3(0, 0.05 + i * 0.04, 0.15)), cage)
	for side: String in ["l", "r"]:
		var knee: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("calf_" + side)).origin
		var ankle: Vector3 = (
			skeleton.get_bone_global_rest(skeleton.find_bone("foot_" + side)).origin
		)
		var pad := BoxMesh.new()
		pad.size = Vector3(0.2, knee.y - ankle.y + 0.14, 0.14)
		_gear(
			"calf_" + side,
			pad,
			Transform3D(Basis(), (knee + ankle) * 0.5 + Vector3(0, 0.04, 0.07)),
			pads
		)
		var kicker := BoxMesh.new()
		kicker.size = Vector3(0.16, 0.12, 0.34)
		_gear("foot_" + side, kicker, Transform3D(Basis(), ankle + Vector3(0, -0.04, 0.09)), pads)
		var hand: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side)).origin
		var glove := BoxMesh.new()
		glove.size = Vector3(0.17, 0.13, 0.13) if side == "r" else Vector3(0.12, 0.22, 0.2)
		var out := -1.0 if side == "r" else 1.0
		_gear("hand_" + side, glove, Transform3D(Basis(), hand + Vector3(out * 0.07, 0, 0)), pads)


func _gear(bone: String, mesh: Mesh, model_xf: Transform3D, mat: Material) -> void:
	var b := skeleton.find_bone(bone)
	var att := BoneAttachment3D.new()
	att.name = "Equip_" + bone
	skeleton.add_child(att)
	att.bone_name = bone
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = skeleton.get_bone_global_rest(b).affine_inverse() * model_xf
	att.add_child(mi)


static func _plain(c: Color) -> StandardMaterial3D:
	var key := "plain:" + c.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.5
		_cache[key] = m
	return _cache[key]
