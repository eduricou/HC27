## Jugador humà automàtic per a les proves (escenari smoke_human): genera entrada com si
## algú jugués amb el teclat, perquè es provi tot el camí de control humà sense ningú.
## Fa servir el seu propi atzar: no toca el de la simulació.
class_name Autopilot
extends RefCounted

var _rng := RandomNumberGenerator.new()
var _hold := 0.0


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func drive(s: MatchState, inp: SimInput) -> void:
	inp.clear_edges()
	inp.sprint = false
	var p := s.ctrl
	if p == null:
		inp.mv = Vector2.ZERO
		return
	var ball := s.ball
	var tx := ball.x
	var ty := ball.y
	if ball.owner == p:
		tx = p.team.dir * Constants.HL
		ty = 0.0
	var dir := Vector2(tx - p.x, ty - p.y)
	inp.mv = dir.normalized() if dir.length() > 0.5 else Vector2.ZERO
	inp.sprint = _rng.randf() < 0.3
	# Represes, penals córner, presentació i repetició: de tant en tant prem PASSA.
	if s.state != &"play" or ball.owner != p:
		inp.pass_e = _rng.randf() < 0.03
		inp.shoot_e = ball.owner != null and ball.owner.team != p.team and _rng.randf() < 0.05
		inp.shoot_held = false
		_hold = 0.0
		return
	# Amb la pilota: passa de tant en tant; a prop de la porteria, carrega i xuta.
	var dg := absf(p.team.dir * Constants.HL - p.x)
	if dg < 18.0:
		_hold += Constants.STEP
		inp.shoot_held = _hold < 0.5
		inp.shoot_up_e = _hold >= 0.5
		if _hold >= 0.5:
			_hold = 0.0
	else:
		inp.shoot_held = false
		inp.pass_e = _rng.randf() < 0.02
