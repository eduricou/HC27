## Indicador del jugador controlat: damunt del cap, un triangle i el dorsal amb el nom; als
## peus, la barra de resistència i, mentre es carrega el xut, la de potència i una línia
## discontínua cap on anirà la pilota. Es dibuixa en 2D projectant des de la càmera.
## ref: render() (showCtrl, línies 1816–1849)
class_name PlayerMarker
extends Control

const HEAD_Z := 2.3

var runner: MatchRunner
var view: MatchView
var camera: Camera3D
var _drawn := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	# Sense ningú a marcar (CPU contra CPU), no cal redibuixar res.
	var any := runner != null and runner.sim != null and marked(runner.sim.s) != null
	if any or _drawn:
		queue_redraw()
	_drawn = any


## Jugador que s'ha de marcar (nul si no n'hi ha cap). ref: showCtrl
static func marked(s: MatchState) -> Player:
	var c := s.ctrl
	if s.mode != &"match" or c == null or not c.team.human:
		return null
	if s.state == &"replay" or s.state == &"goal" or s.intro_t > 0.0:
		return null
	return c


func _draw() -> void:
	if runner == null or runner.sim == null or view == null or camera == null:
		return
	var s := runner.sim.s
	var p := marked(s)
	if p == null:
		return
	var i := s.players.find(p)
	var pos := view.player_sim_pos(i)
	var head_w := Coords.to_view(pos.x, pos.y, HEAD_Z)
	var foot_w := Coords.to_view(pos.x, pos.y, 0.0)
	if camera.is_position_behind(head_w) or camera.is_position_behind(foot_w):
		return
	# unproject_position() ja dona coordenades del rectangle visible (les dels Control).
	var hd := camera.unproject_position(head_w)
	var ft := camera.unproject_position(foot_w)
	var col := Color(p.team.def.ring)
	# Línia de xut mentre es carrega. ref: humanAim()
	if s.charge > 0.0 and s.ball.owner == p:
		var a := HumanControl.human_aim(s, p)
		var length := 2.0 + s.charge * 7.0
		var tip_w := Coords.to_view(pos.x + cos(a) * length, pos.y + sin(a) * length, 0.0)
		if not camera.is_position_behind(tip_w):
			var tip := camera.unproject_position(tip_w)
			var lc := (
				Color(1.0, 0.35, 0.24, 0.85) if s.charge > 0.85 else Color(1.0, 0.75, 0.43, 0.8)
			)
			draw_dashed_line(ft, tip, lc, 3.0, 8.0, true, true)
	# Triangle i etiqueta damunt del cap.
	var y := hd.y - 6.0
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(hd.x, y + 8), Vector2(hd.x - 8, y - 4), Vector2(hd.x + 8, y - 4)]
		),
		col
	)
	var font := UiKit.font(&"ui")
	var fs := 18
	var text := "%d %s" % [p.num, p.name.split(" ")[0]]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var box := Rect2(hd.x - tw * 0.5, y - 30.0, tw, 23.0)
	draw_style_box(UiKit.style(Color(10 / 255.0, 18 / 255.0, 15 / 255.0, 0.82), 5), box)
	draw_string(
		font,
		Vector2(box.position.x + 7.0, box.position.y + 17.5),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		UiKit.INK
	)
	# Resistència i potència sota els peus.
	var bw := clampf((ft.y - hd.y) * 0.75, 34.0, 90.0)
	var by := ft.y + clampf((ft.y - hd.y) * 0.12, 8.0, 18.0)
	draw_rect(Rect2(ft.x - bw * 0.5, by, bw, 4.0), Color(0, 0, 0, 0.5))
	var stc := Color("9fdc6a") if p.stamina > 0.3 else Color("e0a03a")
	draw_rect(Rect2(ft.x - bw * 0.5, by, bw * clampf(p.stamina, 0.0, 1.0), 4.0), stc)
	if s.charge > 0.0 and s.ball.owner == p:
		draw_rect(Rect2(ft.x - bw * 0.5, by + 7.0, bw, 8.0), Color(0, 0, 0, 0.55))
		var cc := Color("ff4b3a") if s.charge > 0.85 else UiKit.ORANGE
		draw_rect(Rect2(ft.x - bw * 0.5, by + 7.0, bw * s.charge, 8.0), cc)
