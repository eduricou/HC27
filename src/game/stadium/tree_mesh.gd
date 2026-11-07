## Arbres fets amb codi, en 3D: pins pinyers (tronc inclinat, tres o quatre branques i la
## copa plana, en forma de para-sol), arbres de fulla del carrer (copa rodona), arbustos i
## la bardissa.
## La copa és un grup de masses irregulars (esferes deformades amb soroll). Cada malla té
## dues superfícies, l'escorça i el fullatge (shaders/tree.gdshader), i es fa una vegada
## per variant: l'estadi les repeteix girades i escalades amb MultiMesh.
## Coordenades: Y amunt i el peu del tronc a l'origen. Mides a escala 1: el pi fa uns
## 11,5 m d'alt, l'arbre del carrer uns 7,5 m i l'arbust uns 2 m.
class_name TreeMesh
extends RefCounted

const BARK := Color("5a4535")
const BARK_PINE := Color("6b4a35")
const SHADER := preload("res://shaders/tree.gdshader")
## Resolució de cada massa de fulles.
const RINGS := 7
const SEGMENTS := 12

static var _noise: FastNoiseLite


## Pi pinyer de la variant `seed_value`.
static func pine(seed_value: int, foliage: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark := MeshPart.new()
	var leaves := MeshPart.new()
	var trunk_h := rng.randf_range(6.6, 7.4)
	var lean_a := rng.randf() * TAU
	var lean := Vector3(cos(lean_a), 0.0, sin(lean_a)) * rng.randf_range(0.4, 1.0)
	var trunk := PackedVector3Array()
	for i in 7:
		var t := i / 6.0
		var wig := Vector3(sin(t * 5.0 + seed_value), 0.0, cos(t * 4.0 + seed_value)) * 0.08
		trunk.append(Vector3(0.0, trunk_h * t, 0.0) + lean * pow(t, 1.5) + wig * t)
	_limb(bark, trunk, 0.3, 0.16, BARK_PINE, 8)
	var top := trunk[-1]
	var n := rng.randi_range(3, 4)
	var a0 := rng.randf() * TAU
	var top_c := Color("2f4a20")
	var bottom_c := Color("142212")
	for i in n:
		var a := a0 + i * TAU / n + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var start := top - Vector3(0.0, rng.randf_range(0.0, 1.0), 0.0)
		var out := rng.randf_range(1.5, 2.3)
		var up := rng.randf_range(1.6, 2.1)
		var limb := PackedVector3Array()
		for k in 4:
			var t := k / 3.0
			limb.append(start + dir * out * t + Vector3(0.0, up * sqrt(t), 0.0))
		_limb(bark, limb, 0.13, 0.05, BARK_PINE, 6)
		var r := rng.randf_range(1.7, 2.3)
		_blob(
			leaves,
			limb[-1] + Vector3(0.0, 0.45, 0.0),
			Vector3(r, r * 0.45, r),
			top_c,
			bottom_c,
			rng
		)
	_blob(leaves, top + Vector3(0.0, 2.35, 0.0), Vector3(2.2, 1.0, 2.2), top_c, bottom_c, rng)
	for i in 2:
		var a := rng.randf() * TAU
		var c := top + Vector3(cos(a) * 1.6, 2.0 + rng.randf() * 0.3, sin(a) * 1.6)
		_blob(leaves, c, Vector3(1.5, 0.75, 1.5), top_c, bottom_c, rng)
	return _mesh(bark, leaves, foliage)


## Arbre de fulla del carrer (lledoner o plàtan): tronc curt i copa rodona.
static func broadleaf(seed_value: int, foliage: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark := MeshPart.new()
	var leaves := MeshPart.new()
	var trunk_h := rng.randf_range(2.3, 2.8)
	var trunk := PackedVector3Array()
	for i in 4:
		var t := i / 3.0
		trunk.append(Vector3(sin(t * 3.0 + seed_value) * 0.08, trunk_h * t, 0.0))
	_limb(bark, trunk, 0.2, 0.14, BARK, 7)
	var top_c := Color("3f6224")
	var bottom_c := Color("1a2d10")
	var a0 := rng.randf() * TAU
	for i in 3:
		var a := a0 + i * TAU / 3.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var limb := PackedVector3Array(
			[
				trunk[-1],
				trunk[-1] + dir * 0.5 + Vector3(0, 0.9, 0),
				trunk[-1] + dir * 0.9 + Vector3(0, 1.8, 0)
			]
		)
		_limb(bark, limb, 0.1, 0.05, BARK, 5)
	var cy := trunk_h + 2.5
	for i in 5:
		var a := a0 + i * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
		var c := Vector3(cos(a) * 1.15, cy + rng.randf_range(-0.4, 0.3), sin(a) * 1.15)
		var r := rng.randf_range(1.35, 1.7)
		_blob(leaves, c, Vector3(r, r * 0.85, r), top_c, bottom_c, rng)
	_blob(leaves, Vector3(0.0, cy + 1.3, 0.0), Vector3(1.6, 1.3, 1.6), top_c, bottom_c, rng)
	return _mesh(bark, leaves, foliage)


## Arbust: dues o tres masses a tocar de terra.
static func bush(seed_value: int, foliage: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var leaves := MeshPart.new()
	var top_c := Color("3b5822")
	var bottom_c := Color("1b2a12")
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.7)
		var r := rng.randf_range(0.75, 1.1)
		var c := Vector3(cos(a) * d, r * 0.75, sin(a) * d)
		_blob(leaves, c, Vector3(r, r * 0.8, r), top_c, bottom_c, rng)
	return _mesh(MeshPart.new(), leaves, foliage)


## Bardissa de x0 a x1 (al llarg de X), de fondària `depth` (cap a +Z des de z = 0) i
## alçada `height` (+0,3 m com a molt). Secció arrodonida i deformada amb soroll.
static func hedge(
	x0: float, x1: float, depth: float, height: float, foliage: Material
) -> ArrayMesh:
	var n := _get_noise()
	var leaves := MeshPart.new()
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	var top_c := Color("33501f")
	var bottom_c := Color("15240f")
	var steps := ceili((x1 - x0) / 0.5)
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		# Alçada del tram: puja i baixa a poc a poc.
		var h := height - 0.2 + 0.3 * (n.get_noise_2d(x * 0.08, 7.0) * 0.5 + 0.5)
		var c := Vector3(x, h * 0.5, depth * 0.5)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in 16:
			var a := TAU * j / 16.0
			var d := Vector2(cos(a), sin(a))
			# Rectangle de cantonades rodones (superel·lipse).
			var e := Vector2(MeshPart.spow(d.x, 0.35), MeshPart.spow(d.y, 0.35))
			var p := Vector3(x, h * 0.5 + e.y * h * 0.5, depth * 0.5 + e.x * depth * 0.5)
			var q := p * 0.9
			var bump := n.get_noise_3d(q.x, q.y, q.z)
			var out := Vector3(0.0, e.y, e.x).normalized()
			if p.y > 0.05:
				p += out * 0.18 * bump
			p.y = maxf(p.y, 0.0)
			ring.append(p)
			var shade := smoothstep(0.0, h, p.y) * (0.85 + 0.3 * bump)
			rc.append(bottom_c.lerp(top_c, clampf(shade, 0.0, 1.0)))
		rows.append(ring)
		cols.append(rc)
		refs.append(c)
	leaves.grid(rows, cols, true, refs)
	return _mesh(MeshPart.new(), leaves, foliage)


## Material del fullatge (un per a tots els arbres).
static func foliage_material(noise: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("noise_tex", noise)
	return m


## Branca o tronc: tub que s'aprima de `r0` a `r1` al llarg de `path`.
static func _limb(
	part: MeshPart, path: PackedVector3Array, r0: float, r1: float, color: Color, sides: int
) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.RIGHT if absf(t.x) < 0.8 else Vector3.BACK
		var u := t.cross(ref).normalized()
		var w := t.cross(u)
		var r := lerpf(r0, r1, float(i) / (path.size() - 1))
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in sides:
			var a := TAU * k / sides
			ring.append(path[i] + (u * cos(a) + w * sin(a)) * r)
			rc.append(color.darkened(0.15 * (1.0 - float(i) / (path.size() - 1))))
		rows.append(ring)
		cols.append(rc)
	part.grid(rows, cols, true, path)


## Massa de fulles: esfera de radis `radii` deformada amb soroll. Més fosca a sota.
static func _blob(
	part: MeshPart,
	center: Vector3,
	radii: Vector3,
	top_c: Color,
	bottom_c: Color,
	rng: RandomNumberGenerator
) -> void:
	var n := _get_noise()
	var off := Vector3(rng.randf() * 100.0, rng.randf() * 100.0, rng.randf() * 100.0)
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for i in RINGS + 1:
		var el := PI * 0.5 - PI * i / RINGS
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in SEGMENTS:
			var az := TAU * j / SEGMENTS
			var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
			var q := dir * 1.6 + off
			var bump := n.get_noise_3d(q.x, q.y, q.z)
			var k := 1.0 + 0.28 * bump
			ring.append(center + dir * radii * k)
			var shade := smoothstep(-0.7, 0.8, dir.y) * (0.85 + 0.3 * bump)
			rc.append(bottom_c.lerp(top_c, clampf(shade, 0.0, 1.0)))
		rows.append(ring)
		cols.append(rc)
		refs.append(center)
	part.grid(rows, cols, true, refs)


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.fractal_octaves = 2
	return _noise


static func _mesh(bark: MeshPart, leaves: MeshPart, foliage: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not bark.verts.is_empty():
		bark.add_to(mesh, MeshPart.material(0.95))
	leaves.add_to(mesh, foliage)
	return mesh
