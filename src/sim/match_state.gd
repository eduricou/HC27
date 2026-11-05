## Estat complet d'un partit: equips, pilota, marcador, rellotge i màquina d'estats.
## Correspon a les variables globals teams, players, ball i G de la referència.
## ref: línies 340–361 (newGame(), diffOf(), possTeam(), other())
class_name MatchState
extends RefCounted

const INTRO_TIME := 4.2
const DEMO_QLEN := 75.0

var rng: SimRng
var input := SimInput.new()
var teams: Array[Team] = []
var players: Array[Player] = []
var ball: Ball

## &"match" (partit) o &"demo" (partit de fons del menú, sense descansos).
var mode: StringName = &"match"
var human_idx := -1
var diff := "normal"
## Durada real de cada quart (segons).
var qlen := 150.0
var quarter := 1
## Rellotge del partit (segons de joc que queden del quart).
var clock := Constants.QGAME
## &"restart", &"play", &"pc", &"goal", &"replay", &"break" o &"full".
var state: StringName = &"restart"
var state_t := 0.0
var restart_type: StringName = &""
var restart_team: Team
var restart_taker: Player
var score := PackedInt32Array([0, 0])
var stat_poss := PackedFloat64Array([0.0, 0.0])
var stat_shots := PackedInt32Array([0, 0])
var stat_on := PackedInt32Array([0, 0])
var stat_pcs := PackedInt32Array([0, 0])
var stat_fouls := PackedInt32Array([0, 0])
var goals: Array[Dictionary] = []
## Jugador controlat per l'humà.
var ctrl: Player
var last_poss: Team
var charge := 0.0
var shoot_consumed := false
var pc_live := false
var pc_t := 0.0
var pc_team: Team
var pc_inj: Player
var pc_hit: Player
var end_pending := false
var time := 0.0
var intro_t := 0.0
var rec := ReplayBuffer.new()
var replay: Array[PackedFloat32Array] = []
var replay_len := 0
var rp_i := 0.0
var rp_end := 0.0
var next_center: Team
var switch_t := 0.0
var goal_side := 1
var scorer: Player
var wiped := false
## Comptadors de diagnosi de la IA. ref: G.dbg
var dbg := {"pass": 0, "tack": 0, "tack_win": 0, "entry": [0, 0]}

## Trajectòria prevista de la pilota (x, y cada 0,1 s). Es calcula quan cal a partir de
## l'estat de la pilota a l'inici de l'últim updatePlayers(). ref: predictTraj(), G.traj
var traj := PackedFloat64Array()
## Fals fins al primer update_players(): a la web G.traj comença buit i interceptT()
## retorna NaN.
var traj_ready := false
var traj_dirty := true
var traj_bx := 0.0
var traj_by := 0.0
var traj_bvx := 0.0
var traj_bvy := 0.0
## Resultat de la intercepció (ref: interceptT() retorna [t, x, y]).
var icpt_x := 0.0
var icpt_y := 0.0
## Resultats de les funcions que retornen un punt. Van en float (64 bits) i no en
## Vector2 (32 bits) perquè els càlculs coincideixin amb els de la web.
## st_*: BallActions.stick_pt(). out_*: Ai.base_pos(), mark_pos() i support_pos().
var st_x := 0.0
var st_y := 0.0
var out_x := 0.0
var out_y := 0.0
## Millor passada trobada per Ai.best_pass().
var bp_q: Player
var bp_score := 0.0
var bp_tx := 0.0
var bp_ty := 0.0
var bp_through := false

## Vectors de treball de Movement.collide().
var col_x := PackedFloat64Array()
var col_y := PackedFloat64Array()
var col_lock := PackedByteArray()

## Esdeveniments de l'últim pas, perquè la presentació hi reaccioni (so, rètols,
## animacions). Cada un és un diccionari amb la clau "type".
var events: Array[Dictionary] = []


func _init(seed_value: int = 0) -> void:
	rng = SimRng.new(seed_value)
	traj.resize(46)


## ref: newGame()
func new_game(p_mode: StringName, side: int, p_diff: String, p_qlen: float) -> void:
	dispose()
	teams = [Team.new(TeamData.load_default(0), 0, rng), Team.new(TeamData.load_default(1), 1, rng)]
	teams[0].opp = teams[1]
	teams[1].opp = teams[0]
	players = []
	players.append_array(teams[0].players)
	players.append_array(teams[1].players)
	ball = Ball.new()
	mode = p_mode
	human_idx = side if p_mode == &"match" else -1
	if human_idx >= 0:
		teams[human_idx].human = true
	diff = p_diff
	qlen = p_qlen if p_mode == &"match" else DEMO_QLEN
	for t in teams:
		var cpu_diff := mode == &"match" and human_idx >= 0 and not t.human
		t.set_difficulty(Constants.DIFFS[diff if cpu_diff else "normal"])
	quarter = 1
	clock = Constants.QGAME
	state = &"restart"
	state_t = 0.0
	restart_type = &""
	restart_team = null
	restart_taker = null
	score = PackedInt32Array([0, 0])
	stat_poss = PackedFloat64Array([0.0, 0.0])
	stat_shots = PackedInt32Array([0, 0])
	stat_on = PackedInt32Array([0, 0])
	stat_pcs = PackedInt32Array([0, 0])
	stat_fouls = PackedInt32Array([0, 0])
	goals = []
	ctrl = null
	last_poss = teams[0]
	charge = 0.0
	shoot_consumed = false
	pc_live = false
	pc_t = 0.0
	pc_team = null
	pc_inj = null
	pc_hit = null
	end_pending = false
	time = 0.0
	rec.clear()
	replay = []
	replay_len = 0
	rp_i = 0.0
	rp_end = 0.0
	next_center = null
	switch_t = 0.0
	traj_ready = false
	traj_dirty = true
	goal_side = 1
	scorer = null
	wiped = false
	dbg = {"pass": 0, "tack": 0, "tack_win": 0, "entry": [0, 0]}
	events = []
	Rules.kickoff(self, teams[0])
	intro_t = INTRO_TIME if mode == &"match" else 0.0


## L'altre equip. ref: other()
func other(t: Team) -> Team:
	return teams[1 - t.idx]


## Equip que té (o ha tingut per últim cop) la pilota. ref: possTeam()
func poss_team() -> Team:
	return ball.owner.team if ball.owner else last_poss


## Afegeix un esdeveniment per a la presentació.
func emit(data: Dictionary) -> void:
	events.append(data)


func human_team() -> Team:
	for t in teams:
		if t.human:
			return t
	return null


## Estadístiques en el mateix format que window.__estic.simulate() de la web.
func stats_dict() -> Dictionary:
	return {
		"poss": [stat_poss[0], stat_poss[1]],
		"shots": [stat_shots[0], stat_shots[1]],
		"on": [stat_on[0], stat_on[1]],
		"pcs": [stat_pcs[0], stat_pcs[1]],
		"fouls": [stat_fouls[0], stat_fouls[1]],
	}


## Trenca les referències circulars (jugador ↔ equip) perquè la memòria s'alliberi.
func dispose() -> void:
	for p in players:
		p.team = null
	for t in teams:
		t.players.clear()
		t.gk = null
		t.chaser = null
		t.presser = null
		t.cover = null
		t.opp = null
	players = []
	teams = []
	if ball:
		ball.owner = null
		ball.last_touch = null
		ball.last_team = null
		ball.last_by = [null, null]
		ball.valid_for = null
		ball.pass_target = null
	restart_team = null
	restart_taker = null
	ctrl = null
	last_poss = null
	pc_team = null
	pc_inj = null
	pc_hit = null
	next_center = null
	scorer = null
	bp_q = null
