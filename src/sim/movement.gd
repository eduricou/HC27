## Moviment dels jugadors: acceleració, integració i col·lisions.
## ref: línies 780–806 de reference/web/index.html
class_name Movement
extends RefCounted

const COLLIDE_DIST := 0.75


## Multiplicador de velocitat per cansament, conducció i dificultat. ref: mods()
static func mods(s: MatchState, p: Player) -> float:
	var m := 0.86 + 0.14 * p.stamina
	if s.ball.owner == p:
		m *= 0.9
	if not p.team.human or s.ctrl != p:
		m *= p.team.df_spd
	return m


## Acosta la velocitat a (vx, vy) amb una acceleració màxima de 16 m/s². ref: accelTo()
static func accel_to(p: Player, vx: float, vy: float, dt: float) -> void:
	var ax := vx - p.vx
	var ay := vy - p.vy
	var a := sqrt(ax * ax + ay * ay)
	var m := 16.0 * dt
	if a > m:
		p.vx += ax / a * m
		p.vy += ay / a * m
	else:
		p.vx = vx
		p.vy = vy


## Mou p cap a (tx, ty) a una fracció de la velocitat màxima, frenant en arribar.
## ref: moveToward()
##
## mods() i accel_to() hi són incrustades perquè és la funció més cridada de la IA.
static func move_toward(
	s: MatchState, p: Player, tx: float, ty: float, frac: float, dt: float, arrive: float
) -> void:
	var px := p.x
	var py := p.y
	var dx := tx - px
	var dy := ty - py
	var d := sqrt(dx * dx + dy * dy)
	# mods()
	var stamina := p.stamina
	var m := 0.86 + 0.14 * stamina
	if s.ball.owner == p:
		m *= 0.9
	var team := p.team
	if not team.human or s.ctrl != p:
		m *= team.df_spd
	var vmax := p.max_speed * frac * m
	var tv := vmax if d > arrive else vmax * d / arrive
	if frac > 1.0:
		p.stamina = maxf(0.0, stamina - dt * 0.1 * (1.3 - p.sta / 100.0))
	var tvx := 0.0
	var tvy := 0.0
	if d > 0.01:
		tvx = dx / d * tv
		tvy = dy / d * tv
	# accel_to()
	var pvx := p.vx
	var pvy := p.vy
	var ax := tvx - pvx
	var ay := tvy - pvy
	var a := sqrt(ax * ax + ay * ay)
	var lim := 16.0 * dt
	if a > lim:
		p.vx = pvx + ax / a * lim
		p.vy = pvy + ay / a * lim
	else:
		p.vx = tvx
		p.vy = tvy


## Avança la posició, gira el cos i recupera resistència. ref: integrate()
static func integrate(s: MatchState, p: Player, dt: float) -> void:
	var ball := s.ball
	var vx := p.vx
	var vy := p.vy
	if p.stun > 0.0:
		vx *= 0.86
		vy *= 0.86
		p.vx = vx
		p.vy = vy
	var x := p.x + vx * dt
	var y := p.y + vy * dt
	var sp := sqrt(vx * vx + vy * vy)
	var has_tf := false
	var tf := 0.0
	var owner := ball.owner == p
	if p.lock_face:
		pass
	elif sp > 0.6:
		tf = atan2(vy, vx)
		has_tf = true
	elif not owner:
		tf = atan2(ball.y - y, ball.x - x)
		has_tf = true
	if has_tf:
		var face := p.face
		# Constants.ang_diff(face, tf), incrustada.
		var d := tf - face
		while d > PI:
			d -= TAU
		while d < -PI:
			d += TAU
		p.face = face + d * minf(1.0, dt * (9.0 if owner else 7.0))
	var moving := sp > 0.4
	p.moving = moving
	if moving:
		p.anim += sp * dt * 2.6
	p.stamina = minf(1.0, p.stamina + dt * 0.04)
	p.x = clampf(x, -Constants.HL - 4.0, Constants.HL + 4.0)
	p.y = clampf(y, -Constants.HW - 3.5, Constants.HW + 4.0)


## Separa els jugadors que es trepitgen (menys de 0,75 m). ref: collide()
## Treballa sobre còpies locals de les posicions (més ràpid que llegir els objectes) i
## les torna als jugadors en acabar; l'ordre de les parelles és el de la referència.
## Els vectors de treball són de l'estat, i no estàtics, per poder simular partits en
## paral·lel.
static func collide(s: MatchState) -> void:
	var players := s.players
	var n := players.size()
	var xs := s.col_x
	var ys := s.col_y
	var locked := s.col_lock
	if xs.size() != n:
		xs.resize(n)
		ys.resize(n)
		locked.resize(n)
	for i in n:
		var p := players[i]
		xs[i] = p.x
		ys[i] = p.y
		locked[i] = 1 if p.lock_face else 0
	var moved := false
	for i in n:
		var ax := xs[i]
		var ay := ys[i]
		for j in range(i + 1, n):
			var dx := xs[j] - ax
			# Si |dx| o |dy| ja passen de 0,75 m, la distància també: no cal l'arrel.
			if dx >= COLLIDE_DIST or dx <= -COLLIDE_DIST:
				continue
			var dy := ys[j] - ay
			if dy >= COLLIDE_DIST or dy <= -COLLIDE_DIST:
				continue
			var d := sqrt(dx * dx + dy * dy)
			if d < COLLIDE_DIST and d > 0.001:
				moved = true
				var o := (COLLIDE_DIST - d) / 2.0
				var nx := dx / d
				var ny := dy / d
				if locked[i] == 0:
					ax -= nx * o
					ay -= ny * o
					xs[i] = ax
					ys[i] = ay
				if locked[j] == 0:
					xs[j] += nx * o
					ys[j] += ny * o
	if moved:
		for i in n:
			var p := players[i]
			p.x = xs[i]
			p.y = ys[i]
