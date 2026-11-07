## El pal i on l'agafen les mans. És un modificador de l'esquelet que va després de la
## postura i abans de la IK dels braços: així fa servir les espatlles d'aquest mateix
## fotograma (corrent, pugen i baixen fins a 25 cm a cada passa).
## - La pilota toca la cara del fons del ganxo al punt de control de la simulació
##   (stickPt; amb el cop, stickWorld(): enrere, a la dreta i amunt). Quan el jugador porta
##   la pilota, el punt de control és la pilota que es veu.
## - La canya va cap a TOP_HAND i el cap reposa a terra sense clavar-s'hi. La mà esquerra
##   agafa dalt de tot i la dreta, més avall (amb el cop, s'hi acosta). Si els braços no hi
##   arriben, el pal s'inclina cap a les espatlles.
## - Lluny de la jugada (PlayerRig.low < 1), el pal va aixecat. Si les mans són lliures
##   (celebrar, protestar...), el pal va amb la mà dreta.
## Deixa els objectius de la IK (`grips`) i l'orientació de les mans (GripModifier3D).
## Coordenades: les locals del jugador (PlayerRig).
class_name StickPlacer
extends SkeletonModifier3D

## Punt de control del pal en repòs (on va la pilota quan es porta). ref: stickPt()
const STICK_F := 0.72
const STICK_SIDE := 0.3
## Cap on va la part de dalt del pal (la mà esquerra) quan no hi ha cop, en coordenades
## locals, a l'alçada del model.
const TOP_HAND := Vector3(0.04, 1.0, -0.4)
## Lluny de la jugada, el jugador va més dret i porta el pal aixecat: la pala a aquesta
## alçada, davant i a la dreta, i la canya cap a TOP_HAND_UP.
const CARRY_BLADE := Vector3(0.3, 0.3, -0.58)
const TOP_HAND_UP := Vector3(-0.02, 1.02, -0.26)
## Fins on arriba el braç, de l'espatlla al puny (metres, a l'alçada del model; gairebé
## estirat). La mà dreta baixa per la canya fins on li arriba, però no més avall que
## RIGHT_LOW metres del taló.
const ARM_REACH := 0.52
const RIGHT_LOW := 0.42

var rig: PlayerRig
var stick: MeshInstance3D
var grip: GripModifier3D
## Objectius de la IK: on han d'anar els canells [esquerre, dret] i on van els colzes.
var grips: Array[Marker3D] = []
## On va el centre de la pilota quan el pal la porta, i els punts del pal on agafen les
## mans (coordenades locals; també per a les proves).
var blade := Vector3.ZERO
var grip_points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## El que cal per a aquest fotograma (PlayerRig.animate): [swing, hold, pilota, delta].
var args: Array = [0.0, 1.0, Vector3.INF, 0.0]

## Quant s'aparta el pal del punt de control de la simulació per anar a la pilota que es
## veu (suavitzat).
var _ball_off := Vector3.ZERO
var _hand_r := -1
var _shoulder_bones := PackedInt32Array()


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if rig == null or sk == null or stick == null:
		return
	if _hand_r < 0:
		_hand_r = sk.find_bone("hand_r")
		_shoulder_bones = PackedInt32Array([sk.find_bone("upperarm_l"), sk.find_bone("upperarm_r")])
	_place(args[0], args[1], args[2], args[3])


## Partit nou: el pal torna al punt de control.
func reset() -> void:
	_ball_off = Vector3.ZERO


## Transformació d'un os en les coordenades locals del jugador, tal com és ara.
func bone_local(bone: int) -> Transform3D:
	var sk := get_skeleton()
	return (
		rig.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(bone)
	)


func _place(swing: float, hold: float, ball: Vector3, delta: float) -> void:
	var low := rig.low
	var height := rig.height
	var k := sin((swing / 0.25) * PI) if swing > 0.0 else 0.0
	var ctrl := CARRY_BLADE.lerp(Vector3(STICK_SIDE, 0.0, -STICK_F), low)
	# Amb un xut fort, el pal fa més arc (passada: com a la web; xut: un 40 % més amunt).
	var lift := 1.0 + 0.4 * maxf(0.0, rig.stroke - 0.5) * 2.0
	ctrl += Vector3(k * 0.35, k * 0.75 * lift, k * 0.55)
	# Amb la pilota, el pal va on es veu la pilota. La diferència amb el punt de control
	# es suavitza perquè el pal no salti quan la guanya o la perd.
	var off := Vector3.ZERO
	if ball != Vector3.INF:
		var b := rig.to_local(ball)
		off = Vector3(b.x - STICK_SIDE, 0.0, b.z + STICK_F) * (1.0 - k)
	if delta > 0.0:
		off = _ball_off.lerp(off, 1.0 - exp(-delta * 30.0))
	_ball_off = off
	ctrl += off
	var top_want := (TOP_HAND_UP.lerp(TOP_HAND, low) + Vector3(0.25, 0.35, 0.2) * k) * height
	var d := _reachable((top_want - ctrl).normalized(), ctrl, k)
	var xf := stick_xf(d, ctrl)
	blade = xf * StickMesh.ball_contact(BallView.RADIUS)
	var heel := xf * StickMesh.heel()
	grip_points[0] = heel + d * (StickMesh.LENGTH - 0.05)
	grip_points[1] = heel + d * _right_grip(heel, d, k)
	for i in 2:
		# La mà continua la línia del braç (de l'espatlla al pal), girada al voltant de la
		# canya, amb el polze cap avall. El canell va on cal perquè el puny caigui al pal.
		var arm := grip_points[i] - _shoulder(i)
		var y := (arm - d * arm.dot(d)).normalized()
		var hb := Basis(y.cross(-d), y, -d)
		grip.hand_basis[i] = hb
		grips[i].position = grip_points[i] - hb * GripModifier3D.hole(i) * height
	grip.hold.fill(hold)
	if hold < 0.999:
		# Amb la mà dreta: el pal amunt, agafat per dalt.
		var hand := bone_local(_hand_r)
		var up := Vector3(0.15, 1.0, 0.1).normalized()
		var fb := StickMesh.place_basis(up, Vector3.LEFT)
		var top := StickMesh.heel() + StickMesh.shaft_dir() * (StickMesh.LENGTH - 0.08)
		var free_xf := Transform3D(fb, hand.origin - fb * top)
		xf = free_xf.interpolate_with(xf, hold)
	stick.transform = xf


## Pal amb la canya en la direcció `d` i la cara del ganxo tocant una pilota a `ctrl`
## (a terra), sense que el cap es clavi a terra.
static func stick_xf(d: Vector3, ctrl: Vector3) -> Transform3D:
	var basis := StickMesh.place_basis(d, Vector3.LEFT)
	var r := BallView.RADIUS
	var origin := ctrl + Vector3(0.0, r, 0.0) - basis * StickMesh.ball_contact(r)
	var lowest := INF
	for q in StickMesh.bottom_points():
		lowest = minf(lowest, origin.y + (basis * q).y)
	origin.y -= minf(0.0, lowest)
	return Transform3D(basis, origin)


## La direcció `d` de la canya, o, si les mans no hi arriben, la més semblant inclinada cap
## a les espatlles amb què hi arriben totes dues (cerca binària).
func _reachable(d: Vector3, ctrl: Vector3, k: float) -> Vector3:
	if _reaches(d, ctrl, k):
		return d
	var mid := (_shoulder(0) + _shoulder(1)) * 0.5
	var toward := (mid - ctrl).normalized()
	var lo := 0.0
	var hi := 1.0
	for i in 8:
		var t := (lo + hi) * 0.5
		if _reaches(d.lerp(toward, t).normalized(), ctrl, k):
			hi = t
		else:
			lo = t
	return d.lerp(toward, hi).normalized()


## Si, amb la canya en la direcció `d`, totes dues mans arriben al pal.
func _reaches(d: Vector3, ctrl: Vector3, k: float) -> bool:
	var reach := ARM_REACH * rig.height
	var heel := stick_xf(d, ctrl) * StickMesh.heel()
	if (heel + d * (StickMesh.LENGTH - 0.05)).distance_to(_shoulder(0)) > reach:
		return false
	return (heel + d * _right_grip(heel, d, k)).distance_to(_shoulder(1)) <= reach


## On és l'espatlla `i` (0 esquerra, 1 dreta), amb la postura ja aplicada.
func _shoulder(i: int) -> Vector3:
	return bone_local(_shoulder_bones[i]).origin


## Fins on baixa la mà dreta per la canya (metres des del taló): tan avall com li arribi
## el braç des de l'espatlla, entre RIGHT_LOW i una mica sota la mà de dalt. Amb el cop
## (k), les mans s'ajunten.
func _right_grip(heel: Vector3, d: Vector3, k: float) -> float:
	var hi := StickMesh.LENGTH - 0.12
	var sh := _shoulder(1)
	var c := (sh - heel).dot(d)
	var gap := (heel + d * c).distance_to(sh)
	var reach := ARM_REACH * rig.height * 0.98
	var s := c - sqrt(maxf(0.0, reach * reach - gap * gap))
	return lerpf(clampf(s, RIGHT_LOW, hi), hi, k)
