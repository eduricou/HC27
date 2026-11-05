## Regles: represes, servei de centre, faltes, penal córner, gols, quarts, sortides
## de la pilota i rellotge.
## ref: línies 439–545, 928–949 i 1007–1031 de reference/web/index.html
class_name Rules
extends RefCounted

const HL := Constants.HL
const HW := Constants.HW
const GHW := Constants.GHW
## Posicions dels atacants al penal córner: [distància a la línia de fons, y].
const PC_SPOTS := [
	[16.6, -6.5],
	[16.6, 6.5],
	[17.5, -11.5],
	[17.5, 11.5],
	[25.0, -17.0],
	[25.0, 17.0],
	[40.0, -9.0],
	[40.0, 9.0]
]


## Col·loca qui treu darrere de la pilota, mirant cap a fa. ref: placeTaker()
static func place_taker(p: Player, x: float, y: float, fa: float) -> void:
	p.face = fa
	var c := cos(fa)
	var sn := sin(fa)
	p.x = x - c * 0.72 + sn * 0.3
	p.y = y - sn * 0.72 - c * 0.3
	p.vx = 0.0
	p.vy = 0.0


## Represa: &"free" (cop franc), &"side" (banda), &"hitout" (sortida), &"long" (córner
## llarg) o &"center" (servei). reason i by només serveixen per al rètol. ref: restart()
static func restart(
	s: MatchState,
	type: StringName,
	team: Team,
	x: float,
	y: float,
	reason: StringName = &"",
	by: Player = null
) -> void:
	s.state = &"restart"
	s.state_t = 0.0
	s.pc_live = false
	s.charge = 0.0
	s.ball.place(x, y)
	s.last_poss = team
	var taker: Player = null
	if type == &"center":
		for p in team.players:
			if p.has_slot and p.role == Player.FW and p.slot_y == 0.0:
				taker = p
				break
	if not taker:
		taker = BallActions.nearest_to(team, x, y)
	var fa := atan2(-y * 0.35, team.dir * 20.0)
	if type == &"side":
		fa = atan2(-signf(y) * 12.0, team.dir * 9.0)
	place_taker(taker, x, y, fa)
	s.restart_type = type
	s.restart_team = team
	s.restart_taker = taker
	for p in s.players:
		p.recv_t = 0.0
		p.has_plan = false
	if team.human:
		BallActions.set_ctrl(s, taker)
	else:
		var h := s.other(team)
		if h.human:
			BallActions.set_ctrl(s, BallActions.nearest_to(h, x, y))
	(
		s
		. emit(
			{
				"type": &"restart",
				"kind": type,
				"team": team.idx,
				"reason": reason,
				"by": by,
			}
		)
	)


## Servei de centre: tothom al seu camp i els rivals a 5 m. ref: kickoff()
static func kickoff(s: MatchState, team: Team) -> void:
	for t in s.teams:
		for p in t.players:
			if p.is_gk:
				p.x = -t.dir * (HL - 1.0)
				p.y = 0.0
			else:
				var x := minf(-1.5, p.slot_x * 30.0 - 6.0)
				if p.role == Player.FW:
					x = minf(-1.2, p.slot_x * 10.0 - 2.5)
				p.x = x * t.dir
				p.y = p.slot_y * HW * 0.72
			p.vx = 0.0
			p.vy = 0.0
			p.face = 0.0 if t.dir > 0 else PI
			p.stun = 0.0
			p.kick_cd = 0.0
			p.stamina = minf(1.0, p.stamina + 0.25)
	restart(s, &"center", team, 0.0, 0.0)
	for p in s.other(team).players:
		var d := sqrt(p.x * p.x + p.y * p.y)
		if d < 5.2:
			var a := atan2(p.y, p.x)
			p.x = cos(a) * 5.2
			p.y = sin(a) * 5.2


## Falta de `off` a (x, y): penal córner si és dins del seu cercle defensiu; si no, cop
## franc (a la línia discontínua si és a menys de 5 m del cercle). ref: foul()
static func foul(s: MatchState, off: Player, x: float, y: float) -> void:
	var vic := s.other(off.team)
	s.stat_fouls[off.team.idx] += 1
	s.emit({"type": &"whistle", "strength": 0.28, "count": 1})
	if Constants.in_circle(x, y, -off.team.dir):
		setup_pc(s, vic, y, &"foul_circle", off)
		return
	var fx := clampf(x, -HL + 0.5, HL - 0.5)
	var fy := clampf(y, -HW + 0.5, HW - 0.5)
	if Constants.in_circle(fx, fy, vic.dir, Constants.DR):
		var v := Constants.push_to_dotted(fx, fy, vic.dir)
		fx = v[0]
		fy = v[1]
	restart(s, &"free", vic, fx, fy, &"foul", off)


## Prepara un penal córner per a l'equip att, des del costat de y.
## ref: setupPC()
static func setup_pc(
	s: MatchState, att: Team, y: float, reason: StringName = &"", by: Player = null
) -> void:
	var def := s.other(att)
	var d := att.dir
	var gx := d * HL
	var sd := 1.0 if y >= 0.0 else -1.0
	s.stat_pcs[att.idx] += 1
	s.state = &"pc"
	s.state_t = 0.0
	s.pc_team = att
	s.pc_live = false
	s.charge = 0.0
	s.ball.place(gx - d * 0.05, sd * (GHW + 10.0), true)
	s.last_poss = att
	var outs: Array[Player] = []
	for p in att.players:
		if not p.is_gk:
			outs.append(p)
	# El que xuta és qui té més xut; l'injector, qui té més passada (el primer si empaten).
	var hitter := outs[0]
	for p in outs:
		if p.sho > hitter.sho:
			hitter = p
	var inj: Player = null
	for p in outs:
		if p != hitter and (inj == null or p.pas > inj.pas):
			inj = p
	var ball := s.ball
	var hx := gx - d * 15.7
	var hy := sd * 0.9
	hitter.x = hx
	hitter.y = hy
	hitter.face = atan2(ball.y - hy, ball.x - hx)
	inj.x = gx + d * 0.8
	inj.y = ball.y
	inj.face = atan2(hy - ball.y, hx - inj.x)
	var k := 0
	for p in outs:
		if p == hitter or p == inj:
			continue
		var sp: Array = PC_SPOTS[k]
		k += 1
		p.x = gx - d * float(sp[0])
		p.y = float(sp[1])
		p.face = atan2(-p.y, d)
	att.gk.x = -gx + d * 1.0
	att.gk.y = 0.0
	var dg := def.gk
	dg.x = gx - d * 0.3
	dg.y = 0.0
	dg.face = PI if d > 0 else 0.0
	var douts := sort_by_dfn_desc(def.players)
	var line_y := [sd * 2.6, sd * 1.0, -sd * 1.2, -sd * 2.7]
	for idx in douts.size():
		var p := douts[idx]
		if idx < 4:
			p.x = gx + d * 0.35
			p.y = line_y[idx]
		else:
			p.x = -d * 2.5
			p.y = (idx - 6.5) * 7.0
		p.face = PI if d > 0 else 0.0
	for p in s.players:
		p.vx = 0.0
		p.vy = 0.0
		p.stun = 0.0
		p.recv_t = 0.0
		p.has_plan = false
	s.pc_inj = inj
	s.pc_hit = hitter
	if att.human:
		BallActions.set_ctrl(s, inj)
	if def.human:
		BallActions.set_ctrl(s, douts[0])
	s.emit({"type": &"pc", "team": att.idx, "reason": reason, "by": by})


## Jugadors de camp ordenats per defensa de més a menys, mantenint l'ordre de la
## plantilla en cas d'empat (com Array.sort de JavaScript, que és estable).
static func sort_by_dfn_desc(src: Array[Player]) -> Array[Player]:
	var out: Array[Player] = []
	for p in src:
		if p.is_gk:
			continue
		var k := out.size()
		while k > 0 and out[k - 1].dfn < p.dfn:
			k -= 1
		out.insert(k, p)
	return out


## Injecció del penal córner: l'injector passa al que xuta. ref: updatePC()
static func update_pc(s: MatchState, dt: float) -> void:
	s.state_t += dt
	var inj := s.pc_inj
	var h := s.pc_hit
	var human := s.pc_team.human and s.ctrl == inj
	var go := false
	if human:
		go = s.state_t > 0.4 and (s.input.pass_e or s.input.shoot_e)
	else:
		go = s.state_t > 1.8
	if go:
		BallActions.stick_pt(s, h)
		BallActions.kick(s, inj, atan2(s.st_y - s.ball.y, s.st_x - s.ball.x), 14.0, 0.0, &"pass")
		s.ball.pass_target = h
		h.recv_t = 2.2
		s.state = &"play"
		s.pc_live = true
		s.pc_t = 0.0
		if s.pc_team.human:
			BallActions.set_ctrl(s, h)


## Gol de l'equip t. ref: scoreGoal()
static func score_goal(s: MatchState, t: Team) -> void:
	s.score[t.idx] += 1
	s.state = &"goal"
	s.state_t = 0.0
	s.pc_live = false
	s.charge = 0.0
	var sc: Player = s.ball.last_by[t.idx]
	if not sc:
		sc = t.players[9]
	var minute := mini(
		60, (s.quarter - 1) * 15 + int(floor((Constants.QGAME - s.clock) / 60.0)) + 1
	)
	s.goals.append({"team": t.idx, "name": sc.name, "num": sc.num, "minute": minute})
	s.replay = s.rec.snapshot()
	s.replay_len = s.rec.length_of()
	s.rp_i = 0.0
	s.rp_end = 0.0
	s.next_center = t.opp
	s.scorer = sc
	s.wiped = false
	s.goal_side = 1 if s.ball.x > 0.0 else -1
	s.emit({"type": &"whistle", "strength": 0.4, "count": 1})
	(
		s
		. emit(
			{
				"type": &"goal",
				"team": t.idx,
				"scorer": sc,
				"minute": minute,
				"side": s.goal_side,
				"y": clampf(s.ball.y, -GHW, GHW),
			}
		)
	)


## Final de quart: descans, final del partit o, en mode demo, continuar. ref: endQuarter()
static func end_quarter(s: MatchState) -> void:
	s.end_pending = false
	s.emit({"type": &"whistle", "strength": 0.7, "count": 3 if s.quarter == 4 else 2})
	if s.mode == &"demo":
		if s.quarter >= 4:
			s.new_game(&"demo", -1, s.diff, s.qlen)
			return
		next_quarter(s)
		return
	s.state = &"full" if s.quarter >= 4 else &"break"
	s.emit({"type": &"quarter_end", "quarter": s.quarter})


## Comença el quart següent; al 3r els equips canvien de camp. ref: nextQuarter()
static func next_quarter(s: MatchState) -> void:
	s.quarter += 1
	s.clock = Constants.QGAME
	if s.quarter == 3:
		for t in s.teams:
			t.dir *= -1
	kickoff(s, s.teams[(s.quarter - 1) % 2])


## Gols i sortides de la pilota pel fons o per la banda. ref: rules()
static func check_bounds(s: MatchState) -> void:
	var b := s.ball
	if absf(b.x) > HL:
		var side := 1 if b.x > 0.0 else -1
		var att := s.teams[0] if s.teams[0].dir == side else s.teams[1]
		var def := s.other(att)
		if absf(b.y) < GHW and b.z < Constants.GH:
			if b.valid_for == att:
				score_goal(s, att)
				return
			s.emit({"type": &"whistle", "strength": 0.3, "count": 1})
			if b.last_team == att:
				var yy := clampf(b.y, -HW + 1.0, HW - 1.0)
				restart(s, &"hitout", def, side * (HL - 14.63), yy, &"no_circle")
				return
		else:
			s.emit({"type": &"whistle", "strength": 0.25, "count": 1})
		var y := clampf(b.y, -HW + 1.0, HW - 1.0)
		if b.last_team == att:
			restart(s, &"hitout", def, side * (HL - 14.63), y)
		else:
			restart(s, &"long", att, side * Constants.L23, y)
		return
	if absf(b.y) > HW:
		s.emit({"type": &"whistle", "strength": 0.25, "count": 1})
		var t: Team = s.other(b.last_team) if b.last_team else s.teams[0]
		var x := clampf(b.x, -HL + 1.0, HL - 1.0)
		var y := (1.0 if b.y > 0.0 else -1.0) * (HW - 0.05)
		if Constants.in_circle(x, y, t.dir, Constants.DR):
			x = t.dir * (HL - Constants.DR - 0.5)
		restart(s, &"side", t, x, y)


## Qui treu una represa ho fa: l'humà amb l'entrada, la CPU després d'esperar.
## ref: updateRestart()
static func update_restart(s: MatchState, dt: float) -> void:
	var tk := s.restart_taker
	var team := s.restart_team
	var inp := s.input
	if team.human and s.ctrl == tk:
		if s.state_t > 0.3:
			if inp.pass_e:
				HumanControl.human_pass(s, tk)
				s.state = &"play"
				return
			if inp.shoot_held and not s.shoot_consumed:
				s.charge = minf(1.0, s.charge + dt / 0.85)
			if inp.shoot_up_e and s.charge > 0.0:
				HumanControl.human_shoot(s, tk, s.charge)
				s.charge = 0.0
				s.state = &"play"
				return
			if inp.mv.length() > 0.6:
				BallActions.gain(s, tk)
				s.state = &"play"
				return
	elif s.state_t > (1.2 if s.restart_type == &"center" else 0.9) + team.df_react * 0.5:
		if Ai.best_pass(s, tk) and s.bp_score > -2.0:
			BallActions.pass_to(s, tk, s.bp_q, s.bp_tx, s.bp_ty, team.df_err, s.bp_through)
		else:
			BallActions.gain(s, tk)
		s.state = &"play"


## Avança el rellotge del partit. ref: tickClock()
static func tick_clock(s: MatchState, dt: float) -> void:
	if s.end_pending:
		return
	s.clock -= dt * (Constants.QGAME / s.qlen)
	if s.clock <= 0.0:
		s.clock = 0.0
		s.end_pending = true
