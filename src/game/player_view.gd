## Jugador de la fase 2: càpsula amb el color de la samarreta, cap, pal i dorsal.
## La fase 4 el substituirà per un model amb esquelet (scenes/player.tscn).
## El −Z local mira cap a on mira el jugador i el +X local és el costat del pal
## (ref: stickPt(), desplaçament de 0,72 m endavant i 0,3 m de costat).
class_name PlayerView
extends Node3D

const HEIGHT := 1.75
const RADIUS := 0.3

static var _body_mesh: CapsuleMesh
static var _head_mesh: SphereMesh
static var _stick_mesh: BoxMesh


func setup(p: Player, def: TeamData) -> void:
	_ensure_meshes()
	name = "Jugador%d_%d" % [p.team.idx, p.num]
	var kit: Dictionary = def.gk_kit if p.is_gk else def.kit
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	body.material_override = _mat(Color(kit["shirt"]))
	add_child(body)
	# Franja amb el segon color (la meitat de dalt blanca de l'Iluro, el blau del Polo).
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = RADIUS * 1.02
	band_mesh.bottom_radius = RADIUS * 1.02
	band_mesh.height = 0.28
	band.mesh = band_mesh
	band.position = Vector3(0.0, HEIGHT * 0.66, 0.0)
	band.material_override = _mat(Color(kit["shirt2"]))
	add_child(band)
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh
	head.position = Vector3(0.0, HEIGHT + 0.12, 0.0)
	head.material_override = _mat(Color(Constants.SKINS[p.skin]))
	add_child(head)
	# Pal: de la mà fins al punt de control, a terra.
	var stick := MeshInstance3D.new()
	stick.mesh = _stick_mesh
	var hand := Vector3(0.22, 0.95, -0.15)
	var tip := Vector3(0.3, 0.05, -0.72)
	stick.basis = Basis.looking_at(tip - hand, Vector3.UP)
	stick.position = (hand + tip) * 0.5
	stick.material_override = _mat(Color("2a2118"))
	add_child(stick)
	var label := Label3D.new()
	label.text = str(p.num)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0004
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color.WHITE
	label.outline_modulate = Color(def.color).darkened(0.5)
	label.position = Vector3(0.0, HEIGHT + 0.55, 0.0)
	label.no_depth_test = true
	add_child(label)


static func _ensure_meshes() -> void:
	if _body_mesh:
		return
	_body_mesh = CapsuleMesh.new()
	_body_mesh.radius = RADIUS
	_body_mesh.height = HEIGHT
	_head_mesh = SphereMesh.new()
	_head_mesh.radius = 0.13
	_head_mesh.height = 0.26
	_stick_mesh = BoxMesh.new()
	# El llarg va en Z perquè look_at orienta el −Z cap a la punta.
	_stick_mesh.size = Vector3(0.04, 0.04, 1.08)


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m
