## Un jugador: atributs de la plantilla i estat dinàmic.
## ref: makeTeam() (objecte p)
class_name Player
extends RefCounted

## Rols (camp role): comparar enters és més ràpid que comparar cadenes.
const GK := 0
const DF := 1
const MF := 2
const FW := 3
const ROLES := {"GK": GK, "DF": DF, "MF": MF, "FW": FW}

var team: Team
## Índex dins de l'equip (ordre de la plantilla).
var i: int
var num: int
var name: String
## "GK", "DF", "MF" o "FW". Per als jugadors de camp també és el rol de la posició base.
var pos: String
## El mateix que pos, com a enter (Player.GK, DF, MF o FW).
var role: int
var spd: float
var ctl: float
var pas: float
var sho: float
var dfn: float
var sta: float
var ref: float
var is_gk: bool
var max_speed: float

## Posició base (1-4-3-3) en fraccions del camp; no en tenen els porters.
var has_slot := false
var slot_x := 0.0
var slot_y := 0.0

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var face := 0.0
var anim := 0.0
var moving := false
var stamina := 1.0
var kick_cd := 0.0
var tackle_cd := 0.0
var stun := 0.0
var think_t := 0.0
## Objectiu de conducció de la IA (plan).
var has_plan := false
var plan_x := 0.0
var plan_y := 0.0
var hold_t := 0.0
var swing := 0.0
var save_cd := 0.0
var recv_t := 0.0
var run_x := 0.0
var run_y := 0.0
var run_t := 0.0
var last_shot := -1
var lock_face := false
var was_in_c := false

## Índexs de Constants.SKINS i Constants.HAIRS, i pentinat (0–4). Només per a la vista.
var skin := 0
var hair := 0
var hs := 0


## ref: makeTeam() — l'ordre de les crides a l'atzar (anim i després thinkT) importa.
func _init(p_team: Team, idx: int, s: Array, rng: SimRng) -> void:
	team = p_team
	i = idx
	num = int(s[0])
	name = String(s[1])
	pos = String(s[2])
	spd = float(s[3])
	ctl = float(s[4])
	pas = float(s[5])
	sho = float(s[6])
	dfn = float(s[7])
	sta = float(s[8])
	ref = float(s[9]) if s.size() > 9 else 0.0
	role = ROLES[pos]
	is_gk = role == GK
	anim = rng.rand() * 6.0
	think_t = rng.rand() * 0.5
	var t_idx := p_team.idx
	skin = (idx * 5 + t_idx * 3) % Constants.SKINS.size()
	hair = (idx * 3 + t_idx * 4) % Constants.HAIRS.size()
	hs = (idx * 7 + t_idx * 3) % 5
	max_speed = 5.0 + spd / 100.0 * 2.7
