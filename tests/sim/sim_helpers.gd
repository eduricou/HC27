# Utilitats per a les proves de la simulació (no és una suite de proves).
class_name SimHelpers
extends RefCounted

const HL := Constants.HL
const HW := Constants.HW


## Partit nou, sense la presentació inicial i en joc.
static func new_sim(seed_value: int = 1, qlen: float = 150.0) -> MatchSim:
	var sim := MatchSim.new(seed_value, qlen)
	sim.s.intro_t = 0.0
	sim.s.state = &"play"
	return sim


## Envia tots els jugadors lluny de la jugada, quiets i sense pilota.
static func clear_field(s: MatchState, x: float = -30.0) -> void:
	var k := 0
	for p in s.players:
		p.x = x
		p.y = -HW + 2.0 + k * 2.4
		p.vx = 0.0
		p.vy = 0.0
		p.kick_cd = 1.0
		p.stun = 0.0
		k += 1
	s.ball.owner = null


## Fixa l'estat de la pilota.
static func set_ball(
	s: MatchState, x: float, y: float, vx: float = 0.0, vy: float = 0.0, z: float = 0.0
) -> void:
	var b := s.ball
	b.owner = null
	b.x = x
	b.y = y
	b.z = z
	b.vx = vx
	b.vy = vy
	b.vz = 0.0
