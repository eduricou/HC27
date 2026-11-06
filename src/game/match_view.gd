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


func _process(delta: float) -> void:
	_apply(Engine.get_physics_interpolation_fraction(), delta)


## Captura l'estat i el mostra tot seguit, sense interpolar (partit nou, captures).
func sync_now() -> void:
	capture()
	snap()
	_apply(1.0)


func _apply(f: float, delta: float = 0.0) -> void:
	if _views.is_empty():
		return
	var s := runner.sim.s if runner and runner.sim else null
	for i in _views.size():
		var a := _prev_pos[i]
		var b := _cur_pos[i]
		var v := _views[i]
		var jump := a.distance_to(b) > SNAP_PLAYER
		v.position = b if jump else a.lerp(b, f)
		v.rotation.y = lerp_angle(_prev_yaw[i], _cur_yaw[i], f)
		if s and i < s.players.size():
			# Velocitat vista entre els dos últims passos (també a la repetició).
			var speed := 0.0 if jump else a.distance_to(b) / Constants.STEP
			v.animate(s.players[i], speed, delta)
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


## Crea les vistes dels jugadors de cada partit nou (la pell, el cabell i el pentinat
## canvien d'un partit a l'altre).
## Jugadors del partit nou. Si són els mateixos que els de l'anterior (sempre ho són: les
## plantilles són fixes), es reaprofiten: muntar-ne 22 de nous i alliberar els vells feia
## una estrebada de 10–20 ms en començar el partit i en tornar al menú (fase 7).
func _bind(s: MatchState) -> void:
	_bound = s.players[0]
	var n := s.players.size()
	if _same_players(s):
		for v in _views:
			v.reset()
	else:
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


func _same_players(s: MatchState) -> bool:
	if _views.size() != s.players.size():
		return false
	for i in _views.size():
		if _views[i].key != PlayerView.key_of(s.players[i]):
			return false
	return true


## Accions dels jugadors a partir dels esdeveniments d'un pas de simulació: el golejador
## ho celebra, el porter que l'encaixa protesta, el porter que atura s'estira, qui fa una
## entrada s'hi llança i qui fa falta protesta. ref: drawPlayer() (cele) i drawGoal3D()
func on_events(events: Array[Dictionary]) -> void:
	if _views.is_empty() or runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	for e in events:
		match e["type"]:
			&"goal":
				_trigger(s, e.get("scorer"), &"celebrate")
				var conceding: Team = s.teams[1 - int(e["team"])]
				for p in conceding.players:
					if p.is_gk:
						_trigger(s, p, &"protest")
			&"save":
				_trigger(s, e.get("player"), &"dive")
			&"tackle":
				_trigger(s, e.get("player"), &"lunge", false)
			&"restart":
				if e.get("reason") == &"foul":
					_trigger(s, e.get("by"), &"protest")


## Tots els jugadors fan l'acció (escenari views, per revisar animacions).
func trigger_all(action: StringName) -> void:
	for v in _views:
		v.trigger(action)


func _trigger(s: MatchState, p: Player, action: StringName, hands_free: bool = true) -> void:
	if p == null:
		return
	var i := s.players.find(p)
	if i >= 0 and i < _views.size():
		_views[i].trigger(action, hands_free)
