## Postura d'hoquei, per sobre de l'animació (córrer, caminar...): genolls flexionats
## (la pelvis baixa i els peus es queden on els posa l'animació, amb la IK de les cames),
## el cos doblegat pels malucs i l'esquena inclinada endavant, amb l'espatlla del pal més
## baixa. Va abans de la IK de les cames i dels braços: deixa als marcadors `foot_targets`
## on han d'anar els peus. El model mira cap a +Z (la dreta del jugador és −X): inclinar
## endavant és girar al voltant de +X.
class_name PostureModifier3D
extends SkeletonModifier3D

## Inclinació endavant (radiants), repartida entre spine_01 i spine_02.
var lean := 0.2
## Gir del tronc (radiants, positiu cap a l'esquerra del jugador).
var twist := 0.0
## Inclinació lateral (radiants, positiu: l'espatlla dreta baixa).
var roll := 0.0
## Quant baixa la pelvis (metres): flexió de genolls.
var drop := 0.0
## Flexió dels malucs (radiants): tot el tronc endavant, des de la pelvis.
var hip := 0.0
## Marcadors on la IK de les cames ha de posar els peus (esquerre i dret).
var foot_targets: Array[Node3D] = []

var _spine := PackedInt32Array()
var _feet := PackedInt32Array()
var _pelvis := -1


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _spine.is_empty():
		_spine = PackedInt32Array([sk.find_bone("spine_01"), sk.find_bone("spine_02")])
		_feet = PackedInt32Array([sk.find_bone("foot_l"), sk.find_bone("foot_r")])
		_pelvis = sk.find_bone("pelvis")
	# Els peus, on els ha deixat l'animació (abans de baixar la pelvis).
	for i in mini(foot_targets.size(), _feet.size()):
		foot_targets[i].global_transform = sk.global_transform * sk.get_bone_global_pose(_feet[i])
	if _pelvis >= 0:
		if drop > 0.0:
			var pp := sk.get_bone_pose_position(_pelvis)
			sk.set_bone_pose_position(_pelvis, pp - Vector3(0.0, drop, 0.0))
		_rotate(sk, _pelvis, Basis(Vector3.RIGHT, hip))
	var r := (
		Basis(Vector3.UP, twist * 0.5)
		* Basis(Vector3.BACK, roll * 0.5)
		* Basis(Vector3.RIGHT, lean * 0.5)
	)
	for b in _spine:
		if b >= 0:
			_rotate(sk, b, r)


## Gira l'os b amb r (rotació en l'espai de l'esquelet, al voltant de l'origen de l'os).
static func _rotate(sk: Skeleton3D, b: int, r: Basis) -> void:
	var g := sk.get_bone_global_pose(b)
	var parent := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := pg.basis.orthonormalized().inverse() * (r * g.basis.orthonormalized())
	sk.set_bone_pose_rotation(b, local.get_rotation_quaternion())
