## Cotxe aparcat, fet amb codi: carrosseria de turisme (morro i cul arrodonits, el capó i
## el maleter més baixos que la cabina), vidres foscos amb els pilars, quatre rodes amb
## llanta, fars i pilots. El color de la carrosseria el posa cada cotxe (MultiMesh,
## INSTANCE_CUSTOM, shaders/car.gdshader); la resta va al color del vèrtex.
## Coordenades: X al llarg (el morro a +X), Y amunt, Z de costat; les rodes a terra.
class_name CarMesh
extends RefCounted

const LENGTH := 4.3
const WIDTH := 1.78
## Perfil de costat: [x, alçada de sota, alçada de dalt] de la carrosseria (sense cabina).
const BODY := [
	Vector3(-2.15, 0.36, 0.78),
	Vector3(-2.05, 0.3, 0.92),
	Vector3(-1.6, 0.28, 0.98),
	Vector3(1.2, 0.28, 0.96),
	Vector3(1.85, 0.3, 0.86),
	Vector3(2.15, 0.36, 0.72),
]
## Cabina: [x, alçada de dalt, mitja amplada] del parabrisa al vidre del darrere.
const CABIN := [
	Vector3(1.05, 0.96, 0.78),
	Vector3(0.35, 1.42, 0.7),
	Vector3(-0.85, 1.45, 0.7),
	Vector3(-1.6, 0.98, 0.78),
]
const WHEELS := [Vector2(1.35, 0.78), Vector2(-1.3, 0.78)]
const TYRE := Color("161718")
const RIM := Color("9a9ea3")
const GLASS := Color("1b232c")
const LIGHT_FRONT := Color("f2efe2")
const LIGHT_BACK := Color("a01818")

const SHADER := preload("res://shaders/car.gdshader")

static var _mesh: ArrayMesh


static func build() -> ArrayMesh:
	if _mesh:
		return _mesh
	var paint := MeshPart.new()
	var other := MeshPart.new()
	_body(paint)
	_cabin(paint, other)
	for w: Vector2 in WHEELS:
		for side: float in [-1.0, 1.0]:
			_wheel(other, Vector3(w.x, 0.33, side * w.y))
	for side: float in [-1.0, 1.0]:
		other.box(
			Vector3(2.13, 0.62, side * 0.62 - 0.15),
			Vector3(2.17, 0.72, side * 0.62 + 0.15),
			LIGHT_FRONT
		)
		other.box(
			Vector3(-2.17, 0.66, side * 0.66 - 0.13),
			Vector3(-2.13, 0.76, side * 0.66 + 0.13),
			LIGHT_BACK
		)
	_mesh = ArrayMesh.new()
	paint.add_to(_mesh, material(true))
	other.add_to(_mesh, material(false))
	return _mesh


## Material: la carrosseria agafa el color de cada cotxe; la resta, el del vèrtex.
static func material(body: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("painted", body)
	m.set_shader_parameter("roughness", 0.3 if body else 0.5)
	m.set_shader_parameter("metallic", 0.45 if body else 0.0)
	return m


## Carrosseria: el perfil de costat extruït, amb els costats una mica bombats.
static func _body(part: MeshPart) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	var half := WIDTH * 0.5
	for b: Vector3 in BODY:
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		var mid := (b.y + b.z) * 0.5
		var k := 1.0 - 0.12 * smoothstep(1.7, 2.15, absf(b.x))
		for j in 12:
			var a := TAU * j / 12.0
			var y := mid + (b.z - b.y) * 0.5 * MeshPart.spow(sin(a), 0.35)
			var z := half * k * MeshPart.spow(cos(a), 0.25)
			ring.append(Vector3(b.x, y, z))
			rc.append(Color.WHITE)
		rows.append(ring)
		cols.append(rc)
		refs.append(Vector3(b.x, mid, 0.0))
	part.grid(rows, cols, true, refs)
	# Tapes del morro i del cul.
	for e in [0, rows.size() - 1]:
		var c := refs[e]
		var out := Vector3.RIGHT if e > 0 else Vector3.LEFT
		for j in 12:
			part.quad(c, rows[e][j], rows[e][(j + 1) % 12], c, Color.WHITE, out)


## Cabina: el sostre i els pilars, del color del cotxe; els vidres, foscos i una mica
## enfonsats.
static func _cabin(paint: MeshPart, glass: MeshPart) -> void:
	var n := CABIN.size()
	for i in n - 1:
		var a: Vector3 = CABIN[i]
		var b: Vector3 = CABIN[i + 1]
		# Sostre o vidre de davant/darrere entre a i b.
		var col := GLASS if i != 1 else Color.WHITE
		var target := glass if i != 1 else paint
		# Cap enfora de la cabina (del centre, a x = −0,25 i 0,9 m d'alçada).
		var up := Vector3(-(b.y - a.y), b.x - a.x, 0.0)
		var mid := (a + b) * 0.5
		if up.dot(Vector3(mid.x + 0.25, mid.y - 0.9, 0.0)) < 0.0:
			up = -up
		target.quad(
			Vector3(a.x, a.y, -a.z),
			Vector3(a.x, a.y, a.z),
			Vector3(b.x, b.y, b.z),
			Vector3(b.x, b.y, -b.z),
			col,
			up
		)
	# Costats: vidres laterals amb el pilar del mig.
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for c: Vector3 in CABIN:
			pts.append(Vector3(c.x, c.y, side * c.z))
		var base_y := 0.96
		for i in n - 1:
			var a := pts[i]
			var b := pts[i + 1]
			glass.quad(
				Vector3(a.x, base_y, side * 0.78),
				a,
				b,
				Vector3(b.x, base_y, side * 0.78),
				GLASS,
				Vector3(0, 0, side)
			)
		# Pilar del mig (B) i marc de baix, del color del cotxe.
		paint.box(
			Vector3(-0.3, base_y, side * 0.745 - 0.02),
			Vector3(-0.18, 1.43, side * 0.745 + 0.02),
			Color.WHITE
		)


## Roda: pneumàtic (cilindre) amb la llanta clara a fora.
static func _wheel(part: MeshPart, c: Vector3) -> void:
	var r := 0.33
	var w := 0.11
	var sides := 14
	var out := signf(c.z)
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for z: float in [c.z - w, c.z + w]:
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in sides:
			var a := TAU * k / sides
			ring.append(Vector3(c.x + cos(a) * r, c.y + sin(a) * r, z))
			rc.append(TYRE)
		rows.append(ring)
		cols.append(rc)
		refs.append(Vector3(c.x, c.y, z))
	part.grid(rows, cols, true, refs)
	var face := Vector3(c.x, c.y, c.z + out * w)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(c.x + cos(a0) * r, c.y + sin(a0) * r, face.z)
		var p1 := Vector3(c.x + cos(a1) * r, c.y + sin(a1) * r, face.z)
		var q0 := face + (p0 - face) * 0.62
		var q1 := face + (p1 - face) * 0.62
		part.quad(q0, p0, p1, q1, TYRE, Vector3(0, 0, out))
		part.quad(face, q0, q1, face, RIM, Vector3(0, 0, out))
