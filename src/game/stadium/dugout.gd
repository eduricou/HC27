## Banquetes de l'Iluro com les reals (foto de l'usuari, 7/11/2026): una sola estructura
## amb el sostre blanc pla i continu; a sota, les dues banquetes de tres trams i, al mig,
## la cabina de la taula. El marc és d'acer taronja i els plafons, negres (amb una barra
## taronja a mitja alçada). A cada banqueta hi ha vuit cadires blanques de plàstic, i a la
## cabina, la taula blanca amb l'escut i el rètol «ILURO HOCKEY CLUB».
## Coordenades locals: x al llarg, y amunt i z cap al camp. El darrere és a z = 0.
class_name Dugout
extends RefCounted

## Alçada fins al sostre i fondària (StadiumLayout).
const H := StadiumLayout.BENCH_H
const D := StadiumLayout.BENCH_Y0 - StadiumLayout.BENCH_Y1
const SEATS := 8
const ORANGE := Color("e5671b")
const PANEL := Color("16181b")
const WHITE := Color("eeefec")
const SEAT := Color("e9ebe9")
const STEEL := Color("8b9096")
const TURF := Color("4f6a45")


## La banqueta sencera (no fa servir Stadium, per a les proves).
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Banquetes"
	var frame := MeshPart.new()
	var panels := MeshPart.new()
	var white := MeshPart.new()
	var seats := MeshPart.new()
	var legs := MeshPart.new()
	var all := units()
	var x_min: float = all[0][0]
	var x_max: float = all[-1][1]
	# Sostre pla, una mica més gran que les banquetes, amb el cantell de davant.
	white.box(
		Vector3(x_min - 0.15, H, -0.08), Vector3(x_max + 0.15, H + 0.1, D + 0.22), WHITE, true
	)
	white.box(
		Vector3(x_min - 0.15, H - 0.06, D + 0.18), Vector3(x_max + 0.15, H + 0.14, D + 0.25), WHITE
	)
	for u: Array in all:
		var x0: float = u[0]
		var x1: float = u[1]
		var bays: int = u[2]
		_unit(frame, panels, x0, x1, bays)
		if u[3]:
			for i in SEATS:
				var cx := x0 + (i + 0.5) * (x1 - x0) / SEATS
				_seat(seats, legs, Vector3(cx, 0.0, 0.62))
	# Cabina: terra de gespa i la taula.
	white.box(Vector3(-0.85, 0.0, D - 0.75), Vector3(0.85, 0.86, D - 0.08), WHITE)
	white.box(Vector3(-0.9, 0.86, D - 0.8), Vector3(0.9, 0.9, D - 0.04), WHITE)
	panels.box(Vector3(-1.16, 0.0, 0.06), Vector3(1.16, 0.012, D), TURF)
	var mesh := ArrayMesh.new()
	frame.add_to(mesh, _material(0.45, 0.35))
	panels.add_to(mesh, _material(0.3, 0.0))
	white.add_to(mesh, _material(0.6, 0.0))
	var plastic := _material(0.35, 0.0)
	plastic.cull_mode = BaseMaterial3D.CULL_DISABLED
	seats.add_to(mesh, plastic)
	legs.add_to(mesh, _material(0.4, 0.6))
	var mi := MeshInstance3D.new()
	mi.name = "Estructura"
	mi.mesh = mesh
	root.add_child(mi)
	root.add_child(_crest(Vector3(0.0, 0.47, D - 0.075)))
	root.add_child(_text("ILURO", &"display", 96, Vector3(0.0, 1.86, 0.075), Color.WHITE))
	root.add_child(_text("HOCKEY CLUB", &"ui_medium", 44, Vector3(0.0, 1.63, 0.075), Color.WHITE))
	var fascia := _text("ILURO Hockey Club", &"ui", 36, Vector3(-6.4, H + 0.04, D + 0.255), PANEL)
	root.add_child(fascia)
	return root


## Trams, d'esquerra a dreta: [x0, x1, nombre de trams, té cadires]. Les banquetes,
## de StadiumLayout.BENCH_X i BENCH_W; la cabina, de BOOTH_W.
static func units() -> Array:
	var out := []
	var half := StadiumLayout.BENCH_W * 0.5
	for i in StadiumLayout.BENCH_X.size():
		var cx: float = StadiumLayout.BENCH_X[i]
		out.append([cx - half, cx + half, 3, true])
	var b := StadiumLayout.BOOTH_W * 0.5
	out.insert(1, [-b, b, 1, false])
	return out


## Un tram: pals, barres i plafons negres al darrere i als costats.
static func _unit(frame: MeshPart, panels: MeshPart, x0: float, x1: float, bays: int) -> void:
	var t := 0.08
	# Pals del darrere (un a cada tram) i dels dos extrems de davant.
	for i in bays + 1:
		var x := lerpf(x0, x1, float(i) / bays)
		frame.box(Vector3(x - t * 0.5, 0.0, 0.0), Vector3(x + t * 0.5, H, t), ORANGE)
	for x: float in [x0, x1]:
		frame.box(Vector3(x - t * 0.5, 0.0, D - t), Vector3(x + t * 0.5, H, D), ORANGE)
		# Barres dels costats: a dalt i a mitja alçada.
		frame.box(Vector3(x - 0.03, H - 0.08, t), Vector3(x + 0.03, H, D - t), ORANGE)
		frame.box(Vector3(x - 0.03, 1.18, t), Vector3(x + 0.03, 1.25, D - t), ORANGE)
		panels.box(Vector3(x - 0.012, 0.03, t), Vector3(x + 0.012, H - 0.08, D - t), PANEL)
	# Barres del darrere: a dalt, a mitja alçada i a baix.
	for y: Vector2 in [Vector2(H - 0.08, H), Vector2(1.18, 1.25), Vector2(0.0, 0.05)]:
		frame.box(Vector3(x0, y.x, 0.0), Vector3(x1, y.y, t), ORANGE)
	panels.box(Vector3(x0, 0.05, 0.02), Vector3(x1, H - 0.08, 0.05), PANEL)


## Cadira de plàstic: closca d'una peça (seient i respatller, una mica enfonsada pels
## costats) sobre quatre potes. `at`, el peu del mig; mira cap a +z.
static func _seat(shell: MeshPart, legs: MeshPart, at: Vector3) -> void:
	# Perfil de la closca, de la vora de davant a dalt del respatller: (y, z).
	var profile: Array[Vector2] = [
		Vector2(0.425, 0.21),
		Vector2(0.45, 0.185),
		Vector2(0.455, 0.06),
		Vector2(0.445, -0.09),
		Vector2(0.47, -0.17),
		Vector2(0.58, -0.215),
		Vector2(0.72, -0.235),
		Vector2(0.85, -0.225),
		Vector2(0.865, -0.205),
	]
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for i in profile.size():
		var pr := profile[i]
		var back := smoothstep(0.46, 0.6, pr.x)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in 9:
			var u := j / 4.0 - 1.0
			var lift := 0.035 * pow(absf(u), 3.0)
			var half := lerpf(0.21, 0.195, back)
			var p := Vector3(u * half, pr.x + lift * (1.0 - back), pr.y + lift * back)
			ring.append(at + p)
			rc.append(SEAT)
		rows.append(ring)
		cols.append(rc)
		refs.append(at + Vector3(0.0, pr.x - 0.3, pr.y - 0.3))
	shell.grid(rows, cols, false, refs)
	# Potes i travesser.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var top := at + Vector3(sx * 0.16, 0.44, sz * 0.13)
			var foot := at + Vector3(sx * 0.19, 0.0, sz * 0.18)
			legs.tube(PackedVector3Array([foot, top]), 0.011, STEEL, 5)
		var a := at + Vector3(sx * 0.18, 0.12, -0.16)
		legs.tube(PackedVector3Array([a, a + Vector3(0.0, 0.0, 0.32)]), 0.009, STEEL, 5)


## L'escut de l'Iluro a la taula.
static func _crest(at: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Escut"
	s.texture = UiKit.crest(0)
	s.pixel_size = 0.42 / maxf(1.0, s.texture.get_height())
	s.position = at
	s.shaded = true
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return s


static func _text(text: String, font: StringName, size: int, at: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = "Retol_" + text.replace(" ", "")
	l.text = text
	l.font = UiKit.font(font)
	l.font_size = size
	l.pixel_size = 0.0028
	l.outline_size = 0
	l.modulate = color
	l.shaded = true
	l.double_sided = false
	l.position = at
	return l


static func _material(roughness: float, metallic: float) -> StandardMaterial3D:
	var m := MeshPart.material(roughness)
	m.metallic = metallic
	return m
