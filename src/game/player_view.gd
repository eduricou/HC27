## Un jugador a la vista: MatchView el col·loca i l'orienta (interpolant entre passos de
## simulació), i el PlayerRig de dins el dibuixa i l'anima (fase 4).
## El −Z local mira cap a on mira el jugador i el +X local és el costat del pal
## (ref: stickPt(), 0,72 m endavant i 0,3 m de costat).
class_name PlayerView
extends Node3D

var rig: PlayerRig
## Velocitat suavitzada (m/s) que es passa a l'animació.
var speed := 0.0
## Qui és i com es veu (key_of()): si el partit nou té el mateix jugador, es reaprofita.
var key := ""


## L'aspecte del jugador només depèn de l'equip, el dorsal i el lloc a la plantilla
## (Player._init), així que és el mateix a cada partit.
static func key_of(p: Player) -> String:
	return "%d/%d/%d/%d/%d/%s" % [p.team.idx, p.num, p.skin, p.hair, p.hs, p.is_gk]


## Partit nou amb el mateix jugador: oblida l'acció i la velocitat del partit anterior.
func reset() -> void:
	speed = 0.0
	rig.reset()


func setup(p: Player, def: TeamData) -> void:
	key = key_of(p)
	name = "Jugador%d_%d" % [p.team.idx, p.num]
	rig = PlayerRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(p, def)


## Un fotograma: `raw_speed` és la velocitat mesurada entre els dos últims passos.
func animate(p: Player, raw_speed: float, delta: float) -> void:
	speed = lerpf(speed, raw_speed, 1.0 - exp(-delta * 10.0))
	rig.animate(p, speed, delta)


func trigger(action: StringName, hands_free: bool = true) -> void:
	rig.trigger(action, hands_free)
