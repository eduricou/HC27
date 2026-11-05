## Un equip en joc: jugadors, sentit d'atac, rols de la IA i dificultat efectiva.
## ref: makeTeam(), diffOf()
class_name Team
extends RefCounted

var def: TeamData
var idx: int
## Sentit d'atac: +1 ataca cap a x positiva, −1 cap a x negativa.
var dir: int
var players: Array[Player] = []
var gk: Player
## L'equip rival (ref: other()). Es fixa a MatchState.new_game().
var opp: Team
var human := false
## Rols que assigna la IA a cada pas (ref: assignRoles()).
var chaser: Player
var presser: Player
var cover: Player

## Dificultat efectiva de l'equip (ref: diffOf()). Es fixa a MatchState.new_game().
var df_react := 0.38
var df_err := 1.0
var df_spd := 1.0
var df_tack := 1.0
var df_gk := 0.0


## ref: makeTeam()
func _init(p_def: TeamData, p_idx: int, rng: SimRng) -> void:
	def = p_def
	idx = p_idx
	dir = 1 if p_idx == 0 else -1
	var cnt := {"DF": 0, "MF": 0, "FW": 0}
	for k in def.squad.size():
		var p := Player.new(self, k, def.squad[k], rng)
		if p.is_gk:
			gk = p
		else:
			var sl: Array = Constants.SLOTS[p.pos][cnt[p.pos]]
			cnt[p.pos] += 1
			p.has_slot = true
			p.slot_x = float(sl[0])
			p.slot_y = float(sl[1])
		players.append(p)


func set_difficulty(d: Dictionary) -> void:
	df_react = d["react"]
	df_err = d["err"]
	df_spd = d["spd"]
	df_tack = d["tack"]
	df_gk = d["gk"]
