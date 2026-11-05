## La pilota: posició, velocitat i informació de l'últim toc.
## ref: newBall()
class_name Ball
extends RefCounted

var x := 0.0
var y := 0.0
var z := 0.0
var vx := 0.0
var vy := 0.0
var vz := 0.0
var owner: Player
var last_touch: Player
var last_team: Team
## Últim jugador de cada equip que l'ha tocada (per atribuir els gols).
var last_by: Array[Player] = [null, null]
## Equip per al qual un gol seria vàlid (l'últim toc ha estat dins del seu cercle d'atac).
var valid_for: Team
## Penal córner en curs: la pilota encara no ha sortit del cercle després de la injecció.
var pc_pending := false
var pass_target: Player
var shot_id := 0


## Deixa la pilota quieta i lliure a (px, py), com fan restart() i setupPC().
func place(px: float, py: float, pending: bool = false) -> void:
	owner = null
	x = px
	y = py
	z = 0.0
	vx = 0.0
	vy = 0.0
	vz = 0.0
	valid_for = null
	pc_pending = pending
	pass_target = null
