## Públic dret en 3D, fet amb codi: cames, tronc, braços, coll i cap amb volum, amb el pes
## sobre una cama. Hi ha unes quantes siluetes (de mides i postures diferents: braços
## avall, mans a les butxaques o braços plegats) i els colors els posa cada persona.
## Per poder pintar-los al shader (shaders/spectator.gdshader), el color del vèrtex diu
## quina peça és: r = peça (PART_*), g = alçada relativa (0 als peus, 1 dalt del cap).
## Coordenades: Y amunt, mirant cap a +Z, els peus a l'origen.
class_name SpectatorMesh
extends RefCounted

enum Part { SKIN, HAIR, SHIRT, JACKET, TROUSERS, SHOES, SCARF }
enum Pose { ARMS_DOWN, POCKETS, CROSSED }

const SHADER := preload("res://shaders/spectator.gdshader")

static var _cache := {}


## Una silueta: `height` en metres, `bulk` (0 prim, 1 gros), `pose` i si porta bufanda.
static func build(height: float, bulk: float, pose: int, scarf: bool) -> ArrayMesh:
	var key := "%.2f:%.2f:%d:%s" % [height, bulk, pose, scarf]
	if _cache.has(key):
		return _cache[key]
	var k := height / 1.75
	var w := lerpf(0.92, 1.25, bulk)
	var part := MeshPart.new()
	var hip_y := 0.92 * k
	var chest_y := 1.3 * k
	var neck_y := 1.47 * k
	var head_y := 1.62 * k
	# Cames: la de la dreta, el pes; l'esquerra, una mica endavant i doblegada.
	for side: float in [-1.0, 1.0]:
		var x := side * 0.095 * w
		var foot := Vector3(x + side * 0.03, 0.0, 0.05 if side > 0.0 else 0.11)
		var knee := Vector3(x * 1.05, 0.5 * k, 0.02 if side > 0.0 else 0.06)
		var hip := Vector3(x, hip_y, 0.0)
		_limb(
			part,
			[foot + Vector3(0, 0.07, 0), knee, hip],
			[0.055 * w, 0.06 * w, 0.075 * w],
			Part.TROUSERS,
			height
		)
		_shoe(part, foot, side)
	# Tronc: de la pelvis a les espatlles, una mica més ample de pit (i de panxa, si és gros).
	var torso: Array[Vector4] = [
		Vector4(hip_y - 0.04 * k, 0.17 * w, 0.12 * w, 0.0),
		Vector4(hip_y + 0.12 * k, 0.17 * w, 0.13 * w + 0.05 * bulk, 0.02 + 0.03 * bulk),
		Vector4(chest_y - 0.05 * k, 0.19 * w, 0.125 * w + 0.03 * bulk, 0.015),
		Vector4(chest_y + 0.08 * k, 0.2 * w, 0.11 * w, 0.0),
		Vector4(neck_y - 0.06 * k, 0.15 * w, 0.085 * w, -0.01),
	]
	_trunk(part, torso, height)
	_limb(
		part,
		[Vector3(0, neck_y - 0.07 * k, -0.01), Vector3(0, neck_y + 0.04 * k, 0.0)],
		[0.055, 0.05],
		Part.SKIN,
		height
	)
	if scarf:
		_limb(
			part,
			[Vector3(0, neck_y - 0.06 * k, -0.01), Vector3(0, neck_y + 0.0, 0.0)],
			[0.085 * w, 0.075 * w],
			Part.SCARF,
			height
		)
	# Cap i cabell (una closca per sobre del cap, més enrere que endavant).
	var head := Vector3(0.0, head_y, 0.01)
	_ellipsoid(part, head, Vector3(0.085, 0.11, 0.1), Part.SKIN, height, -1.0)
	_ellipsoid(
		part, head + Vector3(0, 0.022, -0.012), Vector3(0.09, 0.1, 0.1), Part.HAIR, height, 0.1
	)
	# Braços.
	var sh_y := chest_y + 0.06 * k
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(side * 0.2 * w, sh_y, -0.01)
		var elbow: Vector3
		var hand: Vector3
		match pose:
			Pose.POCKETS:
				elbow = Vector3(side * 0.25 * w, sh_y - 0.3 * k, -0.04)
				hand = Vector3(side * 0.19 * w, hip_y - 0.04 * k, 0.04)
			Pose.CROSSED:
				elbow = Vector3(side * 0.22 * w, sh_y - 0.27 * k, 0.07)
				hand = Vector3(-side * 0.08 * w, sh_y - 0.2 * k, 0.15 * w)
			_:
				elbow = Vector3(side * 0.24 * w, sh_y - 0.29 * k, -0.03)
				hand = Vector3(side * 0.25 * w, sh_y - 0.56 * k, 0.03)
		_limb(part, [sh, elbow, hand], [0.06 * w, 0.05 * w, 0.042 * w], Part.JACKET, height)
		if pose == Pose.ARMS_DOWN:
			_ellipsoid(
				part,
				hand + Vector3(0, -0.06, 0),
				Vector3(0.04, 0.06, 0.035),
				Part.SKIN,
				height,
				-1.0
			)
	var mesh := ArrayMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	part.add_to(mesh, mat)
	_cache[key] = mesh
	return mesh


## Tub de seccions rodones de radis `radii` pels punts `pts`.
static func _limb(part: MeshPart, pts: Array, radii: Array, kind: int, height: float) -> void:
	var path := PackedVector3Array()
	for p: Vector3 in pts:
		path.append(p)
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var sides := 7
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.FORWARD if absf(t.z) < 0.8 else Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var v := t.cross(u)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in sides:
			var a := TAU * k / sides
			var p := path[i] + (u * cos(a) + v * sin(a)) * float(radii[i])
			ring.append(p)
			rc.append(_tag(kind, p.y, height))
		rows.append(ring)
		cols.append(rc)
	part.grid(rows, cols, true, path)
	# Tapes dels extrems.
	for e in [0, path.size() - 1]:
		var c := path[e]
		var ring := rows[e]
		for k in sides:
			var a := ring[k]
			var b := ring[(k + 1) % sides]
			var n := (a - c).cross(b - c)
			var out := c - path[1 if e == 0 else path.size() - 2]
			part.quad(c, a, b, c, _tag(kind, c.y, height), n if n.dot(out) > 0.0 else -n)


## Tronc: el·lipses a les alçades de `rings` (y, mitja amplada, mitja fondària, panxa).
static func _trunk(part: MeshPart, rings: Array[Vector4], height: float) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for r in rings:
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in 12:
			var a := TAU * k / 12.0
			var z := sin(a) * r.z
			if z > 0.0:
				z += r.w * sin(a)
			var p := Vector3(cos(a) * r.y, r.x, z)
			ring.append(p)
			rc.append(_tag(Part.JACKET if r.x > rings[0].x + 0.05 else Part.TROUSERS, p.y, height))
		rows.append(ring)
		cols.append(rc)
		refs.append(Vector3(0, r.x, 0))
	part.grid(rows, cols, true, refs)
	# Tapa de dalt (espatlles).
	var top := rows[-1]
	var c := Vector3(0, rings[-1].x + 0.02, 0)
	for k in 12:
		part.quad(c, top[k], top[(k + 1) % 12], c, _tag(Part.JACKET, c.y, height), Vector3.UP)


## El·lipsoide de radis `r`. Si `cut` > −1, només la part de sobre de `cut` (en fracció de
## l'alçada, de −1 a 1): el cabell.
static func _ellipsoid(
	part: MeshPart, c: Vector3, r: Vector3, kind: int, height: float, cut: float
) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	var n := 6
	for i in n + 1:
		var el := lerpf(PI * 0.5, asin(clampf(cut, -1.0, 1.0)), float(i) / n)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in 10:
			var a := TAU * k / 10.0
			var p := c + Vector3(cos(el) * cos(a) * r.x, sin(el) * r.y, cos(el) * sin(a) * r.z)
			ring.append(p)
			rc.append(_tag(kind, p.y, height))
		rows.append(ring)
		cols.append(rc)
		refs.append(c)
	part.grid(rows, cols, true, refs)


static func _shoe(part: MeshPart, foot: Vector3, side: float) -> void:
	var c := foot + Vector3(side * 0.005, 0.035, 0.05)
	_ellipsoid(part, c, Vector3(0.05, 0.04, 0.12), Part.SHOES, 1.75, -0.2)


static func _tag(kind: int, y: float, height: float) -> Color:
	return Color((kind + 0.5) / 8.0, clampf(y / height, 0.0, 1.0), 0.0, 1.0)
