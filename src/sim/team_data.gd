## Dades d'un equip: noms, colors, equipacions i plantilla.
## Les instàncies són a data/teams/*.tres. ref: TEAM_DEFS, ovrOf(), teamOvr()
class_name TeamData
extends Resource

const PATHS: Array[String] = ["res://data/teams/iluro.tres", "res://data/teams/polo.tres"]

@export var id := ""
@export var name := ""
@export var short := ""
@export var city := ""
## Colors en hexadecimal, tal com a la referència (només per a la presentació).
@export var color := ""
@export var ink := ""
@export var mini := ""
@export var ring := ""
@export var kit: Dictionary = {}
@export var gk_kit: Dictionary = {}
## Cada jugador: [dorsal, nom, posició, velocitat, control, passada, xut, defensa,
## resistència, reflexos]. Els reflexos només els tenen els porters.
@export var squad: Array = []


## Equip per defecte: 0 = Iluro HC, 1 = Club Polo.
static func load_default(idx: int) -> TeamData:
	return load(PATHS[idx]) as TeamData


## Valoració d'un jugador. ref: ovrOf()
static func ovr_of(s: Array) -> float:
	if s[2] == "GK":
		return float(s[9])
	var w: Array = Constants.WEIGHTS[s[2]]
	var v := 0.0
	for k in 6:
		v += float(w[k]) * float(s[3 + k])
	return v


## Valoració de l'equip (mitjana arrodonida). ref: teamOvr()
func team_ovr() -> int:
	var acc := 0.0
	for s: Array in squad:
		acc += ovr_of(s)
	return int(floor(acc / squad.size() + 0.5))
