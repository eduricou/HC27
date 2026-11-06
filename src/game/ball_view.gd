## La pilota que es veu. Té la mida real (7,3 cm de diàmetre), però des de les càmeres de
## lluny es fa més gran perquè no sigui mai més petita que MIN_SCREEN a la pantalla. Roda
## segons com es mou (sense lliscar), a l'aire manté el gir que portava i fa una ombra de
## contacte a terra. La posició és la del centre; MatchView la col·loca a cada fotograma.
class_name BallView
extends Node3D

const RADIUS := 0.0365
## Diàmetre mínim a la pantalla, en fracció de l'alçada de la imatge (7 px a 1080p).
const MIN_SCREEN := 0.0065
## El gir a l'aire es perd a poc a poc (per segon).
const SPIN_DAMP := 0.4
const SHADER := preload("res://shaders/ball.gdshader")
const CONTACT_SHADER := preload("res://shaders/ball_contact.gdshader")

## Radi amb què es dibuixa ara (metres).
var radius := RADIUS
var mesh: MeshInstance3D
var _contact: MeshInstance3D
var _contact_mat: ShaderMaterial
var _spin := Quaternion.IDENTITY
## Gir per segon (eix per angle), per quan és a l'aire.
var _omega := Vector3.ZERO
var _last := Vector3.ZERO
var _placed := false


func _ready() -> void:
	mesh = MeshInstance3D.new()
	mesh.name = "Esfera"
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mesh.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = SHADER
	mesh.material_override = m
	add_child(mesh)
	_contact = MeshInstance3D.new()
	_contact.name = "Ombra"
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	_contact.mesh = q
	_contact_mat = ShaderMaterial.new()
	_contact_mat.shader = CONTACT_SHADER
	_contact.material_override = _contact_mat
	_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact)
	_apply_transform()


## Col·loca la pilota: `at` és el punt de sota (la posició de la simulació, amb l'alçada).
## Si `teleport`, ha saltat (represa, repetició) i no roda.
func place(at: Vector3, delta: float, teleport := false) -> void:
	radius = RADIUS * screen_scale(at)
	var center := at + Vector3(0.0, radius, 0.0)
	if teleport or not _placed:
		_omega = Vector3.ZERO
	else:
		_roll(center - _last, at.y, delta)
	_last = center
	_placed = true
	position = center
	_apply_transform()
	# L'ombra de contacte és a terra i s'esvaeix quan la pilota s'enlaira.
	_contact.position = Vector3(0.0, 0.004 - center.y, 0.0)
	_contact.scale = Vector3.ONE * radius * 3.0
	_contact_mat.set_shader_parameter("strength", 0.4 * clampf(1.0 - at.y / 0.25, 0.0, 1.0))


## Quantes vegades més gran que la real s'ha de dibuixar perquè la càmera actual la vegi
## com a mínim de MIN_SCREEN.
func screen_scale(at: Vector3) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 1.0
	var d := maxf(0.1, cam.global_position.distance_to(at))
	var frac := RADIUS / (d * tan(deg_to_rad(cam.fov) * 0.5))
	return maxf(1.0, MIN_SCREEN / frac)


## A terra roda sense lliscar (l'eix és perpendicular al moviment i l'angle, la distància
## entre el radi). A l'aire continua girant com girava.
func _roll(move: Vector3, height: float, delta: float) -> void:
	move.y = 0.0
	var dist := move.length()
	if height < 0.01:
		if dist > 1e-6:
			var axis := Vector3.UP.cross(move / dist)
			var ang := dist / radius
			_spin = Quaternion(axis, ang) * _spin
			_omega = axis * (ang / delta) if delta > 0.0 else Vector3.ZERO
		else:
			_omega = Vector3.ZERO
	elif delta > 0.0 and _omega.length_squared() > 1e-8:
		var w := _omega.length()
		_spin = Quaternion(_omega / w, w * delta) * _spin
		_omega *= exp(-delta * SPIN_DAMP)
	_spin = _spin.normalized()


func _apply_transform() -> void:
	mesh.transform = Transform3D(Basis(_spin).scaled(Vector3.ONE * radius), Vector3.ZERO)
