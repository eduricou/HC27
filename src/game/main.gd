## Arrencada i flux de pantalles: menú (amb un partit de demostració de fons), partit,
## pausa, descans i final. Amb `-- --scenario=<nom>` prepara situacions per a captures
## (tools/shot.sh, tools/shot_views.sh) i proves (tools/smoke.sh, tools/bench.sh):
##   menu · intro · match · human · pc · pause · break · full · smoke · smoke_human ·
##   bench · views · follow (càmera que segueix un jugador de tools/views.json mentre
##   juga: --cams=jugador_davant)
## Altres arguments: --time=tarda|nit (per defecte, nit), --quality=baixa|mitjana|alta|ultra
## i, per provar, --qset=clau=valor,... (canvia valors del preset; vegeu Quality.override).
## ref: línies 1940–2029 (startMatch(), backToMenu(), togglePause(), start())
extends Node

## Temps màxim de joc dels escenaris smoke abans de donar-los per fallats.
const SMOKE_LIMIT := 900.0
const VIEWS_PATH := "res://tools/views.json"
const VIEWS_OUT := "res://build/shots/godot"
## Fotogrames d'espera abans de cada captura (que s'estabilitzin el cel i les ombres).
const VIEWS_SETTLE := 12

var mode: StringName = &"menu"
var scenario := ""
var _opts := {"side": 0, "diff": "normal", "qlen": 150.0}
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _phase := 0
var _frames := 0
var _events := {}
var _shots: Array = []
var _settle := 0

@onready var stadium: Stadium = $Stadium
@onready var runner: MatchRunner = $Runner
@onready var view: MatchView = $View
@onready var cam: CameraRig = $Camera
@onready var hud: Hud = $Hud
@onready var menu: MainMenu = $Menu


func _ready() -> void:
	InputActions.ensure()
	_rng.randomize()
	var q := Quality.preset(_arg("quality") if _arg("quality") != "" else Quality.DEFAULT)
	Quality.override(q, _arg("qset"))
	Quality.apply_viewport(q, get_viewport())
	stadium.apply_quality(q)
	if _arg("res3d") != "":
		# Mesura de rendiment a una resolució 3D més gran que la finestra (p. ex. 1440p).
		var h := float(_arg("res3d").split("x")[1])
		get_viewport().scaling_3d_scale = h / get_viewport().get_visible_rect().size.y
	stadium.set_night(_arg("time") != "tarda")
	menu.night = stadium.night
	menu.night_changed.connect(stadium.set_night)
	runner.stepped.connect(stadium.on_step)
	runner.stepped.connect(view.on_events)
	view.runner = runner
	cam.runner = runner
	cam.view = view
	hud.runner = runner
	runner.stepped.connect(hud.on_events)
	runner.stepped.connect(_count_events)
	runner.quarter_break.connect(_on_break)
	runner.quarter_started.connect(hud.hide_break)
	runner.full_time.connect(_on_full_time)
	hud.resume_requested.connect(toggle_pause)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(go_menu)
	hud.next_quarter_requested.connect(runner.next_quarter)
	hud.play_again_requested.connect(_restart)
	menu.play_requested.connect(start_match)
	scenario = _arg("scenario")
	_start_scenario()


## Torna al menú amb un partit de demostració de fons. ref: backToMenu()
func go_menu() -> void:
	mode = &"menu"
	stadium.fx.reset()
	runner.start(_rng.randi(), MatchState.DEMO_QLEN, -1, "normal", &"demo")
	runner.input_enabled = false
	hud.set_match_visible(false)
	view.sync_now()
	cam.snap()
	menu.open()


## Partit nou. side: 0 Iluro, 1 Polo, −1 CPU contra CPU. ref: startMatch()
func start_match(side: int, diff: String, qlen: float) -> void:
	mode = &"match"
	_opts = {"side": side, "diff": diff, "qlen": qlen}
	var seed_value := _rng.randi()
	print(
		"Partit nou · llavor %d · costat %d · %s · quarts de %d s" % [seed_value, side, diff, qlen]
	)
	stadium.fx.reset()
	runner.start(seed_value, qlen, side, diff, &"match")
	runner.input_enabled = true
	runner.input_grace = 20
	menu.close()
	hud.set_match_visible(true)
	view.sync_now()
	cam.snap()


## ref: togglePause()
func toggle_pause() -> void:
	if mode != &"match" or runner.sim == null:
		return
	var st := runner.sim.s.state
	if st == &"break" or st == &"full":
		return
	runner.paused = not runner.paused
	runner.input_enabled = not runner.paused
	hud.show_pause(runner.paused)


func _restart() -> void:
	hud.hide_break()
	hud.show_pause(false)
	start_match(_opts["side"], _opts["diff"], _opts["qlen"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


## Si la finestra perd el focus durant el joc, es posa en pausa (com la web quan la
## pestanya s'amaga). No als escenaris, que corren sense ningú davant.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or scenario != "":
		return
	if mode == &"match" and runner.sim and not runner.paused:
		toggle_pause()


func _on_break() -> void:
	hud.show_break(false)


func _on_full_time() -> void:
	hud.show_break(true)


func _count_events(events: Array[Dictionary]) -> void:
	for e in events:
		_events[e["type"]] = _events.get(e["type"], 0) + 1


# --- Escenaris -----------------------------------------------------------------------


func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return ""


func _start_scenario() -> void:
	match scenario:
		"", "menu":
			go_menu()
		"intro":
			start_match(-1, "normal", 150.0)
		"match", "pause", "bench":
			_quick_match(-1, 20.0)
			if scenario == "pause":
				toggle_pause()
			if scenario == "bench":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				Engine.max_fps = 0
		"human":
			runner.autopilot = Autopilot.new(3)
			_quick_match(0, 12.0)
		"pc":
			_quick_match(-1, 0.0)
			Rules.setup_pc(runner.sim.s, runner.sim.s.teams[0], 1.0, &"test")
			runner.fast_forward(40)
			view.sync_now()
			cam.snap()
		"break", "full":
			_quick_match(-1, 0.0)
			var s := runner.sim.s
			if scenario == "full":
				s.quarter = 4
			s.clock = 1.0
			# El servei de centre no fa córrer el rellotge: cal arribar al joc.
			runner.fast_forward(240)
			view.sync_now()
			cam.snap()
		"views":
			_quick_match(-1, 25.0)
			runner.paused = true
			hud.visible = false
			_shots = _view_list()
			if _arg("action") != "":
				# Tots els jugadors fan l'acció (revisar animacions: --action=celebrate).
				view.trigger_all(StringName(_arg("action")))
			if _arg("net") != "":
				# Xarxa de la porteria dreta deformant-se, `net` segons després del gol.
				stadium.fx.net_side = 1
				stadium.fx.net_y = 0.4
				stadium.fx.net_t = float(_arg("net"))
		"follow":
			_quick_match(-1, 8.0)
			hud.visible = false
			_shots = _view_list()
		"smoke":
			start_match(-1, "normal", 40.0)
		"smoke_human":
			runner.autopilot = Autopilot.new(5)
			start_match(0, "normal", 40.0)
		_:
			push_error("Escenari desconegut: %s" % scenario)
			go_menu()


## Partit sense presentació, avançat `seconds` segons.
func _quick_match(side: int, seconds: float) -> void:
	start_match(side, "normal", 150.0)
	runner.sim.s.intro_t = 0.0
	runner.fast_forward(roundi(seconds * 60.0))
	view.sync_now()
	cam.snap()


func _process(delta: float) -> void:
	if runner.sim:
		stadium.update_frame()
	if scenario == "views":
		_views_step()
	elif scenario == "follow" and not _shots.is_empty():
		cam.set_fixed(_resolve_view(_shots[0][1]))
	elif scenario.begins_with("smoke"):
		_smoke_step(delta)
	elif scenario == "bench":
		_bench_step(delta)


## Recorregut complet sense ningú: partit → descansos → final → menú. Ho fa tools/smoke.sh.
func _smoke_step(delta: float) -> void:
	_t += delta
	var s := runner.sim.s if runner.sim else null
	if _t > SMOKE_LIMIT:
		print("SMOKE FALLA: temps esgotat (estat %s)" % (s.state if s else &"cap"))
		get_tree().quit(1)
		return
	if _phase == 0 and s and s.state == &"break" and s.human_idx >= 0:
		# Amb humà, el descans espera el botó: el premem al cap d'un segon.
		if fmod(_t, 1.0) < delta:
			hud.next_quarter_requested.emit()
	if _phase == 0 and s and s.state == &"full":
		_phase = 1
		var summary := (
			"%s %d–%d %s · %d quarts · llavor %d"
			% [
				s.teams[0].def.short,
				s.score[0],
				s.score[1],
				s.teams[1].def.short,
				s.quarter,
				runner.seed_used,
			]
		)
		print("SMOKE: partit acabat · ", summary)
		_t = 0.0
	elif _phase == 1 and _t > 1.0:
		hud.menu_requested.emit()
		_phase = 2
		_t = 0.0
	elif _phase == 2 and _t > 2.0:
		var ok := mode == &"menu" and runner.sim.s.mode == &"demo"
		print("SMOKE: esdeveniments ", _events)
		print("SMOKE OK" if ok else "SMOKE FALLA: no ha tornat al menú")
		get_tree().quit(0 if ok else 1)


## Mesura de fps: 2 s d'escalfament i després `--seconds` segons (10 per defecte).
func _bench_step(delta: float) -> void:
	_t += delta
	if _phase == 0 and _t > 2.0:
		_phase = 1
		_t = 0.0
		_frames = 0
		return
	if _phase != 1:
		return
	_frames += 1
	var secs := float(_arg("seconds")) if _arg("seconds") != "" else 10.0
	if _t >= secs:
		var size := get_viewport().get_visible_rect().size
		var fps := _frames / _t
		var scale := get_viewport().scaling_3d_scale
		print(
			(
				"BENCH: %.0f fps de mitjana (%.2f ms per fotograma) · %dx%d (3D a %dx%d) · %s · %s · %s"
				% [
					fps,
					1000.0 / fps,
					size.x,
					size.y,
					roundi(size.x * scale),
					roundi(size.y * scale),
					stadium.quality.get("name", "?"),
					"nit" if stadium.night else "tarda",
					RenderingServer.get_video_adapter_name(),
				]
			)
		)
		get_tree().quit()


## Combinacions [angle, nit] de l'escenari views: --cams=a,b (per defecte, totes les de
## tools/views.json) i --times=tarda,nit. Amb --net=<segons>, la xarxa de la dreta surt
## deformada com després d'un gol; amb --action=<animació>, tots els jugadors la fan.
func _view_list() -> Array:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VIEWS_PATH))
	all.erase("_doc")
	var cams: Array = all.keys() if _arg("cams") in ["", "tots"] else Array(_arg("cams").split(","))
	var times := (_arg("times") if _arg("times") != "" else "tarda,nit").split(",")
	var out := []
	for t in times:
		for c: String in cams:
			if all.has(c):
				out.append([c, all[c], t == "nit"])
			else:
				push_error("Angle desconegut: %s" % c)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VIEWS_OUT))
	return out


## Captures dels angles fixos, una cada VIEWS_SETTLE fotogrames. Ho fa tools/shot_views.sh.
func _views_step() -> void:
	if _shots.is_empty():
		get_tree().quit()
		return
	var shot: Array = _shots[0]
	if _frames == 0:
		# Canviar de tarda a nit fa refer el cel i el mapa de reflexos: s'espera més.
		_settle = VIEWS_SETTLE * (4 if stadium.night != shot[2] else 1)
		stadium.set_night(shot[2])
		cam.set_fixed(_resolve_view(shot[1]))
	_frames += 1
	if _frames < _settle:
		return
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [VIEWS_OUT, shot[0], "nit" if shot[2] else "tarda"]
	img.save_png(ProjectSettings.globalize_path(path))
	print("Captura: ", ProjectSettings.globalize_path(path))
	_shots.pop_front()
	_frames = 0


## Angle fix que segueix un jugador ("follow": [equip, dorsal] a tools/views.json).
func _resolve_view(v: Dictionary) -> Dictionary:
	if not v.has("follow"):
		return v
	var target: Player = null
	for p in runner.sim.s.players:
		if p.team.idx == int(v["follow"][0]) and p.num == int(v["follow"][1]):
			target = p
	if target == null:
		return v
	var a := target.face + deg_to_rad(float(v["ang"]))
	var d := float(v["dist"])
	return {
		"ex": target.x + cos(a) * d,
		"ey": target.y + sin(a) * d,
		"ez": float(v["h"]),
		"tx": target.x,
		"ty": target.y,
		"tz": 0.95,
		"w": float(v["w"]),
	}
