## Com afecta l'entrada humana (SimInput) al jugador controlat: passar, apuntar, xutar,
## fer entrades i canviar de jugador. Va dins de la simulació perquè sigui determinista;
## la capa de joc només omple SimInput (vegeu docs/decisions/0002).
## ref: línies 807–868 de reference/web/index.html
class_name HumanControl
extends RefCounted

const HL := Constants.HL


## ref: humanPass()
static func human_pass(s: MatchState, p: Player) -> void:
	var mv := s.input.mv
	var ax := float(mv.x)
	var ay := float(mv.y)
	if sqrt(ax * ax + ay * ay) < 0.3:
		if Ai.best_pass(s, p):
			var q := s.bp_q
			BallActions.pass_to(s, p, q, s.bp_tx, s.bp_ty, 1.0, s.bp_through)
			BallActions.set_ctrl(s, q)
			return
		ax = cos(p.face)
		ay = sin(p.face)
	var a0 := atan2(ay, ax)
	var best: Player = null
	var bs := -1e9
	for q in p.team.players:
		if q == p or q.is_gk:
			continue
		var dx := q.x - p.x
		var dy := q.y - p.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 2.0 or d > 45.0:
			continue
		var da := absf(Constants.ang_diff(a0, atan2(dy, dx)))
		if da > 0.9:
			continue
		var sc := cos(da) * 3.0 - d * 0.045
		if sc > bs:
			bs = sc
			best = q
	if best:
		BallActions.pass_to(s, p, best, best.x, best.y, 1.0)
		BallActions.set_ctrl(s, best)
	else:
		BallActions.kick(s, p, a0, 15.0, 0.0, &"pass")


## Angle de xut: a porteria si és a prop, si no cap on apunta el jugador. ref: humanAim()
static func human_aim(s: MatchState, p: Player) -> float:
	var d := p.team.dir
	var gx := d * HL
	var mv := s.input.mv
	var mag := mv.length()
	var dg := sqrt((gx - p.x) * (gx - p.x) + p.y * p.y)
	if dg < 32.0 and (mag < 0.25 or mv.x * d > -0.2):
		var ty := 0.0
		if mag > 0.25:
			ty = clampf(mv.y, -1.0, 1.0) * 1.55
		else:
			ty = -(1.0 if p.y >= 0.0 else -1.0) * 0.9
		return atan2(ty - s.ball.y, gx - s.ball.x)
	return atan2(mv.y, mv.x) if mag > 0.25 else p.face


## Xut carregat (power de 0 a 1). ref: humanShoot()
static func human_shoot(s: MatchState, p: Player, power: float) -> void:
	var ang := human_aim(s, p)
	ang += s.rng.gauss() * (0.015 + (1.0 - p.sho / 100.0) * 0.06 + power * power * 0.035)
	var vz := (power - 0.55) * 7.0 if power > 0.55 else 0.3
	BallActions.kick(s, p, ang, 13.0 + power * 19.0, vz, &"shot")


## Entrada o estirada cap a la pilota. ref: humanTackle()
static func human_tackle(s: MatchState, p: Player) -> void:
	var ball := s.ball
	var own := ball.owner
	var dx := ball.x - p.x
	var dy := ball.y - p.y
	var d := sqrt(dx * dx + dy * dy)
	if own and own.team != p.team:
		if d < 1.9 and p.tackle_cd <= 0.0:
			BallActions.try_tackle(s, p, own)
	elif not own:
		if d < 3.0 and d > 0.01:
			p.vx += dx / d * 3.0
			p.vy += dy / d * 3.0


## Passa el control al company més proper a la pilota. ref: switchPlayer()
static func switch_player(s: MatchState) -> void:
	var t := s.ctrl.team
	var n := BallActions.nearest_to(t, s.ball.x, s.ball.y, s.ctrl)
	if n:
		BallActions.set_ctrl(s, n)
		s.emit({"type": &"switch", "player": n})


## Moviment i accions del jugador controlat durant el joc. ref: humanUpdate()
static func human_update(s: MatchState, p: Player, dt: float) -> void:
	var ball := s.ball
	var inp := s.input
	var mv := inp.mv
	var mag := mv.length()
	var has := ball.owner == p
	if mag < 0.2 and not has and not ball.owner and ball.pass_target == p:
		Ai.intercept_t(s, p)
		Movement.move_toward(s, p, s.icpt_x, s.icpt_y, 1.0, dt, 0.8)
	else:
		var sprint := inp.sprint and p.stamina > 0.08 and mag > 0.2
		var vmax := p.max_speed * (1.22 if sprint else 1.0) * Movement.mods(s, p)
		Movement.accel_to(p, mv.x * vmax, mv.y * vmax, dt)
		if sprint:
			p.stamina = maxf(0.0, p.stamina - dt * 0.16 * (1.25 - p.sta / 100.0))
		if has and mag > 0.2 and sqrt(p.vx * p.vx + p.vy * p.vy) < 0.6:
			p.face += Constants.ang_diff(p.face, atan2(mv.y, mv.x)) * minf(1.0, dt * 10.0)
	if has:
		if inp.pass_e:
			human_pass(s, p)
			s.charge = 0.0
			return
		if inp.shoot_held and not s.shoot_consumed:
			s.charge = minf(1.0, s.charge + dt / 0.85)
		if inp.shoot_up_e and s.charge > 0.0 and not s.shoot_consumed:
			human_shoot(s, p, s.charge)
			s.charge = 0.0
	else:
		s.charge = 0.0
		if inp.pass_e:
			switch_player(s)
		if inp.shoot_e:
			s.shoot_consumed = true
			human_tackle(s, p)
	if not inp.shoot_held and not inp.shoot_up_e:
		s.shoot_consumed = false


## Canvi automàtic al jugador més proper quan el controlat queda lluny. ref: autoSwitch()
static func auto_switch(s: MatchState, dt: float) -> void:
	var h := s.human_team()
	if not h or not s.ctrl:
		return
	s.switch_t -= dt
	if s.switch_t > 0.0:
		return
	s.switch_t = 0.4
	var ball := s.ball
	if ball.owner and ball.owner.team == h:
		return
	if ball.pass_target and ball.pass_target.team == h:
		return
	var n := BallActions.nearest_to(h, ball.x, ball.y)
	if not n or n == s.ctrl:
		return
	var cx := s.ctrl.x - ball.x
	var cy := s.ctrl.y - ball.y
	var nx := n.x - ball.x
	var ny := n.y - ball.y
	if sqrt(cx * cx + cy * cy) - sqrt(nx * nx + ny * ny) > 9.0:
		BallActions.set_ctrl(s, n)
