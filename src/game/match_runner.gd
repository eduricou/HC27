## Fa avançar la simulació a pas fix (60 Hz, a _physics_process) i n'avisa la presentació.
## Gestiona la pausa, el descans (la CPU contra CPU continua sola al cap de 5 s, com a la
## web) i el final del partit. ref: frame(), showBreak() de reference/web/index.html
class_name MatchRunner
extends Node

## Esdeveniments de cada pas de simulació (còpia de MatchState.events).
signal stepped(events: Array[Dictionary])
signal quarter_break
signal quarter_started
signal full_time

const BREAK_AUTO_SECONDS := 5.0

var sim: MatchSim
var paused := false
## Si no és nul, genera l'entrada humana en lloc del teclat (només per a proves).
var autopilot: Autopilot
## Fals mentre hi ha un menú obert: l'entrada no arriba a la simulació.
var input_enabled := true
## Passos en què encara s'ignora l'entrada (que la tecla que ha triat l'opció del menú no
## salti també la presentació).
var input_grace := 0
var seed_used := 0
var _break_t := 0.0
var _last_state: StringName = &""


func start(
	seed_value: int, qlen: float, side: int, diff: String, mode: StringName = &"match"
) -> void:
	stop()
	seed_used = seed_value
	sim = MatchSim.new(seed_value, qlen, side, diff, mode)
	paused = false
	_break_t = 0.0
	_last_state = sim.s.state


func stop() -> void:
	if sim:
		sim.dispose()
	sim = null


func _physics_process(_delta: float) -> void:
	tick()


## Un pas de 60 Hz. Les proves el criden directament.
func tick() -> void:
	if sim == null or paused:
		return
	var s := sim.s
	if s.state == &"break":
		if s.human_idx < 0:
			_break_t += Constants.STEP
			if _break_t >= BREAK_AUTO_SECONDS:
				next_quarter()
		return
	if s.state == &"full":
		return
	if s.human_idx >= 0:
		if autopilot:
			autopilot.drive(s, s.input)
		elif input_grace > 0 or not input_enabled:
			input_grace = maxi(0, input_grace - 1)
			HumanController.compose(s.input, Vector2.ZERO, false, false, false, false, false)
		else:
			HumanController.poll(s.input)
	sim.step()
	stepped.emit(s.events.duplicate())
	if s.state != _last_state:
		if s.state == &"break":
			_break_t = 0.0
			quarter_break.emit()
		elif s.state == &"full":
			full_time.emit()
	_last_state = s.state


## Després del descans, comença el quart següent.
func next_quarter() -> void:
	if sim and sim.s.state == &"break":
		sim.next_quarter()
		_last_state = sim.s.state
		quarter_started.emit()


## Avança `steps` passos de cop (escenaris de captura i proves).
func fast_forward(steps: int) -> void:
	for i in steps:
		tick()


func _exit_tree() -> void:
	stop()
