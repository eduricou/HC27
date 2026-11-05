## Porteria d'hoquei: pals i travesser blancs, taules de fusta (fons i laterals, 46 cm),
## el bastidor del darrere i la xarxa, que es deforma quan hi entra la pilota.
## ref: drawGoal3D() (línies 1725–1761). Mides: src/sim/constants.gd
class_name GoalView
extends Node3D

const HL := Constants.HL
const GHW := Constants.GHW
const GH := Constants.GH
const GD := Constants.GD
## Altura de les taules i del bastidor del darrere. ref: bh, th
const BOARD_H := 0.46
const BACK_H := 1.5
const POST := 0.05
const NET_SHADER := preload("res://shaders/net.gdshader")

## −1 porteria de l'esquerra, 1 la de la dreta.
var side := 1
## D'on llegeix el moviment de la xarxa (pot ser nul).
var fx: StadiumFx

var _net_mat: ShaderMaterial


func _init(p_side: int = 1) -> void:
	side = p_side
	name = "Porteria%s" % ("Dreta" if side > 0 else "Esquerra")


func _ready() -> void:
	_build()


func _build() -> void:
	var s := float(side)
	var x0 := s * HL
	var x1 := s * (HL + GD)
	# Pals i travesser: la cara de davant sobre la línia de gol.
	var white := MeshBuilder.new()
	for py: float in [-1.0, 1.0]:
		var ya := py * GHW
		var yb := py * (GHW + POST)
		white.box(
			_lo(x0, x0 + s * POST),
			_hi(x0, x0 + s * POST),
			minf(ya, yb),
			maxf(ya, yb),
			0.0,
			GH + POST
		)
	white.box(
		_lo(x0, x0 + s * POST), _hi(x0, x0 + s * POST), -GHW - POST, GHW + POST, GH, GH + POST
	)
	add_child(white.to_instance("Pals", _mat(Color("f6f6f2"), 0.4)))
	# Taules: fons i laterals.
	var boards := MeshBuilder.new()
	boards.box(_lo(x1, x1 + s * 0.03), _hi(x1, x1 + s * 0.03), -GHW, GHW, 0.0, BOARD_H)
	for py: float in [-1.0, 1.0]:
		var ya := py * GHW
		var yb := py * (GHW + 0.025)
		boards.box(
			_lo(x0 + s * POST, x1), _hi(x0 + s * POST, x1), minf(ya, yb), maxf(ya, yb), 0.0, BOARD_H
		)
	add_child(boards.to_instance("Taules", _mat(Color("1b2540"), 0.7)))
	# Bastidor del darrere: de terra fins a dalt del fons i fins al travesser.
	var grey := _mat(Color("c8cdd2"), 0.5)
	for py: float in [-1.0, 1.0]:
		var y := py * (GHW + 0.02)
		add_child(_tube(Vector3(x1, y, 0.0), Vector3(x1, y, BACK_H), 0.018, grey))
		add_child(_tube(Vector3(x1, y, BACK_H), Vector3(x0 + s * POST, y, GH), 0.018, grey))
	add_child(_tube(Vector3(x1, -GHW, BACK_H), Vector3(x1, GHW, BACK_H), 0.015, grey))
	# Xarxa.
	_net_mat = ShaderMaterial.new()
	_net_mat.shader = NET_SHADER
	_net_mat.set_shader_parameter("rip_side", s)
	var net := MeshInstance3D.new()
	net.name = "Xarxa"
	net.mesh = net_mesh(side)
	net.material_override = _net_mat
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La deformació mou els vèrtexs: que no se surti de la caixa i desaparegui.
	net.custom_aabb = AABB(
		Vector3(minf(x0, x1) - 1.0, -0.1, -GHW - 0.5), Vector3(GD + 2.0, 2.6, GHW * 2.0 + 1.0)
	)
	add_child(net)


func _process(_delta: float) -> void:
	if _net_mat == null:
		return
	var on := fx != null and fx.net_side == side
	_net_mat.set_shader_parameter("rip_on", 1.0 if on else 0.0)
	if on:
		var t := fx.net_t + Engine.get_physics_interpolation_fraction() * Constants.STEP
		_net_mat.set_shader_parameter("rip_y", fx.net_y)
		_net_mat.set_shader_parameter("rip_t", t)


## Malla de la xarxa: fons, sostre i laterals, en coordenades de Godot. UV en metres,
## UV2 = (y, z) de la simulació i COLOR.r = pes de la deformació (com bulge() a la web:
## tot al fons, proporcional a la fondària al sostre i res als laterals). A diferència de
## la web, les vores lligades als pals, al travesser i a la taula no es mouen: si no, la
## malla s'obriria per les juntes.
static func net_mesh(p_side: int) -> ArrayMesh:
	var s := float(p_side)
	var x0 := s * (HL + POST)
	var x1 := s * (HL + GD)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var faces := [
		# [funció (u, v) -> [x, y, z, pes], nu, nv, normal, mida en metres]
		[
			func(u: float, w: float) -> Array:
				return [
					x1,
					lerpf(-GHW, GHW, u),
					lerpf(BOARD_H, BACK_H, w),
					_edge(u) * smoothstep(0.0, 0.35, w)
				],
			24,
			7,
			Vector3(-s, 0, 0),
			Vector2(GHW * 2.0, BACK_H - BOARD_H)
		],
		[
			func(u: float, w: float) -> Array:
				return [lerpf(x0, x1, w), lerpf(-GHW, GHW, u), lerpf(GH, BACK_H, w), _edge(u) * w],
			24,
			8,
			Vector3(0, 1, 0),
			Vector2(GHW * 2.0, Vector2(GD, GH - BACK_H).length())
		],
		[
			func(u: float, w: float) -> Array:
				return [lerpf(x0, x1, u), -GHW, lerpf(BOARD_H, lerpf(GH, BACK_H, u), w), 0.0],
			8,
			10,
			Vector3(0, 0, 1),
			Vector2(GD, GH - BOARD_H)
		],
		[
			func(u: float, w: float) -> Array:
				return [lerpf(x0, x1, u), GHW, lerpf(BOARD_H, lerpf(GH, BACK_H, u), w), 0.0],
			8,
			10,
			Vector3(0, 0, -1),
			Vector2(GD, GH - BOARD_H)
		],
	]
	for f: Array in faces:
		var fn: Callable = f[0]
		var nu: int = f[1]
		var nv: int = f[2]
		var size: Vector2 = f[4]
		var base := v.size()
		for j in nv + 1:
			for i in nu + 1:
				var p: Array = fn.call(float(i) / nu, float(j) / nv)
				v.append(Coords.to_view(p[0], p[1], p[2]))
				n.append(f[3])
				uv.append(Vector2(float(i) / nu * size.x, float(j) / nv * size.y))
				uv2.append(Vector2(p[1], p[2]))
				col.append(Color(p[3], 0.0, 0.0))
		for j in nv:
			for i in nu:
				var a := base + j * (nu + 1) + i
				idx.append_array([a, a + 1, a + nu + 2, a, a + nu + 2, a + nu + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Pes de la deformació al llarg de l'amplada (u de 0 a 1): zero als pals.
static func _edge(u: float) -> float:
	var k := 2.0 * u - 1.0
	return 1.0 - k * k * k * k


## Tub de radi r entre dos punts de la simulació.
static func _tube(a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var va := Coords.to_view(a.x, a.y, a.z)
	var vb := Coords.to_view(b.x, b.y, b.z)
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = va.distance_to(vb)
	cm.radial_segments = 8
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	var y := (vb - va).normalized()
	var ref := Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	mi.position = (va + vb) * 0.5
	return mi


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _lo(a: float, b: float) -> float:
	return minf(a, b)


static func _hi(a: float, b: float) -> float:
	return maxf(a, b)
