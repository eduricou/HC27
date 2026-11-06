## Equipacions d'un equip al menú (.kitprev de la web): un jugador de camp i el porter, en
## 3D i en repòs, dins d'un SubViewport amb el seu propi món i llum.
## ref: drawKitPreview()
class_name KitPreview
extends SubViewportContainer

const SIZE := Vector2i(220, 320)

var _sim: MatchSim
var _vp: SubViewport
var _rigs: Array[PlayerRig] = []
var _players: Array[Player] = []


## team_idx: 0 Iluro, 1 Polo. El porter va a la banda de fora de la placa.
func setup(team_idx: int) -> void:
	stretch = true
	custom_minimum_size = Vector2(SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	_vp = vp
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.74)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 30.0 if team_idx == 0 else -30.0, 0.0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 25.0
	var eye := Vector3(0.0, 1.1, 5.4)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.9, 0.0) - eye), eye)
	vp.add_child(cam)
	_sim = MatchSim.new(7, 150.0, -1)
	var team := _sim.s.teams[team_idx]
	var field: Player = null
	for p in team.players:
		if p.num == 10:
			field = p
	if field == null:
		field = team.players[team.players.size() - 1]
	var order: Array[Player] = [field, team.gk]
	if team_idx == 1:
		order.reverse()
	for i in 2:
		var p := order[i]
		var rig := PlayerRig.new()
		vp.add_child(rig)
		rig.setup(p, team.def)
		rig.position = Vector3(-0.55 + 1.1 * i, 0.0, 0.0)
		# Mirant a càmera, una mica girats cap al centre de la placa.
		rig.rotation.y = PI + (0.35 if i == 0 else -0.35)
		_rigs.append(rig)
		_players.append(p)


## Només es dibuixa amb el menú obert: cada vista 3D a part costa temps de GPU.
func set_active(on: bool) -> void:
	if _vp:
		_vp.render_target_update_mode = (
			SubViewport.UPDATE_WHEN_VISIBLE if on else SubViewport.UPDATE_DISABLED
		)
	set_process(on)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for i in _rigs.size():
		_rigs[i].animate(_players[i], 0.0, delta)


func _exit_tree() -> void:
	if _sim:
		_sim.dispose()
		_sim = null
