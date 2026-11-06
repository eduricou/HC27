## Un jugador a la vista: MatchView el col·loca i l'orienta (interpolant entre passos de
## simulació), i el PlayerRig de dins el dibuixa i l'anima (fase 4).
## El −Z local mira cap a on mira el jugador i el +X local és el costat del pal
## (ref: stickPt(), 0,72 m endavant i 0,3 m de costat).
class_name PlayerView
extends Node3D

var rig: PlayerRig
## Velocitat suavitzada (m/s) que es passa a l'animació.
var speed := 0.0


func setup(p: Player, def: TeamData) -> void:
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
