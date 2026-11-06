## Opcions del joc i darreres eleccions del menú, desades a user://opcions.cfg amb
## ConfigFile (a Windows: %APPDATA%\Godot\app_userdata\Estic Hoquei Herba\). Les aplica
## main.gd en arrencar i el menú d'opcions quan canvien.
class_name GameSettings
extends RefCounted

const PATH := "user://opcions.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
## Mode de finestra: finestra, pantalla completa (sense vores) i pantalla completa exclusiva.
const WINDOW_MODES: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]
const VSYNC_MODES: Array[DisplayServer.VSyncMode] = [
	DisplayServer.VSYNC_DISABLED,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_ADAPTIVE,
]
const FPS_LIMITS: Array[int] = [0, 60, 120, 144, 165, 240]
## Escala 3D amb FSR 2.2 (1 = desactivat, resolució nativa).
const FSR_SCALES: Array[float] = [1.0, 0.77, 0.67, 0.59, 0.5]
const QLENS: Array[float] = [90.0, 150.0, 240.0]
const DIFFS: Array[String] = ["facil", "normal", "dificil"]

# --- Pantalla ---
## Mida de la finestra (en mode finestra). (0, 0): la de project.godot.
var resolution := Vector2i.ZERO
var window_mode := 0
var vsync := 1
var fps_limit := 0
var quality := Quality.DEFAULT
var fsr := 1.0
# --- So (volums lineals 0–1, per bus) ---
var volumes := {&"Master": 1.0, &"Ambient": 0.8, &"Efectes": 0.9, &"Interficie": 0.8}
# --- Tecles (InputActions.current) ---
var bindings := {}
# --- Partit (darreres eleccions del menú) ---
## 0 Iluro, 1 Polo, −1 CPU contra CPU.
var side := 0
var diff := "normal"
var qlen := 150.0
## Com a la web, per defecte el partit és de nit.
var night := true
## Càmera del partit: "tv" o "ampla". Per defecte, l'àmplia (la web hi posa la TV, però a
## l'usuari li agrada més; totes dues són al menú).
var cam := "ampla"
## Càmera darrere de la porteria als córners curts.
var pc_cam := true
## Vibració del comandament en xuts, entrades i gols.
var vibration := true


func load_file(path: String = PATH) -> bool:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return false
	var res: Variant = cf.get_value("pantalla", "resolucio", resolution)
	resolution = res if res is Vector2i else Vector2i.ZERO
	window_mode = clampi(int(cf.get_value("pantalla", "mode", window_mode)), 0, 2)
	vsync = clampi(int(cf.get_value("pantalla", "vsync", vsync)), 0, 2)
	fps_limit = maxi(0, int(cf.get_value("pantalla", "limit_fps", fps_limit)))
	var q := str(cf.get_value("pantalla", "qualitat", quality))
	quality = q if q in Quality.NAMES else Quality.DEFAULT
	fsr = clampf(float(cf.get_value("pantalla", "fsr", fsr)), 0.5, 1.0)
	for bus: StringName in volumes.keys():
		volumes[bus] = clampf(float(cf.get_value("so", String(bus), volumes[bus])), 0.0, 1.0)
	bindings = {}
	for action: StringName in InputActions.ACTIONS:
		# Amb get_value(..., null), Godot dona error si la clau no hi és.
		if not cf.has_section_key("tecles", String(action)):
			continue
		var b: Variant = cf.get_value("tecles", String(action))
		if b is Dictionary:
			bindings[action] = b
	side = clampi(int(cf.get_value("partit", "costat", side)), -1, 1)
	var d := str(cf.get_value("partit", "dificultat", diff))
	diff = d if d in DIFFS else "normal"
	var ql := float(cf.get_value("partit", "quart", qlen))
	qlen = ql if ql in QLENS else 150.0
	night = bool(cf.get_value("partit", "nit", night))
	cam = "tv" if str(cf.get_value("partit", "camera", cam)) == "tv" else "ampla"
	pc_cam = bool(cf.get_value("joc", "camera_corner", pc_cam))
	vibration = bool(cf.get_value("joc", "vibracio", vibration))
	return true


func save_file(path: String = PATH) -> Error:
	var cf := ConfigFile.new()
	cf.set_value("pantalla", "resolucio", resolution)
	cf.set_value("pantalla", "mode", window_mode)
	cf.set_value("pantalla", "vsync", vsync)
	cf.set_value("pantalla", "limit_fps", fps_limit)
	cf.set_value("pantalla", "qualitat", quality)
	cf.set_value("pantalla", "fsr", fsr)
	for bus: StringName in volumes:
		cf.set_value("so", String(bus), volumes[bus])
	for action: StringName in bindings:
		cf.set_value("tecles", String(action), bindings[action])
	cf.set_value("partit", "costat", side)
	cf.set_value("partit", "dificultat", diff)
	cf.set_value("partit", "quart", qlen)
	cf.set_value("partit", "nit", night)
	cf.set_value("partit", "camera", cam)
	cf.set_value("joc", "camera_corner", pc_cam)
	cf.set_value("joc", "vibracio", vibration)
	return cf.save(path)


## Mode de finestra, mida, VSync i límit de fps.
func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := WINDOW_MODES[window_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED and resolution != Vector2i.ZERO:
		var screen := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(screen)
		var size := Vector2i(mini(resolution.x, area.size.x), mini(resolution.y, area.size.y))
		if DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(area.position + (area.size - size) / 2)
	DisplayServer.window_set_vsync_mode(VSYNC_MODES[vsync])
	Engine.max_fps = fps_limit


## Preset de qualitat amb l'escala FSR de les opcions. `forced`: el de la línia d'ordres.
func graphics_preset(forced: String = "") -> Dictionary:
	var q := Quality.preset(forced if forced != "" else quality)
	q["fsr"] = fsr
	return q


func apply_audio() -> void:
	AudioBuses.ensure()
	for bus: StringName in volumes:
		AudioBuses.set_volume(bus, volumes[bus])


func apply_input() -> void:
	InputActions.apply(bindings)


## Desa a `bindings` l'assignació de tecles activa.
func store_input() -> void:
	bindings = InputActions.current.duplicate(true)


## Resolucions de la llista que caben a la pantalla.
static func resolutions_for(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out
