## Càmera TV: des de la banda (costat +y), a 13 m d'alçada, seguint la pilota amb una
## mica d'avançament i suavitzada. La fase 5 hi afegirà la presentació, el gol i la
## repetició. Treballa en coordenades de la simulació i converteix amb Coords.
## ref: CAM, setMatrices(), tvTarget() i updateCamera() (línies 1208–1247)
class_name CameraRig
extends Camera3D

const HL := Constants.HL
const HW := Constants.HW
## Constant de suavitzat del mode TV (ref: updateCamera(), 3,2 s⁻¹).
const SMOOTH := 3.2

var runner: MatchRunner
var view: MatchView

## Ull (ex, ey, ez), objectiu (tx, ty, tz) i amplada visible w, com CAM a la web.
var ex := 0.0
var ey := HW + 30.0
var ez := 17.0
var tx := 0.0
var ty := -2.0
var tz := 0.0
var w := 44.0


func _ready() -> void:
	near = 0.5
	far = 900.0
	_apply()


func _process(delta: float) -> void:
	if runner == null or runner.sim == null or view == null:
		return
	var g := tv_target()
	var k := 1.0 - exp(-delta * SMOOTH)
	ex += (g[0] - ex) * k
	ey += (g[1] - ey) * k
	ez += (g[2] - ez) * k
	tx += (g[3] - tx) * k
	ty += (g[4] - ty) * k
	tz += (g[5] - tz) * k
	w += (g[6] - w) * k
	_apply()


## Posa la càmera directament al seu objectiu (partit nou, captures).
func snap() -> void:
	if runner == null or runner.sim == null or view == null:
		return
	var g := tv_target()
	ex = g[0]
	ey = g[1]
	ez = g[2]
	tx = g[3]
	ty = g[4]
	tz = g[5]
	w = g[6]
	_apply()


## [ex, ey, ez, tx, ty, tz, w] del mode TV. ref: tvTarget()
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
	var dist := 26.0
	var h := 13.0
	var lim := 11.0 if land else 5.0
	var cx := clampf(fx, -HL + lim, HL - lim)
	var cy := clampf(fy * 0.8, -16.0, 16.0) - 1.5
	var base := clampf(13.0 * asp + 8.0, 33.0, 40.0) if land else 24.0
	return PackedFloat64Array([cx, HW + dist, h, cx, cy, 0.0, base])


func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(1.0, size.y)


## Col·loca la càmera i calcula el camp de visió vertical perquè a la distància de
## l'objectiu es vegin `w` metres d'amplada. ref: setMatrices()
func _apply() -> void:
	var eye := Coords.to_view(ex, ey, ez)
	var target := Coords.to_view(tx, ty, tz)
	var d := eye.distance_to(target)
	var a := _aspect()
	var fy := clampf(2.0 * atan((w * 0.5) / d / a), 0.16, 1.3)
	fov = rad_to_deg(fy)
	keep_aspect = Camera3D.KEEP_HEIGHT
	if eye.distance_to(target) > 0.01:
		look_at_from_position(eye, target, Vector3.UP)
