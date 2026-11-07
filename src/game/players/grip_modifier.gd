## Mans al pal, després de la IK dels braços: gira cada mà com diu `hand_basis` (que
## calcula PlayerRig: la canya passa pel puny, amb el polze cap avall, cap al cap del pal,
## com al golf) i tanca els dits.
## Ossos de la mà (Quaternius): +Y cap als dits, +Z del dit petit a l'índex; el palmell
## mira cap a −X a la dreta i cap a +X a l'esquerra.
class_name GripModifier3D
extends SkeletonModifier3D

## On passa la canya respecte a l'os de la mà (metres): cap als dits i cap al palmell. Amb
## la flexió dels dits (radiants, de la base a la punta) i el gir del polze, les
## articulacions queden a uns 2,5 cm de l'eix de la canya, al voltant (ajustat amb una
## cerca sobre l'esquelet en repòs: l'error mitjà és de 5 mm als dits i 1 cm al polze).
const HOLE_FINGERS := 0.11
const HOLE_PALM := 0.035
const CURL: Array[float] = [0.8, 1.2, 1.2]
## Polze: gir de la base al voltant dels eixos X i Z de l'os (Z, amb el signe de la mà
## dreta) i flexió de la segona falange.
const THUMB_BASE := Vector2(0.8, 0.4)
const THUMB_CURL := 0.6
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky"]
const SIDES: Array[String] = ["l", "r"]

## El rig del jugador: `hand_basis` és en les seves coordenades.
var rig: Node3D
## Quant agafa el pal cada mà (0: lliure; 1: al pal). [esquerra, dreta]
var hold := PackedFloat32Array([1.0, 1.0])
## Orientació de cada mà quan agafa el pal.
var hand_basis: Array[Basis] = [Basis(), Basis()]

var _hands := PackedInt32Array()
## Per a cada mà: ossos dels dits i la rotació local que tenen amb el puny tancat.
var _bones: Array[PackedInt32Array] = []
var _closed: Array[Array] = []


## On queda la canya respecte a l'os de la mà `i` (0 esquerra, 1 dreta).
static func hole(i: int) -> Vector3:
	return Vector3(HOLE_PALM if i == 0 else -HOLE_PALM, HOLE_FINGERS, 0.0)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or rig == null:
		return
	if _hands.is_empty():
		_setup(sk)
	var to_skel := (sk.global_transform.affine_inverse() * rig.global_transform).basis
	for i in 2:
		var w := hold[i]
		if w <= 0.001:
			continue
		var hand := sk.get_bone_global_pose(_hands[i])
		var want := (to_skel * hand_basis[i]).orthonormalized()
		var cur := hand.basis.orthonormalized()
		sk.set_bone_global_pose(_hands[i], Transform3D(cur.slerp(want, w), hand.origin))
		for k in _bones[i].size():
			var b := _bones[i][k]
			var q: Quaternion = _closed[i][k]
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(q, w))


## Rotacions dels dits amb el puny tancat, a partir de la postura de repòs (en T, amb els
## palmells cap avall): cada falange es doblega cap al palmell.
func _setup(sk: Skeleton3D) -> void:
	for i in 2:
		var s := SIDES[i]
		_hands.append(sk.find_bone("hand_" + s))
		var bones := PackedInt32Array()
		var closed := []
		for f in FINGERS:
			for k in CURL.size():
				_add_curl(sk, "%s_%02d_%s" % [f, k + 1, s], CURL[k], bones, closed)
		var thumb := sk.find_bone("thumb_01_" + s)
		if thumb >= 0:
			var z := THUMB_BASE.y * (1.0 if s == "r" else -1.0)
			var rest := sk.get_bone_rest(thumb).basis
			bones.append(thumb)
			closed.append(
				(
					(rest * Basis(Vector3.RIGHT, THUMB_BASE.x) * Basis(Vector3.BACK, z))
					. get_rotation_quaternion()
				)
			)
		_add_curl(sk, "thumb_02_" + s, THUMB_CURL, bones, closed)
		_bones.append(bones)
		_closed.append(closed)


static func _add_curl(
	sk: Skeleton3D, bone: String, angle: float, bones: PackedInt32Array, closed: Array
) -> void:
	var b := sk.find_bone(bone)
	if b < 0:
		return
	var rest := sk.get_bone_global_rest(b).basis.orthonormalized()
	var palm := (rest.inverse() * Vector3.DOWN).normalized()
	var axis := Vector3.UP.cross(palm)
	if axis.length_squared() < 1e-6:
		return
	bones.append(b)
	var q := sk.get_bone_rest(b).basis.get_rotation_quaternion()
	closed.append(q * Quaternion(axis.normalized(), angle))
