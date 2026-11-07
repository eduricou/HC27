## Càmera del partit. Modes (ref: CAM, camTarget(), updateCamera(), línies 1208–1247):
## - TV: des de la banda (costat +y), seguint la pilota; «ampla» (opció del menú) és més
##   alta i més lluny.
## - Presentació: vol d'apropament des de l'aire fins a la TV mentre dura intro_t.
## - Gol: primer pla del golejador (0,7 s després del gol).
## - Repetició multiangle (la simulació ja la passa a mitja velocitat): una càmera aèria
##   que segueix la jugada, una de banda arran de gespa i, per al xut i el gol, la de la web
##   darrere de la porteria. Els canvis d'angle són talls.
## - Córner curt (nova): darrere de la porteria que es defensa, des de la preparació fins
##   que acaba la jugada. Amb aquesta càmera, els controls giren amb ella (MatchRunner).
## Treballa en coordenades de la simulació i converteix amb Coords.
class_name CameraRig
extends Camera3D

enum Mode { TV, INTRO, GOAL, REPLAY, PC }

const HL := Constants.HL
const HW := Constants.HW
const GHW := Constants.GHW
## Constants de suavitzat per mode (s⁻¹). ref: updateCamera() (TV 3,2, repetició 4, gol 1,8)
const SMOOTH := {Mode.TV: 3.2, Mode.GOAL: 1.8, Mode.REPLAY: 4.0, Mode.PC: 2.5}
## Inici del vol de la presentació. ref: camTarget() (mode intro)
const INTRO_FROM := [-78.0, HW + 64.0, 46.0, -6.0, -22.0, 6.0, 170.0]
const INTRO_LEN := 4.2
## Fotogrames de la repetició (a 60 per segon de joc) que mostra cada angle abans del gol:
## l'aèria fins a 200 abans de l'últim, la de banda fins a 100 i després la de la porteria.
const REPLAY_CUTS: Array[int] = [200, 100]

var runner: MatchRunner
var view: MatchView
var mode := Mode.TV
## Opció «Càmera: Àmplia» del menú.
var wide := false
## Opció «Càmera darrere de la porteria als córners curts».
var pc_enabled := true

## Ull (ex, ey, ez), objectiu (tx, ty, tz) i amplada visible w, com CAM a la web.
var ex := 0.0
var ey := HW + 30.0
var ez := 17.0
var tx := 0.0
var ty := -2.0
var tz := 0.0
var w := 44.0
## Si no és buit, angle fix [ex, ey, ez, tx, ty, tz, w] (captures de tools/shot_views.sh).
var fixed := PackedFloat64Array()

var _replay_angle := -1
## Bàndol de la porteria del córner curt (+1 o −1).
var _pc_side := 1.0


func _ready() -> void:
	near = 0.5
	# Fins a l'horitzó (el terra arriba a 4 km): la càmera ampla el veu.
	far = 6000.0
	_apply()


func _process(delta: float) -> void:
	if not fixed.is_empty():
		_set_view(fixed)
		return
	if runner == null or runner.sim == null or view == null:
		return
	var prev := mode
	var prev_angle := _replay_angle
	mode = pick_mode(runner.sim.s)
	var g := target()
	var cut := mode != prev and mode != Mode.GOAL
	cut = cut or (mode == Mode.REPLAY and _replay_angle != prev_angle)
	if mode == Mode.INTRO or cut:
		_set_view(g)
	else:
		var k := 1.0 - exp(-delta * float(SMOOTH[mode]))
		ex += (g[0] - ex) * k
		ey += (g[1] - ey) * k
		ez += (g[2] - ez) * k
		tx += (g[3] - tx) * k
		ty += (g[4] - ty) * k
		tz += (g[5] - tz) * k
		w += (g[6] - w) * k
		_apply()
	runner.camera_angle = control_angle()


## Mode que toca segons l'estat de la simulació. ref: updateCamera()
func pick_mode(s: MatchState) -> Mode:
	if s.mode == &"match" and s.intro_t > 0.0:
		return Mode.INTRO
	if s.state == &"replay":
		return Mode.REPLAY
	if s.state == &"goal":
		if mode == Mode.GOAL or s.state_t > 0.7:
			return Mode.GOAL
		return mode if mode == Mode.PC else Mode.TV
	if pc_enabled and s.mode == &"match":
		if s.state == &"pc" or (s.state == &"play" and s.pc_live):
			if s.pc_team and mode != Mode.PC:
				_pc_side = float(s.pc_team.dir)
			return Mode.PC
	return Mode.TV


## Posa la càmera directament al seu objectiu (partit nou, captures).
func snap() -> void:
	if not fixed.is_empty():
		_set_view(fixed)
	elif runner and runner.sim and view:
		mode = pick_mode(runner.sim.s)
		_set_view(target())
		runner.camera_angle = control_angle()


## Angle fix a partir d'un diccionari com els de tools/views.json (buit: torna al partit).
func set_fixed(v: Dictionary) -> void:
	if v.is_empty():
		fixed = PackedFloat64Array()
	else:
		fixed = PackedFloat64Array([v["ex"], v["ey"], v["ez"], v["tx"], v["ty"], v["tz"], v["w"]])
	snap()


## Gir de la direcció dels controls: 0 amb la TV (amunt a la pantalla = −y de la
## simulació); amb altres càmeres, amunt és cap on mira la càmera.
func control_angle() -> float:
	if mode == Mode.TV or mode == Mode.INTRO:
		return 0.0
	var f := Vector2(tx - ex, ty - ey)
	if f.length() < 0.01:
		return 0.0
	return wrapf(f.angle() + PI * 0.5, -PI, PI)


func target() -> PackedFloat64Array:
	match mode:
		Mode.INTRO:
			return intro_target()
		Mode.GOAL:
			return goal_target()
		Mode.REPLAY:
			return replay_target()
		Mode.PC:
			return pc_target()
	return tv_target()


func _set_view(g: PackedFloat64Array) -> void:
	ex = g[0]
	ey = g[1]
	ez = g[2]
	tx = g[3]
	ty = g[4]
	tz = g[5]
	w = g[6]
	_apply()


## [ex, ey, ez, tx, ty, tz, w] del mode TV (i de l'ampla). ref: tvTarget()
func tv_target() -> PackedFloat64Array:
	var s := runner.sim.s
	var bp := view.ball_sim_pos()
	var fx := bp.x + s.ball.vx * 0.25
	var fy := bp.y + s.ball.vy * 0.15
	var ctrl := s.ctrl
	if s.mode == &"match" and ctrl and ctrl.team.human and s.state == &"play":
		var cp := view.player_sim_pos(s.players.find(ctrl))
		fx = fx * 0.85 + cp.x * 0.15
		fy = fy * 0.85 + cp.y * 0.15
	var asp := _aspect()
	var land := asp >= 1.0
	var dist := 40.0 if wide else 26.0
	var h := 28.0 if wide else 13.0
	var lim := (14.0 if wide else 11.0) if land else 5.0
	var cx := clampf(fx, -HL + lim, HL - lim)
	var cy := clampf(fy * 0.8, -16.0, 16.0) - (4.0 if wide else 1.5)
	var base := clampf(13.0 * asp + 8.0, 33.0, 40.0) if land else 24.0
	return PackedFloat64Array([cx, HW + dist, h, cx, cy, 0.0, base * (1.45 if wide else 1.0)])


## Vol de la presentació: de l'aire a la TV, amb sortida i arribada suaus. ref: camTarget()
func intro_target() -> PackedFloat64Array:
	var b := tv_target()
	var k := 1.0 - clampf(runner.sim.s.intro_t / INTRO_LEN, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var out := PackedFloat64Array()
	for i in 7:
		out.append(lerpf(INTRO_FROM[i], b[i], e))
	return out


## Primer pla del golejador. ref: camTarget() (mode goal)
func goal_target() -> PackedFloat64Array:
	var s := runner.sim.s
	var sc := s.scorer
	if sc == null:
		return tv_target()
	var p := view.player_sim_pos(s.players.find(sc))
	return PackedFloat64Array([p.x - sc.team.dir * 3.0, p.y + 12.0, 4.4, p.x, p.y, 1.1, 13.0])


## Angle de la repetició (0 aèria, 1 banda, 2 porteria) segons el fotograma que es mostra.
static func replay_angle(rp_i: float, length: int) -> int:
	var left := float(length - 1) - rp_i
	if left > REPLAY_CUTS[0]:
		return 0
	if left > REPLAY_CUTS[1]:
		return 1
	return 2


func replay_target() -> PackedFloat64Array:
	var s := runner.sim.s
	var bp := view.ball_sim_pos()
	var bx := bp.x
	var by := bp.y
	var sd := float(s.goal_side) if s.goal_side != 0 else 1.0
	_replay_angle = replay_angle(s.rp_i, s.replay_len)
	match _replay_angle:
		0:
			# Alta, per darrere de la jugada i una mica des de la banda de la TV, mirant
			# cap a la porteria.
			return PackedFloat64Array(
				[bx - sd * 16.0, by * 0.5 + 11.0, 10.0, bx + sd * 7.0, by * 0.9, 0.0, 27.0]
			)
		1:
			# Arran de gespa, des de la banda de la TV, mirant cap a la porteria.
			var cy := HW + 3.0
			return PackedFloat64Array([bx - sd * 7.0, cy, 1.6, bx + sd * 5.0, by * 0.85, 0.7, 17.0])
	# Darrere de la porteria. ref: camTarget() (mode replay)
	return PackedFloat64Array(
		[
			sd * (HL + 4.6),
			clampf(by * 0.3, -7.0, 7.0) + 2.5,
			5.2,
			lerpf(bx, sd * HL, 0.2),
			by * 0.8,
			0.5,
			30.0,
		]
	)


## Darrere de la porteria que es defensa al córner curt, alta: a baix es veu la línia de
## fons amb el porter i els defensors, i a dalt el cercle i els atacants.
func pc_target() -> PackedFloat64Array:
	var d := _pc_side
	var bp := view.ball_sim_pos()
	var follow := clampf(bp.y * 0.15, -3.0, 3.0)
	return PackedFloat64Array(
		[d * (HL + 7.0), follow, 8.0, d * (HL - 9.0), follow * 1.5, 0.0, 34.0]
	)


func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(1.0, size.y)


## Col·loca la càmera i calcula el camp de visió vertical perquè a la distància de
## l'objectiu es vegin `w` metres d'amplada. ref: setMatrices()
func _apply() -> void:
	var eye := Coords.to_view(ex, ey, ez)
	var tgt := Coords.to_view(tx, ty, tz)
	var d := eye.distance_to(tgt)
	var a := _aspect()
	var fy := clampf(2.0 * atan((w * 0.5) / d / a), 0.16, 1.3)
	fov = rad_to_deg(fy)
	keep_aspect = Camera3D.KEEP_HEIGHT
	if eye.distance_to(tgt) > 0.01:
		look_at_from_position(eye, tgt, Vector3.UP)
