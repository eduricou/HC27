## Sons del partit a partir dels esdeveniments de la simulació (com MatchView amb les
## animacions). Els cops, la pilota i la porteria sonen en 3D al lloc on passen (la càmera
## escolta, i a la repetició de prop sonen més a prop); el xiulet i el públic no tenen lloc.
## El públic és el d'un camp petit (unes desenes de persones): murmuri continu en dues capes
## que s'anima a prop de la porteria i als córners curts, crits i aplaudiments als gols,
## aplaudiments a les aturades i als finals de quart.
## ref: SFX.hit(), SFX.whistle(), SFX.crowd() i les seves crides (línies 404–943)
class_name MatchSound
extends Node3D

const VOICES := 14
## Cada tipus d'esdeveniment de la simulació i què fa sonar (la prova de la fase 6 hi busca
## tots els que emet src/sim/).
const SOUNDS := {
	&"kick": "pal: passada, cop o xut, més fort com més ràpida va la pilota",
	&"control": "la pilota al pal en rebre-la",
	&"deflect": "rebot al pal",
	&"tackle": "pals que xoquen",
	&"save": "proteccions del porter, i aplaudiments",
	&"post": "pal de la porteria, i el públic s'aixeca",
	&"net": "taula de fons o xarxa (a la repetició)",
	&"goal": "taula de fons o xarxa, i el públic (crits si marca l'Iluro, que juga a casa)",
	&"whistle": "xiulet: un bufet per a cada «count», de «strength» segons",
	&"intro_end": "aplaudiments",
	&"quarter_end": "aplaudiments",
	&"pc": "el públic s'anima",
	&"switch": "clic de canvi de jugador (bus Interfície)",
	&"wipe": "whoosh de la cortineta (bus Interfície)",
	&"replay_start": "el públic baixa",
}
## Esdeveniments que no fan cap so propi, i per què.
const SILENT := {
	&"restart": "la simulació ja emet un «whistle» a part",
	&"replay_end": "la cortineta («wipe») ja sona",
}
## Alçada de la taula de fons de la porteria (m): per sota, el gol fa «bum».
const BACKBOARD_H := 0.46
const WHISTLE_GAP := 0.14
## Murmuri del públic (dB) en calma i amb la màxima emoció.
const CROWD_DB: Array[float] = [-10.0, -14.0]
const CROWD_RANGE := 9.0
## Guany de tota la barreja del partit. Amb +4 dB, al gol (el moment més fort) el
## limitador del Master hi treu menys d'1 dB (tools/audio_check.sh, docs/decisions/0009).
const MIX_DB := 4.0

var runner: MatchRunner
## Sense pantalla (proves) no hi ha sortida d'àudio i el mesclador no allibera els sons
## aturats: no se'n reprodueix cap, però queden apuntats a `played` igualment.
var silent := DisplayServer.get_name() == "headless"
## Darrers sons demanats: [so, dB] (per a les proves).
var played: Array = []
## Guany (dB) de tot el partit: més fluix amb el menú obert (partit de demostració).
var level_db := 0.0
## Emoció del públic (0–1): puja amb les jugades de perill i baixa sola.
var excitement := 0.0

var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _whistle: AudioStreamPlayer
var _whistle_tween: Tween
var _blasts: Array = []
var _crowd: Array[AudioStreamPlayer] = []
var _reactions: Array[AudioStreamPlayer] = []
var _ui: AudioStreamPlayer
var _tension := 0.0
var _prev_z := 0.0
var _prev_vz := 0.0
var _frame := -1
var _steps_this_frame := 0


func _ready() -> void:
	# Després del MatchRunner, que fa el pas de simulació.
	process_physics_priority = 10
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"Efectes"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 20.0
		p.max_db = 3.0
		p.panning_strength = 0.6
		add_child(p)
		_voices.append(p)
	_whistle = _player(&"Efectes")
	_whistle.stream = SfxBank.pick(&"sfx/whistle")
	for snd in [&"crowd/murmur_a", &"crowd/murmur_b"]:
		var c := _player(&"Ambient")
		var st: AudioStream = SfxBank.pick(snd)
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		c.stream = st
		_crowd.append(c)
	for i in 3:
		_reactions.append(_player(&"Ambient"))
	_ui = _player(&"Interficie")


## Fa callar tot el partit (en tancar el joc).
func silence() -> void:
	_blasts.clear()
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
		elif c is AudioStreamPlayer3D:
			(c as AudioStreamPlayer3D).stop()


## En sortir (tancar el joc), s'aturen tots els sons: si un bucle encara sona quan
## es tanca el servidor d'àudio, Godot no allibera el flux.
func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stream = null
		elif c is AudioStreamPlayer3D:
			(c as AudioStreamPlayer3D).stream = null


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## Comença el murmuri del públic (partit nou o menú). Cada capa a un punt diferent: les
## dues duren 80 i 108 s i així el bucle no es nota.
func start_crowd() -> void:
	for i in _crowd.size():
		var c := _crowd[i]
		if silent:
			break
		if c.stream and not c.playing:
			c.volume_db = CROWD_DB[i] + level_db
			c.play(SfxBank.randf_range(0.0, maxf(0.0, c.stream.get_length() - 1.0)))
	excitement = 0.0


func _process(delta: float) -> void:
	excitement = move_toward(excitement, _tension, delta * (0.22 if excitement > _tension else 0.8))
	var paused := runner != null and runner.paused
	for i in _crowd.size():
		var db := CROWD_DB[i] + excitement * CROWD_RANGE + level_db - (10.0 if paused else 0.0)
		_crowd[i].volume_db = lerpf(_crowd[i].volume_db, db, 1.0 - exp(-delta * 4.0))
	for b: Array in _blasts:
		b[0] -= delta
	while not _blasts.is_empty() and _blasts[0][0] <= 0.0:
		var b: Array = _blasts.pop_front()
		_blast(b[1])


func _physics_process(_delta: float) -> void:
	if runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	# Tensió de fons: la pilota a prop d'una porteria o un córner curt en joc.
	var t := 0.0
	if s.state == &"pc" or s.pc_live:
		t = 0.55
	elif s.state == &"play" and absf(s.ball.x) > Constants.HL - Constants.CR - 4.0:
		t = 0.3
	_tension = maxf(t, _tension - 0.004)


## Esdeveniments d'un pas de simulació. ref: SFX.hit()/whistle()/crowd() i on es criden
func on_events(events: Array[Dictionary]) -> void:
	if runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	# En avançar molts passos de cop (escenaris de proves), no sona res.
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_steps_this_frame = 0
	_steps_this_frame += 1
	var mute := _steps_this_frame > 10
	_ball_landing(s, mute)
	if mute:
		return
	for e in events:
		play_event(s, e)


func play_event(s: MatchState, e: Dictionary) -> void:
	var b := s.ball
	var at := Coords.to_view(b.x, b.y, b.z)
	match e["type"]:
		&"kick":
			var k := clampf(float(e.get("speed", 10.0)) / 30.0, 0.0, 1.0)
			if e.get("kind") == &"pass":
				_hit(&"sfx/stick_pass", at, lerpf(-15.0, -6.0, k), SfxBank.randf_range(1.2, 1.45))
			else:
				var pitch := SfxBank.randf_range(1.1, 1.3)
				_hit(&"sfx/stick_hit", at, lerpf(-9.0, 0.0, k), pitch)
		&"control":
			_hit(&"sfx/control", at, -17.0, SfxBank.randf_range(1.3, 1.6))
		&"deflect":
			_hit(&"sfx/control", at, -10.0, SfxBank.randf_range(0.95, 1.15))
		&"tackle":
			var p: Player = e.get("player")
			var pos := Coords.to_view(p.x, p.y, 0.5) if p else at
			_hit(&"sfx/tackle", pos, -9.0, SfxBank.randf_range(1.2, 1.45))
		&"save":
			_hit(&"sfx/pads", at, -4.0, SfxBank.randf_range(0.9, 1.1))
			_react(&"crowd/applause", -13.0)
			_bump(0.5)
		&"post":
			_hit(&"sfx/post", at, -3.0, SfxBank.randf_range(0.95, 1.05))
			_bump(0.8)
		&"net":
			_goal_hit(s, at)
		&"goal":
			_goal_hit(s, at)
			# L'Iluro juga a casa: els seus gols, crits i aplaudiments; els del Polo, uns
			# quants aplaudiments dels seus.
			if int(e.get("team", 0)) == 0:
				_react(&"crowd/cheer", -3.0)
				_react(&"crowd/applause", -7.0)
			else:
				_react(&"crowd/applause", -12.0)
			_bump(1.0)
		&"whistle":
			whistle(float(e.get("strength", 0.3)), int(e.get("count", 1)))
		&"intro_end":
			_react(&"crowd/applause", -11.0)
		&"quarter_end":
			_react(&"crowd/applause", -9.0)
		&"pc":
			_bump(0.6)
		&"switch":
			_ui_play(&"ui/switch", -16.0)
		&"wipe":
			_ui_play(&"ui/whoosh", -9.0)
		&"replay_start":
			excitement *= 0.5


## Bufets del xiulet, com SFX.whistle(dur, n): n bufets de dur segons separats 0,14 s.
func whistle(dur: float, count: int) -> void:
	var t := 0.0
	for k in maxi(1, count):
		_blasts.append([t, dur])
		t += dur + WHISTLE_GAP


func pending_blasts() -> int:
	return _blasts.size()


func _blast(dur: float) -> void:
	if _whistle_tween:
		_whistle_tween.kill()
	_whistle.volume_db = -9.0 + level_db + MIX_DB
	_note(&"sfx/whistle", _whistle.volume_db)
	if silent:
		return
	_whistle.play()
	_whistle_tween = create_tween()
	_whistle_tween.tween_interval(maxf(0.0, dur - 0.04))
	_whistle_tween.tween_property(_whistle, "volume_db", -60.0, 0.04)
	_whistle_tween.tween_callback(_whistle.stop)


## Gol o pilota a la xarxa: per sota de la taula de fons, el «bum» de la fusta.
func _goal_hit(s: MatchState, at: Vector3) -> void:
	if s.ball.z < BACKBOARD_H:
		_hit(&"sfx/backboard", at, 0.0, SfxBank.randf_range(0.9, 1.05))
	else:
		_hit(&"sfx/net", at, -6.0, SfxBank.randf_range(0.9, 1.1))


## La pilota toca la gespa després d'anar per l'aire.
func _ball_landing(s: MatchState, mute: bool) -> void:
	var b := s.ball
	if not mute and _prev_z > 0.02 and b.z <= 0.0:
		var k := clampf(-_prev_vz / 8.0, 0.0, 1.0)
		_hit(&"sfx/ball_turf", Coords.to_view(b.x, b.y, 0.0), lerpf(-20.0, -7.0, k), 1.0)
	# Velocitat vertical vista (a la repetició, la simulació no la porta).
	_prev_vz = (b.z - _prev_z) / Constants.STEP
	_prev_z = b.z


func _hit(sound: StringName, at: Vector3, db: float, pitch: float) -> void:
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = SfxBank.pick(sound)
	p.position = at
	p.volume_db = db + level_db + MIX_DB
	p.pitch_scale = pitch
	_note(sound, p.volume_db)
	if not silent:
		p.play()


func _react(sound: StringName, db: float) -> void:
	var p: AudioStreamPlayer = _reactions[0]
	for r in _reactions:
		if not r.playing:
			p = r
			break
	p.stream = SfxBank.pick(sound)
	p.volume_db = db + level_db + MIX_DB
	_note(sound, p.volume_db)
	if not silent:
		p.play()


func _ui_play(sound: StringName, db: float) -> void:
	_ui.stream = SfxBank.pick(sound)
	_ui.volume_db = db + level_db + MIX_DB
	_note(sound, _ui.volume_db)
	if not silent:
		_ui.play()


func _note(sound: StringName, db: float) -> void:
	played.append([sound, db])
	if played.size() > 32:
		played.pop_front()


## El públic s'anima de cop (gol, aturada, pal...) i després es calma sol.
func _bump(v: float) -> void:
	excitement = maxf(excitement, v)
	_tension = maxf(_tension, v * 0.4)
