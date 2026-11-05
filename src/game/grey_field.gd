## Camp de la fase 2 («caixes grises»): gespa plana, línies i porteries simples.
## La fase 3 el substituirà per l'estadi (scenes/stadium.tscn i shaders/turf.gdshader).
## Mides: src/sim/constants.gd. ref: línies 1278–1342 (FS_GROUND) i drawGoal3D()
class_name GreyField
extends RefCounted

const HL := Constants.HL
const HW := Constants.HW
const GHW := Constants.GHW
const LINE_W := 0.1
const LINE_Y := 0.012
const DASH := 3.0
const TURF := Color("1f6b33")
const SURROUND := Color("174f27")
const GROUND := Color("2b3a30")
const LINE := Color("eef2ec")
const GOAL := Color("f4f4f0")
const BOARD := Color("1b2a22")


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "GreyField"
	# Terra fins a l'horitzó (la fase 3 hi posarà l'estadi i la ciutat).
	root.add_child(_plane("Terra", Vector2(800.0, 800.0), GROUND, -0.02))
	root.add_child(
		_plane("Voltant", Vector2(Constants.FL + 14.0, Constants.FW + 12.0), SURROUND, 0.0)
	)
	root.add_child(_plane("Gespa", Vector2(Constants.FL + 4.0, Constants.FW + 4.0), TURF, 0.004))
	var lines := MeshInstance3D.new()
	lines.name = "Linies"
	lines.mesh = line_mesh()
	lines.material_override = _unshaded(LINE)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lines)
	for side: int in [-1, 1]:
		root.add_child(_goal(side))
	return root


## Malla de totes les línies del camp (quads plans de LINE_W d'amplada).
static func line_mesh() -> ArrayMesh:
	var segs := PackedVector2Array()
	# Límits, línia central i línies de 23 m.
	_polyline(segs, [Vector2(-HL, -HW), Vector2(HL, -HW), Vector2(HL, HW), Vector2(-HL, HW)], true)
	_polyline(segs, [Vector2(0.0, -HW), Vector2(0.0, HW)])
	for s: int in [-1, 1]:
		var l23 := s * Constants.L23
		_polyline(segs, [Vector2(l23, -HW), Vector2(l23, HW)])
		_polyline(segs, circle_points(s, Constants.CR))
		_dashed(segs, circle_points(s, Constants.DR), DASH)
		# Punt de penal.
		var px := s * (HL - Constants.PSPOT)
		_polyline(segs, [Vector2(px - 0.08, 0.0), Vector2(px + 0.08, 0.0)])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0, segs.size(), 2):
		var a := segs[i]
		var b := segs[i + 1]
		var d := b - a
		if d.length() < 1e-6:
			continue
		var n := Vector2(-d.y, d.x).normalized() * (LINE_W * 0.5)
		# Allarga una mica cada segment perquè les juntes no facin forats.
		var e := d.normalized() * (LINE_W * 0.5)
		var q := [a - e + n, b + e + n, b + e - n, a - e - n]
		for k: int in [0, 1, 2, 0, 2, 3]:
			var v: Vector2 = q[k]
			verts.append(Coords.to_view(v.x, v.y, LINE_Y))
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Contorn del cercle d'atac de la porteria del costat `side`: dos quarts de cercle de
## radi r centrats als pals i la recta que els uneix (la mateixa forma que in_circle()).
static func circle_points(side: int, r: float, steps: int = 24) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var gx := side * HL
	for k in range(steps, -1, -1):
		var a := PI * 0.5 * k / steps
		pts.append(Vector2(gx - side * r * cos(a), GHW + r * sin(a)))
	for k in range(0, steps + 1):
		var a := PI * 0.5 * k / steps
		pts.append(Vector2(gx - side * r * cos(a), -GHW - r * sin(a)))
	return pts


static func _polyline(out: PackedVector2Array, pts: Array, closed: bool = false) -> void:
	for i in range(pts.size() - 1):
		out.append(pts[i])
		out.append(pts[i + 1])
	if closed:
		out.append(pts[pts.size() - 1])
		out.append(pts[0])


## Línia discontínua: trams de `dash` metres separats per `dash` metres.
static func _dashed(out: PackedVector2Array, pts: Array[Vector2], dash: float) -> void:
	var dist := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var phase := fmod(dist + t, dash * 2.0)
			var step := minf(seg - t, (dash if phase < dash else dash * 2.0) - phase)
			if phase < dash:
				out.append(a.lerp(b, t / seg))
				out.append(a.lerp(b, (t + step) / seg))
			t += step
		dist += seg


static func _plane(n: String, size: Vector2, color: Color, y: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var pm := PlaneMesh.new()
	pm.size = size
	m.mesh = pm
	m.position = Vector3(0.0, y, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	m.material_override = mat
	return m


static func _goal(side: int) -> Node3D:
	var g := Node3D.new()
	g.name = "Porteria%s" % ("Dreta" if side > 0 else "Esquerra")
	var gx := side * HL
	var white := StandardMaterial3D.new()
	white.albedo_color = GOAL
	var dark := StandardMaterial3D.new()
	dark.albedo_color = BOARD
	var gh := Constants.GH
	var gd := Constants.GD
	var post := 0.07
	for py: float in [-GHW, GHW]:
		g.add_child(
			_box(
				Vector3(post, gh, post), Coords.to_view(gx + side * post * 0.5, py, gh * 0.5), white
			)
		)
	g.add_child(
		_box(
			Vector3(post, post, GHW * 2.0 + post),
			Coords.to_view(gx + side * post * 0.5, 0.0, gh),
			white
		)
	)
	# Taula del fons i taules laterals (0,46 m d'alçada).
	g.add_child(
		_box(Vector3(0.03, 0.46, GHW * 2.0), Coords.to_view(gx + side * gd, 0.0, 0.23), dark)
	)
	for py: float in [-GHW, GHW]:
		g.add_child(
			_box(Vector3(gd, 0.46, 0.03), Coords.to_view(gx + side * gd * 0.5, py, 0.23), dark)
		)
	return g


static func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	return m


static func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Coords.to_view() és una reflexió: els triangles queden girats i, si no, es descarten.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
