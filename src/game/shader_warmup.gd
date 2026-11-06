## Escalfament de shaders. Abans d'ensenyar el menú (i després de canviar la qualitat
## gràfica), dibuixa d'amagat, sota una cortina, el que el partit ensenyarà i el menú no:
## l'estadi des dels angles de la presentació, del córner curt, de la repetició i del gol,
## de tarda i de nit, i tot el HUD. Així Godot crea abans de jugar els pipelines que li
## falten, i no n'ha de compilar cap en dibuixar quan comença el partit (decisió 0010).
class_name ShaderWarmup
extends CanvasLayer

signal finished

## Angles [ex, ey, ez, tx, ty, tz, w] en coordenades de la simulació (com CameraRig).
const VIEWS := [
	[-78.0, 91.5, 46.0, -6.0, -22.0, 6.0, 170.0],  # inici de la presentació, des de l'aire
	[0.0, 67.5, 28.0, 0.0, -4.0, 0.0, 58.0],  # TV àmplia
	[52.7, 0.0, 8.0, 36.7, 0.0, 0.0, 34.0],  # córner curt, porteria de la dreta
	[-52.7, 0.0, 8.0, -36.7, 0.0, 0.0, 34.0],  # córner curt, porteria de l'esquerra
	[20.0, 11.0, 10.0, 43.0, 0.0, 0.0, 27.0],  # repetició: aèria
	[25.0, 30.5, 1.6, 37.0, 0.0, 0.7, 17.0],  # repetició: arran de gespa
	[50.3, 2.5, 5.2, 40.0, 0.0, 0.5, 30.0],  # repetició: darrere de la porteria
	[30.0, 12.0, 4.4, 33.0, 0.0, 1.1, 13.0],  # primer pla del golejador
	[0.0, -15.0, 5.0, 0.0, 40.0, 3.0, 90.0],  # cap a la bardissa i el talús
	[10.0, 20.0, 2.0, 30.0, -40.0, 3.0, 80.0],  # cap al passeig, les casetes i el carrer
]
const FADE := 0.25

var running := false
var _curtain: ColorRect


func _ready() -> void:
	layer = 10
	_curtain = ColorRect.new()
	_curtain.color = UiKit.DARK
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_curtain)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var l := UiKit.kicker(tr("Carregant"), 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_curtain.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Fa l'escalfament i ho deixa tot com estava: la llum, la càmera i el HUD amagat (només
## es fa al menú). L'entrada de la interfície queda aturada fins que s'acaba.
func run(stadium: Stadium, cam: CameraRig, hud: Hud) -> void:
	if running:
		return
	running = true
	visible = true
	_curtain.modulate.a = 1.0
	var vp := get_viewport()
	vp.gui_disable_input = true
	var night := stadium.night
	hud.show_all()
	for n: bool in [not night, night]:
		# Els pipelines no depenen de la mida dels mapes d'ombres: es deixen els de la llum
		# que es fa servir, perquè no hi hagi mai els dos mapes grans alhora (memòria).
		stadium.set_night(n, false)
		for v: Array in VIEWS:
			cam.fixed = PackedFloat64Array(v)
			cam.snap()
			await get_tree().process_frame
	cam.fixed = PackedFloat64Array()
	cam.snap()
	hud.set_match_visible(false)
	var tw := create_tween()
	tw.tween_property(_curtain, "modulate:a", 0.0, FADE)
	await tw.finished
	visible = false
	vp.gui_disable_input = false
	running = false
	finished.emit()
