## Pal d'hoquei fet amb codi: cap en forma de J amb la cara plana a l'esquerra, canya
## ovalada que s'arrodoneix cap al mànec i puny folrat. Colors com a la web (drawStick()):
## puny blanc, franja del color de l'equip i la resta fosca.
## Coordenades del cap: Y amunt, Z endavant (cap on apunta la punta del ganxo) i X a
## l'esquerra (la cara plana). L'origen és a terra, just a sota del fons del ganxo. La
## canya surt del taló inclinada LIE cap enrere, de manera que amb el pal així inclinat el
## cap reposa pla a terra. PlayerRig el col·loca amb place_basis().
class_name StickMesh
extends RefCounted

## Llargada de la canya, del taló a dalt (un pal de 36,5", 93 cm).
const LENGTH := 0.93
## Inclinació de la canya respecte a la vertical amb el cap pla a terra.
const LIE := deg_to_rad(32.0)
## Radi de la corba del ganxo i angles de la tangent on comença (al taló) i acaba (la punta).
const HOOK_R := 0.045
const HOOK_END := deg_to_rad(100.0)
## Mitja alçada de la secció al fons del ganxo (el ganxo toca a terra amb la vora).
const HOOK_HALF := 0.02
## Gruix (cap a la cara) al fons del ganxo.
const HOOK_THICK := 0.013
## On comença el puny i on és la franja de l'equip (metres des del taló).
const GRIP_FROM := LENGTH - 0.22
const BAND := Vector2(0.36, 0.5)
const DARK := Color("1c1f23")
const GRIP := Color("e9ece6")
const AROUND := 10

static var _cache := {}


## Centre de la corba del ganxo.
static func hook_center() -> Vector3:
	return Vector3(0.0, HOOK_HALF + HOOK_R, 0.0)


## Punt de la línia del mig del ganxo amb la tangent a l'angle `th` (0 = horitzontal
## endavant, al fons).
static func hook_point(th: float) -> Vector3:
	return hook_center() + Vector3(0.0, -cos(th), sin(th)) * HOOK_R


## Taló: on la canya s'uneix al ganxo.
static func heel() -> Vector3:
	return hook_point(LIE - PI * 0.5)


## Direcció de la canya (del taló cap amunt).
static func shaft_dir() -> Vector3:
	return Vector3(0.0, cos(LIE), -sin(LIE))


## On queda el centre d'una pilota de radi `r` que toca la cara del fons del ganxo.
static func ball_contact(r: float) -> Vector3:
	return Vector3(HOOK_THICK + r + 0.002, r, 0.004)


## Punts de la vora de sota del ganxo, per saber si el cap es clava a terra.
static func bottom_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in 9:
		var th := lerpf(LIE - PI * 0.5, HOOK_END, k / 8.0)
		var p := hook_point(th)
		out.append(p + (p - hook_center()).normalized() * _section(th).y)
	return out


## Base del cap perquè la canya vagi en la direcció `d` (del taló cap a les mans), amb el
## cap tan pla a terra com es pugui. `left` és l'esquerra del jugador (si `d` és vertical).
static func place_basis(d: Vector3, left: Vector3) -> Basis:
	var x := d.cross(Vector3.UP)
	x = left if x.length_squared() < 1e-6 else x.normalized()
	var y := d.rotated(x, LIE)
	return Basis(x, y, x.cross(y))


## Pal amb la franja del color `team` (es fa una vegada per equip).
static func build(team: Color) -> ArrayMesh:
	var key := team.to_html()
	if _cache.has(key):
		return _cache[key]
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	# Ganxo: de la punta al taló (la tangent, cap al taló). La secció es fa zero a la punta
	# perquè acabi rodona.
	var n_hook := 16
	for i in n_hook + 1:
		var th := lerpf(HOOK_END, LIE - PI * 0.5, float(i) / n_hook)
		var tip := clampf((HOOK_END - th) / 0.35, 0.0, 1.0)
		var tangent := -Vector3(0.0, sin(th), cos(th))
		_ring(rows, cols, refs, hook_point(th), tangent, _section(th), DARK, sqrt(tip))
	# Canya: del taló a dalt. On canvia el color hi ha dues files al mateix lloc.
	var stops := [
		[0.015, DARK],
		[0.05, DARK],
		[0.1, DARK],
		[0.18, DARK],
		[0.27, DARK],
		[BAND.x, DARK],
		[BAND.x, team],
		[BAND.y, team],
		[BAND.y, DARK],
		[0.6, DARK],
		[GRIP_FROM, DARK],
		[GRIP_FROM, GRIP],
		[0.8, GRIP],
		[LENGTH - 0.012, GRIP],
		[LENGTH - 0.004, GRIP],
		[LENGTH, GRIP],
	]
	for stop: Array in stops:
		var u: float = stop[0]
		# Dalt de tot, el puny acaba arrodonit.
		var cap := sqrt(clampf((LENGTH - u) / 0.012, 0.0, 1.0))
		var p := heel() + shaft_dir() * u
		_ring(rows, cols, refs, p, shaft_dir(), _shaft_section(u), stop[1], cap)
	var part := MeshPart.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, MeshPart.material(0.35))
	_cache[key] = mesh
	return mesh


## Mida de la secció del ganxo a l'angle `th`: x = gruix, y = mitja alçada. S'aprima cap a
## la punta.
static func _section(th: float) -> Vector2:
	var to_tip := clampf((th - (LIE - PI * 0.5)) / (HOOK_END - (LIE - PI * 0.5)), 0.0, 1.0)
	return Vector2(lerpf(HOOK_THICK, 0.009, to_tip), lerpf(HOOK_HALF, 0.013, to_tip * to_tip))


## Secció de la canya a `u` metres del taló: ovalada a baix i rodona al mànec.
static func _shaft_section(u: float) -> Vector2:
	var t := smoothstep(0.05, 0.5, u)
	var s := Vector2(lerpf(0.0125, 0.0145, t), lerpf(0.019, 0.0145, t))
	if u >= GRIP_FROM:
		s += Vector2.ONE * 0.0012
	return s


## Afegeix una secció a `p`, perpendicular a `tangent`: plana pel costat de la cara (+X) i
## rodona pel darrere. `k` l'encongeix (puntes).
static func _ring(
	rows: Array[PackedVector3Array],
	cols: Array[PackedColorArray],
	refs: PackedVector3Array,
	p: Vector3,
	tangent: Vector3,
	size: Vector2,
	col: Color,
	k: float
) -> void:
	var n := Vector3.RIGHT.cross(tangent).normalized()
	var ring := PackedVector3Array()
	var rc := PackedColorArray()
	for j in AROUND:
		var a := TAU * j / AROUND
		var s := sin(a)
		var x := size.x * MeshPart.spow(s, 0.25 if s > 0.0 else 0.85)
		var y := size.y * MeshPart.spow(cos(a), 0.75)
		ring.append(p + (Vector3.RIGHT * x + n * y) * k)
		rc.append(col)
	rows.append(ring)
	cols.append(rc)
	refs.append(p)
