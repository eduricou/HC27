## Entrada del jugador humà per a un pas de simulació.
## La capa de joc (src/game/human_controller.gd) l'omple a partir del teclat o el
## comandament; la simulació només la llegeix. `mv` va en coordenades de la simulació
## (x = llargada, y = amplada) i té mòdul ≤ 1. Els camps *_e són flancs: valen només
## durant un pas i MatchSim.step() els esborra en acabar. ref: input, sampleInput()
class_name SimInput
extends RefCounted

var mv := Vector2.ZERO
var sprint := false
var shoot_held := false
var pass_e := false
var shoot_e := false
var shoot_up_e := false
var tap_e := false


## ref: clearEdges()
func clear_edges() -> void:
	pass_e = false
	shoot_e = false
	shoot_up_e = false
	tap_e = false
