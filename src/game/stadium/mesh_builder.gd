## Construeix malles a partir de punts en coordenades de la simulació (x, y, z amunt) i
## les converteix a Godot amb Coords.to_view(). Com que la conversió és una reflexió, cada
## triangle s'orienta a partir de la normal que es demana: així es poden fer servir
## materials amb el descart de cares normal. Equival a quad(), box() i crossQuad() de la
## web (línies 1469–1481).
class_name MeshBuilder
extends RefCounted

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _uv := PackedVector2Array()


func is_empty() -> bool:
	return _v.is_empty()


## Quad amb els vèrtexs a (baix-esquerra), b (baix-dreta), c (dalt-dreta) i d
## (dalt-esquerra), com a la web. UV: a = (u0, v1), b = (u1, v1), c = (u1, v0), d = (u0, v0).
## `facing`: cap on mira la cara visible, en coordenades de la simulació.
func quad(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	facing: Vector3,
	uv0: Vector2 = Vector2.ZERO,
	uv1: Vector2 = Vector2.ONE
) -> void:
	var va := _view(a)
	var vb := _view(b)
	var vc := _view(c)
	var vd := _view(d)
	var n := (vb - va).cross(vd - va)
	if n.length_squared() < 1e-12:
		n = (vc - vb).cross(va - vb)
	n = n.normalized()
	if n.dot(_view(facing)) < 0.0:
		n = -n
	var ta := Vector2(uv0.x, uv1.y)
	var tb := Vector2(uv1.x, uv1.y)
	var tc := Vector2(uv1.x, uv0.y)
	var td := Vector2(uv0.x, uv0.y)
	_tri(va, vb, vc, ta, tb, tc, n)
	_tri(va, vc, vd, ta, tc, td, n)


## Caixa alineada amb els eixos, en coordenades de la simulació. `uv_m`: metres per
## unitat de UV a les parets (0 = una textura per cara). Sense la cara de sota.
func box(
	x0: float,
	x1: float,
	y0: float,
	y1: float,
	z0: float,
	z1: float,
	uv_m: float = 0.0,
	v_scale: float = 1.0,
	top: bool = true
) -> void:
	var ux := (x1 - x0) / uv_m if uv_m > 0.0 else 1.0
	var uy := (y1 - y0) / uv_m if uv_m > 0.0 else 1.0
	var v1 := Vector2(ux, v_scale)
	var w1 := Vector2(uy, v_scale)
	quad(
		Vector3(x0, y1, z0),
		Vector3(x1, y1, z0),
		Vector3(x1, y1, z1),
		Vector3(x0, y1, z1),
		Vector3(0, 1, 0),
		Vector2.ZERO,
		v1
	)
	quad(
		Vector3(x1, y1, z0),
		Vector3(x1, y0, z0),
		Vector3(x1, y0, z1),
		Vector3(x1, y1, z1),
		Vector3(1, 0, 0),
		Vector2.ZERO,
		w1
	)
	quad(
		Vector3(x0, y0, z0),
		Vector3(x0, y1, z0),
		Vector3(x0, y1, z1),
		Vector3(x0, y0, z1),
		Vector3(-1, 0, 0),
		Vector2.ZERO,
		w1
	)
	quad(
		Vector3(x1, y0, z0),
		Vector3(x0, y0, z0),
		Vector3(x0, y0, z1),
		Vector3(x1, y0, z1),
		Vector3(0, -1, 0),
		Vector2.ZERO,
		v1
	)
	if top:
		quad(
			Vector3(x0, y1, z1),
			Vector3(x1, y1, z1),
			Vector3(x1, y0, z1),
			Vector3(x0, y0, z1),
			Vector3(0, 0, 1)
		)


## Dos quads verticals creuats, centrats a (x, y), d'amplada w i de h0 a h1 (arbres).
## `angle`: gir al voltant de la vertical (0: un quad paral·lel a x i l'altre a y).
func cross_quad(x: float, y: float, w: float, h0: float, h1: float, angle: float = 0.0) -> void:
	for k in 2:
		var a := angle + k * PI * 0.5
		var d := Vector2(cos(a), sin(a)) * (w * 0.5)
		var n := Vector3(-d.y, d.x, 0.0)
		quad(
			Vector3(x - d.x, y - d.y, h0),
			Vector3(x + d.x, y + d.y, h0),
			Vector3(x + d.x, y + d.y, h1),
			Vector3(x - d.x, y - d.y, h1),
			n
		)


## Polígon convex (en ventall des del primer punt), amb UV planes a partir de x i z o y.
func polygon(pts: Array[Vector3], facing: Vector3) -> void:
	for i in range(1, pts.size() - 1):
		var va := _view(pts[0])
		var vb := _view(pts[i])
		var vc := _view(pts[i + 1])
		var n := (vb - va).cross(vc - va).normalized()
		if n.dot(_view(facing)) < 0.0:
			n = -n
		_tri(
			va,
			vb,
			vc,
			Vector2(pts[0].y, pts[0].z),
			Vector2(pts[i].y, pts[i].z),
			Vector2(pts[i + 1].y, pts[i + 1].z),
			n
		)


## Afegeix triangles ja en coordenades de Godot (per a malles fetes a mà).
func tri_view(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	n: Vector3,
	ta := Vector2.ZERO,
	tb := Vector2.ZERO,
	tc := Vector2.ZERO
) -> void:
	_tri(a, b, c, ta, tb, tc, n)


func to_mesh(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	var mesh := ArrayMesh.new()
	if _v.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


## Instància amb la malla i el material.
func to_instance(node_name: String, material: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = to_mesh()
	mi.material_override = material
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _view(p: Vector3) -> Vector3:
	return Coords.to_view(p.x, p.y, p.z)


## Godot dibuixa la cara davantera quan els vèrtexs van en sentit horari vistos des de
## davant: si cal, s'intercanvien b i c.
func _tri(
	a: Vector3, b: Vector3, c: Vector3, ta: Vector2, tb: Vector2, tc: Vector2, n: Vector3
) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tt := tb
		tb = tc
		tc = tt
	_v.append_array([a, b, c])
	_n.append_array([n, n, n])
	_uv.append_array([ta, tb, tc])
