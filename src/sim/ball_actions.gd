## Accions sobre la pilota: tocar, guanyar-la, xutar, passar i fer entrades.
## ref: línies 370–437 de reference/web/index.html
class_name BallActions
extends RefCounted


## Punt del pal (on es controla la pilota) davant del jugador. Deixa el resultat a
## s.st_x i s.st_y. ref: stickPt()
static func stick_pt(s: MatchState, p: Player, f: float = 0.72, side: float = 0.3) -> void:
	var c := cos(p.face)
	var n := sin(p.face)
	s.st_x = p.x + c * f - n * side
	s.st_y = p.y + n * f + c * side


## Jugador de camp de l'equip t més proper a (x, y). ref: nearestTo()
static func nearest_to(t: Team, x: float, y: float, excl: Player = null) -> Player:
	var b: Player = null
	var bd := 1e9
	for p in t.players:
		if p.is_gk or p == excl:
			continue
		var dx := p.x - x
		var dy := p.y - y
		var d := sqrt(dx * dx + dy * dy)
		if d < bd:
			bd = d
			b = p
	return b


## Distància al rival més proper (porter inclòs). ref: nearestOppDist()
static func nearest_opp_dist(p: Player) -> float:
	var m := 99.0
	for o in p.team.opp.players:
		var dx := o.x - p.x
		var dy := o.y - p.y
		var d := sqrt(dx * dx + dy * dy)
		if d < m:
			m = d
	return m


## Registra un toc: qui l'ha tocada i si un gol seria vàlid. ref: touch()
static func touch(s: MatchState, p: Player) -> void:
	var ball := s.ball
	ball.last_touch = p
	ball.last_team = p.team
	ball.last_by[p.team.idx] = p
	if ball.pc_pending:
		return
	if Constants.in_circle(ball.x, ball.y, p.team.dir):
		ball.valid_for = p.team
	elif ball.valid_for == p.team:
		ball.valid_for = null


## Canvia el jugador controlat per l'humà. ref: setCtrl()
static func set_ctrl(s: MatchState, p: Player) -> void:
	if not p or p.is_gk:
		return
	s.ctrl = p
	p.has_plan = false


## El jugador p es queda la pilota. ref: gain()
static func gain(s: MatchState, p: Player) -> void:
	var ball := s.ball
	ball.owner = p
	ball.vx = p.vx
	ball.vy = p.vy
	ball.vz = 0.0
	ball.z = 0.0
	ball.pass_target = null
	p.recv_t = 0.0
	touch(s, p)
	p.hold_t = 0.0
	p.think_t = minf(p.think_t, 0.12 + s.rng.rand() * 0.18)
	if s.last_poss != p.team:
		s.last_poss = p.team
		on_poss_change(s, p.team)
	if p.team.human and s.ctrl != p and not p.is_gk:
		set_ctrl(s, p)


## Quan l'humà perd la pilota, passa a controlar el defensor més proper. ref: onPossChange()
static func on_poss_change(s: MatchState, t: Team) -> void:
	var h := s.human_team()
	if h and h != t and s.ctrl:
		var n := nearest_to(h, s.ball.x, s.ball.y)
		if n:
			set_ctrl(s, n)


## Colpeja la pilota. kind: &"pass", &"shot" o &"hit". ref: kick()
static func kick(
	s: MatchState, p: Player, ang: float, spd: float, vz: float, kind: StringName
) -> void:
	var ball := s.ball
	ball.owner = null
	ball.vx = cos(ang) * spd
	ball.vy = sin(ang) * spd
	ball.vz = vz
	if ball.vz > 0.0:
		ball.z = maxf(ball.z, 0.05)
	touch(s, p)
	p.kick_cd = 0.4
	p.swing = 0.24
	p.face = ang
	ball.pass_target = null
	if kind == &"shot":
		ball.shot_id += 1
		var side := p.team.dir
		if Constants.in_circle(ball.x, ball.y, side) and cos(ang) * side > 0.0:
			s.stat_shots[p.team.idx] += 1
			var t := (side * Constants.HL - ball.x) / ball.vx
			var y_at := ball.y + ball.vy * t
			if absf(y_at) < Constants.GHW:
				s.stat_on[p.team.idx] += 1
	s.emit({"type": &"kick", "player": p, "kind": kind, "speed": spd})


## Passada de p a q cap a (tx, ty), avançant-se al moviment del company. ref: passTo()
static func pass_to(
	s: MatchState,
	p: Player,
	q: Player,
	tx: float,
	ty: float,
	err_mul: float = 1.0,
	through: bool = false
) -> void:
	var ball := s.ball
	s.dbg["pass"] += 1
	var dx := tx - ball.x
	var dy := ty - ball.y
	var d := sqrt(dx * dx + dy * dy)
	var spd := clampf(7.0 + d * 0.55, 9.0, 22.0)
	var tt := d / (spd * 0.78)
	var lx := tx
	var ly := ty
	if q and not through:
		lx = q.x + q.vx * tt * 0.85
		ly = q.y + q.vy * tt * 0.85
	var ang := atan2(ly - ball.y, lx - ball.x)
	ang += s.rng.gauss() * (0.012 + (1.0 - p.pas / 100.0) * 0.07) * err_mul
	kick(s, p, ang, spd, 0.0, &"pass")
	if q:
		ball.pass_target = q
		q.recv_t = 1.6
		q.has_plan = false


## Entrada del defensor dp al conductor car. ref: tryTackle()
static func try_tackle(s: MatchState, dp: Player, car: Player) -> void:
	var ball := s.ball
	dp.tackle_cd = 0.85
	dp.swing = 0.25
	var rx := dp.x - car.x
	var ry := dp.y - car.y
	var rl := sqrt(rx * rx + ry * ry)
	if rl == 0.0:
		rl = 1.0
	var behind := (cos(car.face) * rx + sin(car.face) * ry) / rl < -0.4
	var dv := dp.ref if dp.is_gk else dp.dfn
	var ps := (
		0.4
		+ (dv - car.ctl) / 170.0
		+ (dp.team.df_tack - 1.0) * 0.15
		- (0.12 if behind else 0.0)
		+ (0.05 if dp.team.human else 0.0)
	)
	s.dbg["tack"] += 1
	if s.rng.rand() < clampf(ps, 0.12, 0.8):
		s.dbg["tack_win"] += 1
		car.stun = 0.45
		car.kick_cd = 0.5
		if s.rng.rand() < 0.6:
			gain(s, dp)
		else:
			ball.owner = null
			var a := dp.face + (s.rng.rand() - 0.5) * 1.4
			ball.vx = cos(a) * 5.0
			ball.vy = sin(a) * 5.0
			touch(s, dp)
		s.emit({"type": &"tackle", "player": dp, "won": true})
	else:
		dp.stun = 0.4
		var in_own := Constants.in_circle(car.x, car.y, -dp.team.dir)
		var foul_p := (0.5 if behind else 0.1) + (0.22 if in_own else 0.0)
		if s.rng.rand() < foul_p:
			Rules.foul(s, dp, car.x, car.y)
		else:
			s.emit({"type": &"tackle", "player": dp, "won": false})
