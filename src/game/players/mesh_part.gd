## Malla feta amb codi (equip del porter, pal): una superfície amb vèrtexs, normals, colors
## i triangles, que s'omple amb graelles i tubs. Els colors van als vèrtexs (material()).
class_name MeshPart
extends RefCounted

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var idx := PackedInt32Array()


## Graella pts[i][j]: i al llarg, j al voltant (si `closed`, la volta es tanca). Les
## normals surten de la mateixa graella i miren lluny de refs[i] (el centre de cada
## anella), o cap a dins si `inward`.
func grid(
	pts: Array[PackedVector3Array],
	cols: Array[PackedColorArray],
	closed: bool,
	refs: PackedVector3Array,
	inward := false
) -> void:
	var rows := pts.size()
	var m := pts[0].size()
	var start := verts.size()
	for i in rows:
		for j in m:
			var p := pts[i][j]
			var du := pts[mini(i + 1, rows - 1)][j] - pts[maxi(i - 1, 0)][j]
			var jn := (j + 1) % m if closed else mini(j + 1, m - 1)
			var jp := (j + m - 1) % m if closed else maxi(j - 1, 0)
			var n := du.cross(pts[i][jn] - pts[i][jp])
			var out := p - refs[i]
			if n.length_squared() < 1e-14:
				# Anella feta un punt (una punta o el pol): la normal va enfora.
				var axis := refs[0] - refs[1] if i == 0 else refs[i] - refs[i - 1]
				n = out if out.length_squared() > 1e-10 else axis
			elif n.dot(out) < 0.0:
				n = -n
			verts.append(p)
			normals.append((-n if inward else n).normalized())
			colors.append(cols[i][j])
	for i in rows - 1:
		for j in m if closed else m - 1:
			var j2 := (j + 1) % m
			var a := start + i * m + j
			var b := start + (i + 1) * m + j
			var c := start + (i + 1) * m + j2
			var d := start + i * m + j2
			_tri(a, b, c)
			_tri(a, c, d)


## Tub de radi `r` al llarg de `path` (les barres de la reixa).
func tube(path: PackedVector3Array, r: float, color: Color, sides := 6) -> void:
	var along := (path[path.size() - 1] - path[0]).normalized()
	var ref := Vector3.UP if absf(along.y) < 0.7 else Vector3.RIGHT
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var u := t.cross(ref).normalized()
		var w := t.cross(u)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in sides:
			var a := TAU * k / sides
			ring.append(path[i] + (u * cos(a) + w * sin(a)) * r)
			rc.append(color)
		rows.append(ring)
		cols.append(rc)
	grid(rows, cols, true, path)


## Godot dibuixa la cara de davant dels triangles en sentit horari.
func _tri(a: int, b: int, c: int) -> void:
	var face := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if face.dot(normals[a] + normals[b] + normals[c]) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


func add_to(mesh: ArrayMesh, mat: Material) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## Escala de la secció a prop de les puntes perquè acabin rodones: d0 i d1 són les
## distàncies a cada punta i r0 i r1 els radis de la volta. Amb e > 2, la punta és més
## xata (superel·lipse).
static func round_ends(d0: float, d1: float, r0: float, r1: float, e := 2.0) -> float:
	var u := 0.0
	if d0 < r0:
		u = 1.0 - d0 / r0
	elif d1 < r1:
		u = 1.0 - d1 / r1
	return pow(maxf(0.0, 1.0 - pow(u, e)), 1.0 / e)


## Potència amb signe: superel·lipses (seccions de cantells rodons).
static func spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


static func material(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m
