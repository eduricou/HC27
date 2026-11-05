## IA del porter: aturades, sortides, col·locació i treure la pilota.
## ref: línies 729–778 de reference/web/index.html
class_name AiGk
extends RefCounted

const HL := Constants.HL
const GHW := Constants.GHW


## Intent d'aturada si la pilota va cap a porteria i és a l'abast. ref: trySave()
static func try_save(s: MatchState, p: Player) -> void:
	var ball := s.ball
	if ball.owner or p.save_cd > 0.0 or p.last_shot == ball.shot_id:
		return
	var side := -p.team.dir
	if ball.vx * side <= 0.0:
		return
	var sp := sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
	if sp < 6.0:
		return
	var reach := 0.9 + p.ref / 100.0 * 0.75
	var dx := ball.x - p.x
	var dy := ball.y - p.y
	var d := sqrt(dx * dx + dy * dy)
	if d > reach or ball.z > 2.0:
		return
	p.last_shot = ball.shot_id
	var ps := clampf(
		(
			0.72
			+ (p.ref - 75.0) / 100.0
			+ p.team.df_gk
			- (sp - 22.0) * 0.018
			- (d / reach) * 0.25
			- (0.08 if ball.z > 0.9 else 0.0)
		),
		0.12,
		0.94
	)
	var rng := s.rng
	if rng.rand() < ps:
		var out := -side
		ball.vx = absf(ball.vx) * 0.28 * out + out * 2.0
		var sgn := -1.0 if rng.rand() < 0.5 else 1.0
		ball.vy = ball.vy * 0.3 + sgn * (3.0 + rng.rand() * 6.0)
		ball.vz = rng.rand() * 2.5
		ball.z = maxf(ball.z, 0.1)
		BallActions.touch(s, p)
		p.kick_cd = 0.5
		p.save_cd = 0.4
		p.swing = 0.3
		s.emit({"type": &"save", "player": p})
	else:
		p.save_cd = 0.5


## IA del porter. ref: aiGK()
static func ai_gk(s: MatchState, p: Player, dt: float) -> void:
	var ball := s.ball
	var t := p.team
	var side := -t.dir
	var gx := side * HL
	var inward := t.dir
	if s.state == &"goal" or s.state == &"restart":
		Movement.move_toward(s, p, gx + inward * 1.0, 0.0, 0.5, dt, 1.0)
		return
	if ball.owner == p:
		p.hold_t += dt
		Movement.accel_to(p, 0.0, 0.0, dt)
		if p.hold_t > 0.5:
			if Ai.best_pass(s, p) and s.bp_score > 1.0:
				BallActions.pass_to(s, p, s.bp_q, s.bp_tx, s.bp_ty)
			else:
				var a := atan2((1.0 if p.y >= 0.0 else -1.0) * 16.0 - p.y, inward * 25.0)
				BallActions.kick(s, p, a, 21.0, 0.8, &"hit")
		return
	var sp := sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
	var bgx := ball.x - gx
	var bd := sqrt(bgx * bgx + ball.y * ball.y)
	if not ball.owner and ball.vx * side > 2.0 and sp > 7.0 and bd < 30.0:
		var line_x := gx + inward * 0.7
		var tt := (line_x - ball.x) / ball.vx
		if tt > 0.0:
			var y_at := ball.y + ball.vy * tt
			if absf(y_at) < GHW + 1.2:
				var ty := clampf(y_at, -GHW - 0.3, GHW + 0.3)
				Movement.move_toward(s, p, line_x, ty, 1.3, dt, 0.3)
				try_save(s, p)
				return
	if not ball.owner and Constants.in_circle(ball.x, ball.y, side) and bd < 9.0:
		var mx := ball.x - p.x
		var my_y := ball.y - p.y
		var my := sqrt(mx * mx + my_y * my_y)
		var od := 99.0
		for o in t.opp.players:
			var ox := ball.x - o.x
			var oy := ball.y - o.y
			var d := sqrt(ox * ox + oy * oy)
			if d < od:
				od = d
		if my < od * 0.9 or my < 2.5:
			Movement.move_toward(s, p, ball.x, ball.y, 1.1, dt, 0.2)
			return
	if (
		ball.owner
		and ball.owner.team != t
		and Constants.in_circle(ball.x, ball.y, side)
		and bd < 7.0
	):
		Movement.move_toward(s, p, ball.x + (gx - ball.x) * 0.35, ball.y * 0.65, 1.0, dt, 0.4)
		var cx := ball.x - p.x
		var cy := ball.y - p.y
		if sqrt(cx * cx + cy * cy) < 1.6 and p.tackle_cd <= 0.0 and s.rng.rand() < dt * 2.5:
			BallActions.try_tackle(s, p, ball.owner)
		return
	var a := atan2(ball.y, ball.x - gx)
	var dd := clampf(bd * 0.1, 0.6, 3.2)
	var tx := gx + cos(a) * dd
	var ty := sin(a) * dd
	if (tx - gx) * inward < 0.4:
		tx = gx + inward * 0.4
	ty = clampf(ty, -GHW - 0.6, GHW + 0.6)
	Movement.move_toward(s, p, tx, ty, 0.8, dt, 0.6)
	try_save(s, p)
