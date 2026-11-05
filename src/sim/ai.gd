## IA dels jugadors de camp: posicions, marcatge, suport, rols, passades, conducció i xut.
## ref: línies 546–728 de reference/web/index.html
class_name Ai
extends RefCounted

const HL := Constants.HL
const HW := Constants.HW
const TRAJ_POINTS := 23


## Posició base segons el rol, la pilota i qui té la possessió. Deixa el resultat a
## s.out_x i s.out_y. ref: basePos()
static func base_pos(s: MatchState, p: Player) -> void:
	var t := p.team
	var d := t.dir
	var ball := s.ball
	var b_a := ball.x * d
	var by := ball.y
	var att := (ball.owner.team if ball.owner else s.last_poss) == t
	var role := p.role
	var push := -4.0
	if att:
		push = 7.0 if role == Player.DF else (9.0 if role == Player.MF else 12.0)
	var x := p.slot_x * 31.0 + b_a * 0.55 + push
	var y := p.slot_y * HW * 0.8 + by * (0.25 if att else 0.4)
	if role == Player.DF:
		x = clampf(x, -HL + 5.0, 10.0 if att else 0.0)
	elif role == Player.MF:
		x = clampf(x, -HL + 10.0, HL - 12.0)
	else:
		x = clampf(x, -HL * 0.35, HL - 6.5)
	s.out_x = x * d
	s.out_y = clampf(y, -HW + 2.0, HW - 2.0)


## Marcatge: entre el rival més proper a la posició base i la pròpia porteria.
## Deixa el resultat a s.out_x i s.out_y. ref: markPos()
static func mark_pos(s: MatchState, p: Player) -> void:
	base_pos(s, p)
	if p.role == Player.FW:
		return
	var bx := s.out_x
	var by := s.out_y
	var t := p.team
	var ogx := -t.dir * HL
	var best: Player = null
	var bd := 10.0
	for o in t.opp.players:
		if o.is_gk or o == s.ball.owner:
			continue
		var dx := o.x - bx
		var dy := o.y - by
		var d := sqrt(dx * dx + dy * dy)
		if d < bd:
			bd = d
			best = o
	if not best:
		return
	var gx := ogx - best.x
	var gy := -best.y
	var gl := sqrt(gx * gx + gy * gy)
	if gl == 0.0:
		gl = 1.0
	var mx := best.x + gx / gl * 1.7
	var my := best.y + gy / gl * 1.7
	s.out_x = lerpf(bx, mx, 0.55)
	s.out_y = lerpf(by, my, 0.55)


## Desmarcatge en atac: posició base més una carrera aleatòria, lluny del conductor.
## Deixa el resultat a s.out_x i s.out_y. ref: supportPos()
static func support_pos(s: MatchState, p: Player, dt: float) -> void:
	base_pos(s, p)
	var bx := s.out_x
	var by := s.out_y
	p.run_t -= dt
	if p.run_t <= 0.0:
		p.run_t = 1.8 + s.rng.rand() * 2.2
		p.run_x = (s.rng.rand() - 0.3) * 8.0 * p.team.dir
		p.run_y = (s.rng.rand() - 0.5) * 9.0
	var x := bx + p.run_x
	var y := clampf(by + p.run_y, -HW + 1.5, HW - 1.5)
	var c := s.ball.owner
	if c:
		var dx := x - c.x
		var dy := y - c.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 7.0 and d > 0.01:
			x = c.x + dx / d * 7.0
			y = c.y + dy / d * 7.0
	s.out_x = clampf(x, -HL + 2.0, HL - 2.0)
	s.out_y = clampf(y, -HW + 1.5, HW - 1.5)


## Posicions futures de la pilota cada 0,1 s (23 punts), a partir de l'estat de la
## pilota que es va desar a l'inici de l'últim update_players(). ref: predictTraj()
static func ensure_traj(s: MatchState) -> void:
	if not s.traj_dirty:
		return
	s.traj_dirty = false
	var tr := s.traj
	var x := s.traj_bx
	var y := s.traj_by
	var vx := s.traj_bvx
	var vy := s.traj_bvy
	for i in TRAJ_POINTS:
		tr[2 * i] = x
		tr[2 * i + 1] = y
		if vx == 0.0 and vy == 0.0:
			continue
		for k in 6:
			var sp := sqrt(vx * vx + vy * vy)
			if sp > 0.0:
				var ns := maxf(0.0, sp - (1.5 + 0.32 * sp) * (1.0 / 60.0))
				vx *= ns / sp
				vy *= ns / sp
			x += vx / 60.0
			y += vy / 60.0


## Primer instant en què p pot arribar a la pilota. Deixa el punt a s.icpt_x/y.
## ref: interceptT()
static func intercept_t(s: MatchState, p: Player) -> float:
	if not s.traj_ready:
		s.icpt_x = NAN
		s.icpt_y = NAN
		return NAN
	ensure_traj(s)
	var tr := s.traj
	var v := p.max_speed * 1.05
	for i in TRAJ_POINTS:
		var t := i * 0.1
		var dx := tr[2 * i] - p.x
		var dy := tr[2 * i + 1] - p.y
		var r := v * t + 0.7
		# d <= r, comparant quadrats (tots dos són positius).
		if dx * dx + dy * dy <= r * r:
			s.icpt_x = tr[2 * i]
			s.icpt_y = tr[2 * i + 1]
			return t
	var n := 2 * TRAJ_POINTS - 2
	var ex := tr[n] - p.x
	var ey := tr[n + 1] - p.y
	s.icpt_x = tr[n]
	s.icpt_y = tr[n + 1]
	return 3.0 + sqrt(ex * ex + ey * ey) / v


## Rols de cada equip: qui persegueix la pilota lliure, qui pressiona i qui cobreix.
## ref: assignRoles()
static func assign_roles(s: MatchState) -> void:
	for t in s.teams:
		t.chaser = null
		t.presser = null
		t.cover = null
	if s.state != &"play":
		return
	var ball := s.ball
	var own := ball.owner
	# Poda exacta per a la pilota lliure: la trajectòria és una recta que recorre com a
	# molt `travel` metres, així que p no hi pot arribar abans de
	# (dist(p, inici) − travel − 0,7) / v. Si aquesta cota ja no millora el millor temps,
	# intercept_t(p) tampoc no el milloraria i es pot saltar.
	var prune := not own and s.traj_ready
	var x0 := 0.0
	var y0 := 0.0
	var travel := 0.0
	if prune:
		ensure_traj(s)
		var tr := s.traj
		x0 = tr[0]
		y0 = tr[1]
		var ex := tr[2 * TRAJ_POINTS - 2] - x0
		var ey := tr[2 * TRAJ_POINTS - 1] - y0
		travel = sqrt(ex * ex + ey * ey) + 0.7
	for t in s.teams:
		var hp: Player = s.ctrl if (t.human and s.ctrl) else null
		if not own:
			var best: Player = null
			var bt := 1e9
			for p in t.players:
				if p.is_gk or p.stun > 0.2 or p == hp:
					continue
				if prune and best:
					var px := p.x - x0
					var py := p.y - y0
					var lb := (sqrt(px * px + py * py) - travel) / (p.max_speed * 1.05)
					if lb - 1e-6 >= bt:
						continue
				var tt := intercept_t(s, p)
				if tt < bt:
					bt = tt
					best = p
			if hp and best:
				var th := intercept_t(s, hp)
				if bt > th * 0.8:
					best = null
			t.chaser = best
		elif own.team != t:
			# Els dos més propers a la pilota (ordre estable, com sort() de JavaScript).
			var b1: Player = null
			var b2: Player = null
			var d1 := INF
			var d2 := INF
			for p in t.players:
				if p.is_gk or p.stun > 0.2 or p == hp:
					continue
				var dx := p.x - ball.x
				var dy := p.y - ball.y
				var d := sqrt(dx * dx + dy * dy)
				if d < d1:
					b2 = b1
					d2 = d1
					b1 = p
					d1 = d
				elif d < d2:
					b2 = p
					d2 = d
			var hd := 1e9
			if hp:
				var hx := hp.x - ball.x
				var hy := hp.y - ball.y
				hd = sqrt(hx * hx + hy * hy)
			if b1 and d1 < hd - 2.0:
				t.presser = b1
			t.cover = b2 if t.presser == b1 else b1


## Valora una passada de p cap a (tx, ty): obertura de la línia i espai del receptor.
## Si és la millor fins ara, la desa a s.bp_*. ref: bestPass() › consider(), laneOpen()
static func _consider(
	s: MatchState, p: Player, q: Player, tx: float, ty: float, through: bool, opp: Array[Player]
) -> void:
	if absf(ty) > HW - 0.8 or absf(tx) > HL - 0.8:
		return
	var d := p.team.dir
	var dx := tx - p.x
	var dy := ty - p.y
	var dist := sqrt(dx * dx + dy * dy)
	# La referència calcula la línia abans de descartar per distància; el resultat és el
	# mateix i així s'estalvia el bucle.
	if dist < 5.0 or dist > 40.0:
		return
	var dist2 := dist * dist
	var lane := 9.0
	var open := 9.0
	for o in opp:
		var u := ((o.x - p.x) * dx + (o.y - p.y) * dy) / dist2
		if u > 0.05 and u < 1.05:
			var lx := o.x - (p.x + dx * u)
			var ly := o.y - (p.y + dy * u)
			var ld := sqrt(lx * lx + ly * ly) / (0.6 + dist * u * 0.12)
			if ld < lane:
				lane = ld
		var ox := o.x - tx
		var oy := o.y - ty
		var od := sqrt(ox * ox + oy * oy)
		if od < open:
			open = od
	if lane < 1.0:
		return
	var fwd := (tx - p.x) * d
	var sc := (
		fwd * 0.3 + minf(open, 8.0) * 0.42 + minf(lane, 4.0) * 0.45 - maxf(0.0, dist - 28.0) * 0.15
	)
	if Constants.in_circle(tx, ty, d):
		sc += 3.5
	elif tx * d > Constants.L23:
		sc += 1.2
	if fwd < -3.0:
		sc -= 2.5
	if through:
		sc -= 0.6
	if not s.bp_q or sc > s.bp_score:
		s.bp_q = q
		s.bp_score = sc
		s.bp_tx = tx
		s.bp_ty = ty
		s.bp_through = through


## Millor passada possible per a p (també per al porter). Deixa el resultat a s.bp_* i
## retorna si n'ha trobat cap. ref: bestPass()
static func best_pass(s: MatchState, p: Player) -> bool:
	var t := p.team
	var d := t.dir
	var opp := t.opp.players
	s.bp_q = null
	for q in t.players:
		if q == p or q.is_gk:
			continue
		_consider(s, p, q, q.x + q.vx * 0.45, q.y + q.vy * 0.45, false, opp)
		if q.role != Player.DF and (q.x - p.x) * d > 2.0:
			# Bola a l'espai per davant del company.
			var lead := 6.0 + s.rng.rand() * 3.0
			var tx := q.x + d * lead
			var ty := q.y * 0.85
			if tx * d > HL - 4.0:
				tx = d * (HL - 4.0)
			_consider(s, p, q, tx, ty, true, opp)
	return s.bp_q != null


## Espai lliure per conduir endavant. ref: dribbleScore()
static func dribble_score(p: Player) -> float:
	var d := p.team.dir
	var space := 10.0
	for o in p.team.opp.players:
		var rx := (o.x - p.x) * d
		var ry := o.y - p.y
		if rx > -1.0 and rx < 10.0 and absf(ry) < rx * 0.8 + 1.5:
			space = minf(space, sqrt(rx * rx + ry * ry))
	return space * 0.6 - 1.2


## Tria cap on conduir. ref: dribbleTarget()
static func set_dribble_target(s: MatchState, p: Player) -> void:
	var d := p.team.dir
	var gx := d * HL
	p.has_plan = true
	if p.x * d > HL - 34.0:
		p.plan_x = gx - d * (7.0 + s.rng.rand() * 3.0)
		p.plan_y = clampf(p.y * 0.35 + (s.rng.rand() - 0.5) * 4.0, -5.0, 5.0)
		return
	p.plan_x = clampf(p.x + d * 14.0, -HL + 3.0, HL - 3.0)
	p.plan_y = clampf(p.y * 0.85 + (s.rng.rand() - 0.5) * 7.0, -HW + 3.0, HW - 3.0)


## Xut a porteria, cap al pal contrari al porter. ref: aiShoot()
static func ai_shoot(s: MatchState, p: Player) -> void:
	var rng := s.rng
	var ball := s.ball
	var d := p.team.dir
	var gx := d * HL
	var gk := p.team.opp.gk
	var ty := -(1.0 + rng.rand() * 0.6) if gk.y > 0.0 else (1.0 + rng.rand() * 0.6)
	if rng.rand() < 0.25:
		ty = (rng.rand() - 0.5) * 1.2
	var ang := (
		atan2(ty - ball.y, gx - ball.x)
		+ rng.gauss() * (0.03 + (1.0 - p.sho / 100.0) * 0.09) * p.team.df_err
	)
	var spd := 21.0 + p.sho / 100.0 * 8.0 + rng.rand() * 3.0
	var vz := 0.2
	if rng.rand() < 0.5:
		vz = 0.4 + rng.rand() * 2.6
	BallActions.kick(s, p, ang, spd, vz, &"shot")


## IA del jugador que porta la pilota: xutar, passar, rebutjar o conduir esquivant.
## ref: aiCarrier()
static func ai_carrier(s: MatchState, p: Player, dt: float) -> void:
	var ball := s.ball
	var t := p.team
	var d := t.dir
	var gx := d * HL
	var opp := t.opp
	p.hold_t += dt
	p.think_t -= dt
	var in_c := Constants.in_circle(ball.x, ball.y, d)
	if in_c and not p.was_in_c:
		s.dbg["entry"][t.idx] += 1
		p.think_t = minf(p.think_t, 0.05)
	p.was_in_c = in_c
	if s.pc_live and in_c and not ball.pc_pending and t == s.pc_team:
		ai_shoot(s, p)
		return
	if s.pc_live and t == s.pc_team and p == s.pc_hit and not in_c and not ball.pc_pending:
		p.has_plan = true
		p.plan_x = gx - d * 11.0
		p.plan_y = p.y * 0.5
		p.think_t = 0.3
	if p.think_t <= 0.0:
		p.think_t = t.df_react * (0.7 + s.rng.rand() * 0.6)
		var dg := sqrt((gx - p.x) * (gx - p.x) + p.y * p.y)
		if in_c and not ball.pc_pending:
			var straight := 1.0 - minf(1.0, absf(p.y) / (dg + 0.1))
			if dg < 11.0 or (dg < 14.8 and s.rng.rand() < 0.4 + straight * 0.3):
				ai_shoot(s, p)
				return
		var press := BallActions.nearest_opp_dist(p)
		var has_bp := best_pass(s, p)
		var ds := dribble_score(p)
		var can := p.hold_t > 0.35 or press < 2.5
		if has_bp and can and s.bp_score > ds + (-1.5 if press < 2.2 else 1.2):
			BallActions.pass_to(s, p, s.bp_q, s.bp_tx, s.bp_ty, t.df_err, s.bp_through)
			return
		if press < 1.6 and p.x * d < -HL + 18.0 and not has_bp:
			var a := atan2((1.0 if p.y >= 0.0 else -1.0) * 14.0, d * 20.0)
			BallActions.kick(s, p, a, 20.0, 0.5, &"hit")
			return
		set_dribble_target(s, p)
	if not p.has_plan:
		set_dribble_target(s, p)
	var vx := p.plan_x - p.x
	var vy := p.plan_y - p.y
	var ln := sqrt(vx * vx + vy * vy)
	if ln == 0.0:
		ln = 1.0
	vx /= ln
	vy /= ln
	var ax := vx
	var ay := vy
	for o in opp.players:
		var rx := o.x - p.x
		var ry := o.y - p.y
		var rd := sqrt(rx * rx + ry * ry)
		if rd < 5.0 and rd > 0.01:
			var ahead := (rx * vx + ry * vy) / rd
			if ahead > 0.0:
				var w := (5.0 - rd) / 5.0 * ahead * 1.5
				var px := -vy
				var py := vx
				if px * rx + py * ry > 0.0:
					px = -px
					py = -py
				ax += px * w
				ay += py * w
	if absf(p.y) > HW - 3.0:
		ay -= signf(p.y) * 1.2
	if p.x * d > HL - 3.0:
		ax -= d * 1.2
	if p.x * d < -HL + 3.0:
		ax += d * 1.2
	var al := sqrt(ax * ax + ay * ay)
	if al == 0.0:
		al = 1.0
	ax /= al
	ay /= al
	var vmax := p.max_speed * 0.9 * Movement.mods(s, p)
	Movement.accel_to(p, ax * vmax, ay * vmax, dt)
	if absf(p.y) > HW - 1.2 and p.vy * p.y > 0.0:
		p.vy = 0.0
	if absf(p.x) > HL - 1.2 and p.vx * p.x > 0.0:
		p.vx = 0.0


## IA dels jugadors de camp sense pilota. ref: aiField()
static func ai_field(s: MatchState, p: Player, dt: float) -> void:
	var ball := s.ball
	var t := p.team
	var d := t.dir
	var own := ball.owner
	var tx := 0.0
	var ty := 0.0
	var frac := 0.85
	if s.state == &"goal":
		var sc := s.scorer
		if sc and t == sc.team:
			if p == sc:
				tx = sc.team.dir * (HL - 3.0)
				ty = (1.0 if sc.y >= 0.0 else -1.0) * (HW - 3.0)
				frac = 0.9
			else:
				tx = sc.x
				ty = sc.y
				frac = 0.75
		else:
			base_pos(s, p)
			tx = s.out_x
			ty = s.out_y
			frac = 0.4
		Movement.move_toward(s, p, tx, ty, frac, dt, 1.5)
		return
	if s.state == &"restart":
		base_pos(s, p)
		Movement.move_toward(s, p, s.out_x, s.out_y, 0.9, dt, 1.5)
		return
	if not own and p.recv_t > 0.0 and ball.pass_target == p:
		intercept_t(s, p)
		tx = s.icpt_x
		ty = s.icpt_y
		frac = 1.05
	elif own and own.team != t:
		var ogx := -d * HL
		var gx := ogx - own.x
		var gy := -own.y
		var gl := sqrt(gx * gx + gy * gy)
		if gl == 0.0:
			gl = 1.0
		if t.presser == p:
			var ex := own.x - p.x
			var ey := own.y - p.y
			var dist := sqrt(ex * ex + ey * ey)
			if dist > 3.0:
				tx = own.x + gx / gl * 1.3 + own.vx * 0.25
				ty = own.y + gy / gl * 1.3 + own.vy * 0.25
			else:
				tx = ball.x
				ty = ball.y
			frac = 1.15 if dist > 8.0 else 1.0
		elif t.cover == p:
			tx = own.x + gx / gl * 5.0
			ty = own.y + gy / gl * 5.0
			frac = 1.0
		else:
			mark_pos(s, p)
			tx = s.out_x
			ty = s.out_y
	elif not own:
		if t.chaser == p:
			intercept_t(s, p)
			tx = s.icpt_x
			ty = s.icpt_y
			frac = 1.15
		else:
			base_pos(s, p)
			tx = s.out_x
			ty = s.out_y
	else:
		support_pos(s, p, dt)
		tx = s.out_x
		ty = s.out_y
	Movement.move_toward(s, p, tx, ty, frac, dt, 1.5)
	if own and own.team != t and p.tackle_cd <= 0.0 and p.stun <= 0.0:
		var bx := ball.x - p.x
		var by := ball.y - p.y
		if sqrt(bx * bx + by * by) < 1.5:
			var rate := (2.6 if t.presser == p else 1.0) * t.df_tack
			if s.rng.rand() < rate * dt:
				BallActions.try_tackle(s, p, own)
