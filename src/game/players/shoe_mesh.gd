## Sabatilles d'hoquei fetes amb codi, per sobre del peu del model (que és nu i pintat):
## sola gruixuda amb el taló més alt i una mica de punta aixecada, i empenya que tapa el peu
## fins al turmell. Es mouen amb l'esquelet com el peu: la punta amb l'os dels dits i el
## coll una mica amb la cama (els pesos imiten els del model).
## Una sola malla per a tots els jugadors: els colors els posa cada jugador (instance
## uniform de shaders/shoe.gdshader) i els dibuixos (ratlles, cordons, taló) els fa el
## shader a partir de la posició dins la sabatilla, que va al color del vèrtex:
## r = costat (0,5 al mig, 1 a fora), g = del taló a la punta, b = alçada, a = 1 a la sola.
class_name ShoeMesh
extends RefCounted

const SHADER := preload("res://shaders/shoe.gdshader")
## Perfil de la sabatilla esquerra (metres, espai del model en repòs, mirant cap a +Z):
## [z, centre x, mitja amplada, alçada de dalt]. S'ha fet a partir del peu del model, amb
## uns quants mil·límetres de marge.
const PROFILE: Array[Vector4] = [
	Vector4(-0.158, 0.124, 0.034, 0.108),
	Vector4(-0.13, 0.125, 0.041, 0.114),
	Vector4(-0.08, 0.122, 0.047, 0.118),
	Vector4(-0.05, 0.126, 0.049, 0.116),
	Vector4(-0.02, 0.13, 0.053, 0.099),
	Vector4(0.0, 0.132, 0.058, 0.083),
	Vector4(0.03, 0.1315, 0.064, 0.07),
	Vector4(0.06, 0.131, 0.065, 0.06),
	Vector4(0.09, 0.126, 0.059, 0.05),
	Vector4(0.115, 0.121, 0.049, 0.043),
	Vector4(0.146, 0.118, 0.036, 0.036),
]
## Sota de la sola i dalt de la sola (al taló i a la punta).
const SOLE_BOT := -0.014
const SOLE_TOP := Vector2(0.017, 0.009)
## Fins on s'arrodoneixen el taló i la punta.
const HEEL_R := 0.03
const TOE_R := 0.05
## Colors [empenya, ratlles i cordons, sola], com les sabatilles d'hoquei de les botigues.
const PALETTE := [
	[Color("1c1d21"), Color("f2f2ef"), Color("26272b")],
	[Color("f0f0ec"), Color("1d2b5c"), Color("e8e8e4")],
	[Color("d4ec3a"), Color("15161a"), Color("f0f0ec")],
	[Color("2456c8"), Color("f4f4f0"), Color("eeeeea")],
	[Color("c8262f"), Color("f4f4f0"), Color("1c1d21")],
	[Color("f0559a"), Color("16171b"), Color("f0f0ec")],
	[Color("7c8088"), Color("ff7a1a"), Color("efefeb")],
	[Color("18191d"), Color("6af03c"), Color("202125")],
	[Color("f2f2ee"), Color("d0283a"), Color("c49a64")],
	[Color("1fb5b0"), Color("f6f6f2"), Color("f0f0ec")],
	[Color("ff8a1f"), Color("18191d"), Color("202125")],
	[Color("6a3fc4"), Color("f2d12a"), Color("f0f0ec")],
]

static var _cache := {}


## Els colors de les sabatilles de `p` [empenya, ratlles, sola]: sempre els mateixos per
## a cada jugador, i diferents per als companys d'equip (els dorsals van de l'1 a l'11).
static func colors_for(p: Player) -> PackedColorArray:
	return PackedColorArray(PALETTE[(p.num * 5 + p.team.idx * 7) % PALETTE.size()])


## Perfil interpolat a `z`: (centre x, mitja amplada, alçada de dalt), del peu esquerre.
static func profile_at(z: float) -> Vector3:
	var a := PROFILE[0]
	for b in PROFILE:
		if z <= b.x:
			var f := 0.0 if b.x == a.x else clampf((z - a.x) / (b.x - a.x), 0.0, 1.0)
			var v := a.lerp(b, f)
			return Vector3(v.y, v.z, v.w)
		a = b
	return Vector3(a.y, a.z, a.w)


## Les dues sabatilles, que es mouen amb els ossos del cos (`skin`, l'esquelet `sk`).
static func build(skin: Skin, sk: Skeleton3D) -> ArrayMesh:
	if _cache.has(skin):
		return _cache[skin]
	var part := MeshPart.new()
	for side: float in [1.0, -1.0]:
		var start := part.verts.size()
		_sole(part, side)
		_upper(part, side)
		var s := "l" if side > 0.0 else "r"
		var binds := PackedInt32Array()
		for b in ["foot_", "ball_", "calf_"]:
			binds.append(_bind(skin, sk, b + s))
		for i in range(start, part.verts.size()):
			var w := weights_at(part.verts[i])
			part.bones.append_array([binds[0], binds[1], binds[2], binds[0]])
			part.weights.append_array([w.x, w.y, w.z, 0.0])
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var mesh := ArrayMesh.new()
	part.add_to(mesh, mat)
	_cache[skin] = mesh
	return mesh


## Pesos (peu, dits, cama) d'un punt de la sabatilla: la punta es doblega amb els dits i
## el coll del darrere segueix una mica la cama, com el peu del model.
static func weights_at(p: Vector3) -> Vector3:
	var toes := smoothstep(0.03, 0.075, p.z)
	var leg := clampf((p.y - 0.03) / 0.08, 0.0, 1.0) * 0.85 * (1.0 - smoothstep(-0.04, 0.0, p.z))
	return Vector3(1.0 - toes - leg, toes, leg)


## Sola: una llosa de cantells rodons, una mica més ampla i llarga que l'empenya.
static func _sole(part: MeshPart, side: float) -> void:
	var z0: float = PROFILE[0].x - 0.004
	var z1: float = PROFILE[-1].x + 0.003
	_loft(part, side, z0, z1, 22, 10, true)


## Empenya: del dins de la sola fins a dalt del peu.
static func _upper(part: MeshPart, side: float) -> void:
	_loft(part, side, PROFILE[0].x, PROFILE[-1].x, 26, 14, false)


static func _loft(
	part: MeshPart, side: float, z0: float, z1: float, n_rows: int, around: int, sole: bool
) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for i in n_rows + 1:
		var t := float(i) / n_rows
		var z := lerpf(z0, z1, t)
		var pr := profile_at(z)
		var k := MeshPart.round_ends(z - z0, z1 - z, HEEL_R, TOE_R, 2.5)
		var bot := 0.004
		var top := pr.z
		var half_w := pr.y
		if sole:
			bot = SOLE_BOT + 0.008 * smoothstep(0.85, 1.0, t)
			top = lerpf(SOLE_TOP.x, SOLE_TOP.y, t)
			half_w += 0.005
		var center := Vector3(side * pr.x, (top + bot) * 0.5, z)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in around:
			var th := TAU * j / around
			var c := cos(th)
			var dy := (top - bot) * 0.5 * MeshPart.spow(c, 0.7 if c >= 0.0 else 0.25)
			if sole:
				dy = (top - bot) * 0.5 * MeshPart.spow(c, 0.35)
			var dx := half_w * MeshPart.spow(sin(th), 0.6 if not sole else 0.4)
			var p := center + Vector3(dx, dy, 0.0) * k
			ring.append(p)
			var across := clampf(side * (p.x - side * pr.x) / half_w, -1.0, 1.0)
			var h := clampf((p.y - SOLE_BOT) / (0.12 - SOLE_BOT), 0.0, 1.0)
			rc.append(Color(0.5 + 0.5 * across, t, h, 1.0 if sole else 0.0))
		rows.append(ring)
		cols.append(rc)
		refs.append(center)
	part.grid(rows, cols, true, refs)


static func _bind(skin: Skin, sk: Skeleton3D, bone: String) -> int:
	for i in skin.get_bind_count():
		var n := String(skin.get_bind_name(i))
		if n == "":
			n = sk.get_bone_name(skin.get_bind_bone(i))
		if n == bone:
			return i
	push_error("Sabatilles: no trobo l'os %s a la pell" % bone)
	return 0
