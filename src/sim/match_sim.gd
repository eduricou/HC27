## Simulació d'un partit, sense gràfics: el bucle de pas fix, els jugadors, la pilota i la
## recollida. És el punt d'entrada de la capa de joc i de tools/sim_stats.gd.
## ref: línies 870–1031 de reference/web/index.html (update() i companyia)
class_name MatchSim
extends RefCounted

const HL := Constants.HL
const GHW := Constants.GHW
## Límit de passos de run_to_end() (molt per sobre d'un partit normal).
const MAX_STEPS := 2_000_000

var s: MatchState


## seed_value: llavor de l'atzar. qlen: durada real de cada quart (s).
## side: equip humà (0 Iluro, 1 Polo) o −1 per a CPU contra CPU. mode: &"match" o &"demo".
func _init(
	seed_value: int = 0,
	qlen: float = 150.0,
	side: int = -1,
	diff: String = "normal",
	mode: StringName = &"match"
) -> void:
	s = MatchState.new(seed_value)
	s.new_game(mode, side, diff, qlen)


## Avança un pas fix. La capa de joc omple s.input abans de cridar-lo. ref: update()
func step(dt: float = Constants.STEP) -> void:
	update(s, dt)
	s.input.clear_edges()


## Després del descans, comença el quart següent. ref: nextQuarter()
func next_quarter() -> void:
	if s.state == &"break":
		Rules.next_quarter(s)


## Simula fins al xiulet final, com window.__estic.simulate(). ref: simulate()
func run_to_end() -> Dictionary:
	for i in MAX_STEPS:
		if s.state == &"break":
			Rules.next_quarter(s)
		if s.state == &"full":
			break
		step()
	return result()


## Marcador i estadístiques, en el format de la web.
func result() -> Dictionary:
	return {
		"score": [s.score[0], s.score[1]],
		"quarter": s.quarter,
		"state": String(s.state),
		"stats": s.stats_dict(),
	}


## Allibera les referències circulars de l'estat. Crida-ho quan ja no el necessitis.
func dispose() -> void:
	s.dispose()


## Un pas de simulació. ref: update()
static func update(s: MatchState, dt: float) -> void:
	s.events.clear()
	s.time += dt
	var inp := s.input
	if s.intro_t > 0.0:
		s.intro_t -= dt
		if inp.pass_e or inp.shoot_e or inp.tap_e or (s.mode == &"match" and inp.mv.length() > 0.5):
			s.intro_t = 0.0
		if s.intro_t <= 0.0:
			s.intro_t = 0.0
			s.emit({"type": &"intro_end"})
			s.emit({"type": &"whistle", "strength": 0.5, "count": 1})
		return
	for p in s.players:
		p.kick_cd -= dt
		p.tackle_cd -= dt
		p.stun -= dt
		p.swing -= dt
		p.recv_t -= dt
		p.save_cd -= dt
	var st := s.state
	var ball := s.ball
	if st == &"play":
		Ai.assign_roles(s)
		update_players(s, dt)
		update_ball(s, dt)
		if s.state == &"play":
			Rules.check_bounds(s)
		if s.state == &"play":
			pickup(s)
		if s.state == &"play":
			if ball.pc_pending:
				var pc_dir := s.pc_team.dir if s.pc_team else 1
				if not Constants.in_circle(ball.x, ball.y, pc_dir):
					ball.pc_pending = false
			if ball.valid_for and not Constants.in_circle(ball.x, ball.y, ball.valid_for.dir):
				ball.valid_for = null
			if s.pc_live:
				s.pc_t += dt
				if (
					s.pc_t > 8.0
					or (
						not ball.pc_pending
						and not Constants.in_circle(
							ball.x, ball.y, s.pc_team.dir, Constants.DR + 2.0
						)
					)
				):
					s.pc_live = false
			if ball.owner:
				s.stat_poss[ball.owner.team.idx] += dt
			HumanControl.auto_switch(s, dt)
		Rules.tick_clock(s, dt)
	elif st == &"restart":
		s.state_t += dt
		update_players(s, dt)
		Rules.update_restart(s, dt)
		if s.restart_type != &"center":
			Rules.tick_clock(s, dt)
	elif st == &"pc":
		Rules.update_pc(s, dt)
	elif st == &"goal":
		s.state_t += dt
		update_players(s, dt)
		if absf(ball.x) > HL:
			# La pilota és dins de la porteria: frena contra la xarxa.
			var sd := 1.0 if ball.x > 0.0 else -1.0
			ball.vx *= 0.85
			ball.vy *= 0.85
			ball.vz = 0.0
			ball.z = maxf(0.0, ball.z - dt * 2.0)
			if absf(ball.x) > HL + Constants.GD - 0.15:
				ball.x = sd * (HL + Constants.GD - 0.15)
				ball.vx = 0.0
			ball.y = clampf(ball.y, -GHW + 0.1, GHW - 0.1)
			ball.x += ball.vx * dt
			ball.y += ball.vy * dt
		else:
			update_ball(s, dt)
		if s.state_t > 2.7 and not s.wiped:
			s.wiped = true
			s.emit({"type": &"wipe", "team": s.scorer.team.idx})
		if s.state_t > 3.05:
			if s.replay_len > 60:
				s.state = &"replay"
				s.rp_i = 0.0
				s.rp_end = 0.0
				apply_replay(s)
				s.emit({"type": &"replay_start"})
			else:
				kickoff_after_goal(s)
	elif st == &"replay":
		if s.rp_end == 0.0:
			var prev_x := ball.x
			s.rp_i += 0.5
			apply_replay(s)
			if absf(prev_x) <= HL and absf(ball.x) > HL and absf(ball.y) < GHW:
				s.emit({"type": &"net", "side": 1 if ball.x > 0.0 else -1, "y": ball.y})
			if s.rp_i >= s.replay_len - 1 or inp.pass_e or inp.shoot_e or inp.tap_e:
				s.rp_end = s.time
				s.emit({"type": &"wipe", "team": s.scorer.team.idx})
		if s.rp_end != 0.0 and s.time - s.rp_end > 0.36:
			s.replay = []
			s.emit({"type": &"replay_end"})
			kickoff_after_goal(s)
	if st == &"play" or st == &"restart" or st == &"pc":
		s.rec.record(s.players, ball)
	if (
		s.end_pending
		and not s.pc_live
		and s.state != &"pc"
		and (s.state == &"play" or s.state == &"restart")
	):
		Rules.end_quarter(s)


## Posa jugadors i pilota al fotograma s.rp_i de la repetició (interpolant entre dos).
## Com a la web, la repetició es mostra amb el mateix estat de la simulació; el servei de
## centre posterior ho torna a col·locar tot, excepte el cicle d'animació (anim).
## ref: applyReplay()
static func apply_replay(s: MatchState) -> void:
	var rp := s.replay
	if rp.is_empty():
		return
	var last := rp.size() - 1
	var fl := floorf(s.rp_i)
	var i0 := mini(last, int(fl))
	var i1 := mini(last, i0 + 1)
	var t := s.rp_i - fl
	var a := rp[i0]
	var b := rp[i1]
	for i in s.players.size():
		var p := s.players[i]
		var k := i * 4
		p.x = lerpf(a[k], b[k], t)
		p.y = lerpf(a[k + 1], b[k + 1], t)
		p.face = a[k + 2] + Constants.ang_diff(a[k + 2], b[k + 2]) * t
		p.moving = a[k + 3] >= 0.0
		if p.moving:
			p.anim = lerpf(a[k + 3], b[k + 3], t) if b[k + 3] >= 0.0 else a[k + 3]
		p.swing = 0.0
	var n := s.players.size() * 4
	var ball := s.ball
	ball.owner = null
	var nx := lerpf(a[n], b[n], t)
	var ny := lerpf(a[n + 1], b[n + 1], t)
	ball.vx = (nx - ball.x) * 60.0
	ball.vy = (ny - ball.y) * 60.0
	ball.x = nx
	ball.y = ny
	ball.z = lerpf(a[n + 2], b[n + 2], t)


## ref: kickoffAfterGoal()
static func kickoff_after_goal(s: MatchState) -> void:
	s.wiped = false
	Rules.kickoff(s, s.next_center)


## Decisions i moviment de tots els jugadors. ref: updatePlayers()
static func update_players(s: MatchState, dt: float) -> void:
	var ball := s.ball
	# predictTraj(): la trajectòria es calcula quan cal, però sempre a partir d'aquest estat.
	s.traj_bx = ball.x
	s.traj_by = ball.y
	s.traj_bvx = ball.vx
	s.traj_bvy = ball.vy
	s.traj_dirty = true
	s.traj_ready = true
	var in_restart := s.state == &"restart"
	var taker: Player = s.restart_taker if in_restart else null
	for p in s.players:
		p.lock_face = false
		if p == taker:
			p.vx = 0.0
			p.vy = 0.0
			p.lock_face = true
			continue
		if p.stun > 0.0:
			Movement.accel_to(p, 0.0, 0.0, dt)
			continue
		var human := s.ctrl == p and p.team.human and (s.state == &"play" or s.state == &"restart")
		if human:
			if s.state == &"play":
				HumanControl.human_update(s, p, dt)
			else:
				var mv := s.input.mv
				var v := p.max_speed * Movement.mods(s, p)
				Movement.accel_to(p, mv.x * v, mv.y * v, dt)
		elif p.is_gk:
			AiGk.ai_gk(s, p, dt)
		elif ball.owner == p:
			Ai.ai_carrier(s, p, dt)
		else:
			Ai.ai_field(s, p, dt)
	for p in s.players:
		Movement.integrate(s, p, dt)
	Movement.collide(s)
	if taker:
		Rules.place_taker(taker, ball.x, ball.y, taker.face)
		for p in s.other(s.restart_team).players:
			var dx := p.x - ball.x
			var dy := p.y - ball.y
			var d := sqrt(dx * dx + dy * dy)
			if d < 5.0 and d > 0.01:
				p.x = ball.x + dx / d * 5.0
				p.y = ball.y + dy / d * 5.0


## Física de la pilota: conducció, bot, fregament i pals. ref: updateBall()
static func update_ball(s: MatchState, dt: float) -> void:
	var ball := s.ball
	if ball.owner:
		var o := ball.owner
		BallActions.stick_pt(s, o, 0.72 + sin(o.anim * 1.3) * 0.06)
		var k := minf(1.0, dt * 20.0)
		ball.x += (s.st_x - ball.x) * k
		ball.y += (s.st_y - ball.y) * k
		ball.vx = o.vx
		ball.vy = o.vy
		ball.z = 0.0
		ball.vz = 0.0
		BallActions.touch(s, o)
		return
	if ball.z > 0.0 or ball.vz > 0.0:
		ball.vz -= 9.8 * dt
		ball.z += ball.vz * dt
		if ball.z <= 0.0:
			ball.z = 0.0
			ball.vz = -ball.vz * 0.35 if ball.vz < -1.5 else 0.0
	var sp := sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
	if sp > 0.0:
		var dec := (0.12 * sp if ball.z > 0.05 else 1.5 + 0.32 * sp) * dt
		var ns := maxf(0.0, sp - dec)
		ball.vx *= ns / sp
		ball.vy *= ns / sp
	ball.x += ball.vx * dt
	ball.y += ball.vy * dt
	# Pals: només si la pilota és a prop d'una línia de fons.
	if absf(absf(ball.x) - HL) < 0.11:
		for sd in [-1.0, 1.0]:
			for py in [-GHW, GHW]:
				var dx: float = ball.x - sd * HL
				var dy: float = ball.y - py
				var d := sqrt(dx * dx + dy * dy)
				if d < 0.11 and ball.z < Constants.GH:
					var nx := dx / d
					var ny := dy / d
					var dot := ball.vx * nx + ball.vy * ny
					if dot < 0.0:
						ball.vx -= 1.6 * dot * nx
						ball.vy -= 1.6 * dot * ny
						ball.x = sd * HL + nx * 0.11
						ball.y = py + ny * 0.11
						s.emit({"type": &"post"})


## Algú recull la pilota lliure: control, desviació o peu. ref: pickup()
static func pickup(s: MatchState) -> void:
	var ball := s.ball
	if ball.owner:
		return
	var sp := sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
	var best: Player = null
	var bd := 1e9
	for p in s.players:
		if p.kick_cd > 0.0 or p.stun > 0.0 or (p.is_gk and p.save_cd > 0.0):
			continue
		var bx := ball.x - p.x
		var by := ball.y - p.y
		var body2 := bx * bx + by * by
		# El pal és a 0,78 m del cos com a molt: més enllà de 2,1 m ningú no hi arriba.
		if body2 > 4.41:
			continue
		BallActions.stick_pt(s, p)
		var sx := ball.x - s.st_x
		var sy := ball.y - s.st_y
		var d := minf(sqrt(sx * sx + sy * sy), sqrt(body2) * 1.15)
		var reach := 1.25 if p.is_gk else 0.85
		var max_z := 1.7 if p.is_gk else 0.55
		if d < reach and ball.z < max_z and d < bd:
			best = p
			bd = d
	if not best:
		return
	var p := best
	var own_side := -p.team.dir
	if (
		p.is_gk
		and sp > 9.0
		and ball.vx * own_side > 0.0
		and Constants.in_circle(ball.x, ball.y, own_side)
	):
		AiGk.try_save(s, p)
		return
	if s.pc_live and ball.pc_pending and p.team == s.pc_team and p != s.pc_hit:
		return
	if (
		not p.is_gk
		and sp > 6.0
		and ball.last_team
		and ball.last_team != p.team
		and Constants.in_circle(ball.x, ball.y, own_side)
		and s.rng.rand() < 0.3
	):
		s.stat_fouls[p.team.idx] += 1
		s.emit({"type": &"whistle", "strength": 0.28, "count": 1})
		Rules.setup_pc(s, p.team.opp, ball.y, &"foot", p)
		return
	var rvx := ball.vx - p.vx
	var rvy := ball.vy - p.vy
	var rel := sqrt(rvx * rvx + rvy * rvy)
	if rel < (12.0 + p.ref / 10.0 if p.is_gk else 8.0 + p.ctl / 10.0):
		BallActions.gain(s, p)
		s.emit({"type": &"control", "player": p})
	else:
		var a := atan2(ball.vy, ball.vx) + (s.rng.rand() - 0.5) * 1.6
		var sp2 := sp * 0.4
		ball.vx = cos(a) * sp2
		ball.vy = sin(a) * sp2
		BallActions.touch(s, p)
		p.kick_cd = 0.25
		s.emit({"type": &"deflect", "player": p})
