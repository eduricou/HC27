## Vista 3D del partit: jugadors i pilota (el camp i l'estadi són a scenes/stadium.tscn).
## Llegeix l'estat de la simulació a cada pas (després del MatchRunner) i interpola entre
## els dos últims passos a cada fotograma amb Engine.get_physics_interpolation_fraction(),
## per anar fluid a qualsevol fps.
## No canvia mai l'estat de la simulació.
class_name MatchView
extends Node3D

## Més gran que la real (0,037 m) perquè es vegi des de la càmera TV.
const BALL_RADIUS := 0.12
## Salts més grans que això en un pas són teletransports (represes, servei, repetició):
## no s'interpolen.
const SNAP_PLAYER := 2.0
const SNAP_BALL := 3.0

var runner: MatchRunner

var _views: Array[PlayerView] = []
var _ball: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mats: Array[StandardMaterial3D] = []
var _prev_pos := PackedVector3Array()
var _cur_pos := PackedVector3Array()
var _prev_yaw := PackedFloat32Array()
var _cur_yaw := PackedFloat32Array()
var _prev_ball := Vector3.ZERO
var _cur_ball := Vector3.ZERO
var _bound: Player
var _snap_next := true


func _ready() -> void:
	# Després del MatchRunner, que fa el pas de simulació.
	process_physics_priority = 10
	_ball = MeshInstance3D.new()
	_ball.name = "Pilota"
	var sm := SphereMesh.new()
	sm.radius = BALL_RADIUS
	sm.height = BALL_RADIUS * 2.0
	_ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("f6f2d8")
	bm.emission_enabled = true
	bm.emission = Color("f6f2d8")
	bm.emission_energy_multiplier = 0.25
	_ball.material_override = bm
	add_child(_ball)
	_ring = MeshInstance3D.new()
	_ring.name = "Controlat"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 0.85
	tm.rings = 32
	_ring.mesh = tm
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for hex: String in ["ffb066", "9fb6ff"]:
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(hex)
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mats.append(rm)
	_ring.visible = false
	add_child(_ring)


func _physics_process(_delta: float) -> void:
	capture()


## Copia l'estat actual de la simulació (el del pas anterior passa a ser «prev»).
func capture() -> void:
	if runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	if s.players.is_empty():
		return
	if s.players[0] != _bound:
		_bind(s)
	var n := s.players.size()
	for i in n:
		var p := s.players[i]
		_prev_pos[i] = _cur_pos[i]
		_prev_yaw[i] = _cur_yaw[i]
		_cur_pos[i] = Coords.to_view(p.x, p.y)
		_cur_yaw[i] = Coords.face_to_yaw(p.face)
	_prev_ball = _cur_ball
	var b := s.ball
	_cur_ball = Coords.to_view(b.x, b.y, b.z + BALL_RADIUS)
	if _snap_next:
		snap()


## Oblida el pas anterior: el proper fotograma mostra l'estat actual sense interpolar.
func snap() -> void:
	_snap_next = false
	_prev_pos = _cur_pos.duplicate()
	_prev_yaw = _cur_yaw.duplicate()
	_prev_ball = _cur_ball


func _process(_delta: float) -> void:
	_apply(Engine.get_physics_interpolation_fraction())


## Captura l'estat i el mostra tot seguit, sense interpolar (partit nou, captures).
func sync_now() -> void:
	capture()
	snap()
	_apply(1.0)


func _apply(f: float) -> void:
	if _views.is_empty():
		return
	for i in _views.size():
		var a := _prev_pos[i]
		var b := _cur_pos[i]
		var v := _views[i]
		v.position = b if a.distance_to(b) > SNAP_PLAYER else a.lerp(b, f)
		v.rotation.y = lerp_angle(_prev_yaw[i], _cur_yaw[i], f)
	if _prev_ball.distance_to(_cur_ball) > SNAP_BALL:
		_ball.position = _cur_ball
	else:
		_ball.position = _prev_ball.lerp(_cur_ball, f)
	_update_ring()


## Posició de la pilota que es veu ara (interpolada), en coordenades de la simulació.
func ball_sim_pos() -> Vector2:
	return Vector2(_ball.position.x, _ball.position.z)


## Posició que es veu ara del jugador `i`, en coordenades de la simulació.
func player_sim_pos(i: int) -> Vector2:
	if i < 0 or i >= _views.size():
		return Vector2.ZERO
	return Vector2(_views[i].position.x, _views[i].position.z)


func _update_ring() -> void:
	var s := runner.sim.s if runner and runner.sim else null
	var ctrl: Player = s.ctrl if s else null
	var show := ctrl != null and ctrl.team.human and s.mode == &"match"
	_ring.visible = show
	if show:
		var i := s.players.find(ctrl)
		_ring.position = _views[i].position + Vector3(0.0, 0.02, 0.0)
		_ring.material_override = _ring_mats[ctrl.team.idx]


## Crea les vistes dels jugadors la primera vegada; després només cal tornar a
## sincronitzar, perquè l'ordre dels jugadors (i, per tant, l'equipació) no canvia.
func _bind(s: MatchState) -> void:
	_bound = s.players[0]
	var n := s.players.size()
	if _views.size() != n:
		for v in _views:
			v.queue_free()
		_views.clear()
		for p in s.players:
			var v := PlayerView.new()
			v.setup(p, p.team.def)
			add_child(v)
			_views.append(v)
		_prev_pos.resize(n)
		_cur_pos.resize(n)
		_prev_yaw.resize(n)
		_cur_yaw.resize(n)
	_snap_next = true
