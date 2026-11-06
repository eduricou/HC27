## Equip del porter fet amb codi: guardes de foam amb ranures i genollera, xuteres que
## tapen la bota, casc amb la cara oberta, reixa i protector de coll, i guants arrodonits.
## Les peces es fan a l'espai del model en repòs (metres; el model mira cap a +Z i la cama
## esquerra és a +X) i PlayerRig les enganxa a l'os que toca. Els colors van als vèrtexs
## i cada malla es fa una sola vegada per joc de colors.
class_name GkGear
extends RefCounted

## Folre de dins (guardes i casc) i sola de les xuteres.
const LINING := Color("2a2c30")
const CAGE := Color("41464d")

## Guarda: d'on a on va (alçada), centre de la cama i radis de la volta de les puntes.
const PAD_BOT := 0.075
const PAD_TOP := 0.675
const PAD_X := 0.13
const PAD_HALF_W := 0.112
const PAD_DEPTH := 0.064
const PAD_ROUND_BOT := 0.03
const PAD_ROUND_TOP := 0.07
## Genollera (alçada del centre) i ranures del davant.
const KNEE_Y := 0.565
const GROOVES: Array[float] = [0.17, 0.25, 0.33, 0.41, 0.49, 0.645]

## Xutera: de darrere a davant (z), amplada i alçada al turmell i a la punta.
const KICK_X := 0.134
const KICK_Z0 := -0.15
const KICK_Z1 := 0.175

## Closca del casc: centre i radis (el cap fa ±0,09 d'ample i va de 1,58 a 1,81 d'alçada),
## gruix, i fins on baixa (graus d'elevació): al front, a les galtes i al clatell.
const SHELL_C := Vector3(0.0, 1.705, -0.005)
const SHELL_R := Vector3(0.112, 0.128, 0.128)
const SHELL_T := 0.012
const BROW_E := 20.0
const JAW_E := -50.0
const NAPE_E := -45.0
## Vora de color de la closca (graus) i mitja amplada de la franja del mig (metres).
const TRIM_E := 6.0
const STRIPE_W := 0.017
## Reixa: alçades de dalt (al front de la closca) i de baix (sota la barbeta), i angles
## de les barres verticals i dels laterals.
const CAGE_TOP := 1.748
const CAGE_BOT := 1.556
const CAGE_SIDE := 66.0
const CAGE_V: Array[float] = [0.17, 0.36, 0.55, 0.74, 0.92, 1.0]
const CAGE_PHI: Array[float] = [-44.0, -22.0, 0.0, 22.0, 44.0]

static var _cache := {}


## El color de `options` que més es distingeix de `base` (ribets i franges).
static func contrast(base: Color, options: Array[Color]) -> Color:
	var best := options[0]
	for c in options:
		if (
			absf(c.get_luminance() - base.get_luminance())
			> absf(best.get_luminance() - base.get_luminance())
		):
			best = c
	return best


# --- Guardes i xuteres --------------------------------------------------------------


## Guarda de la cama esquerra (side = 1) o dreta (−1): foam corbat davant la canyella, de
## sobre la xutera fins a sobre el genoll, amb la genollera que sobresurt, ranures
## horitzontals i una franja de color al costat de fora.
static func leg_guard(side: float, pad: Color, accent: Color) -> ArrayMesh:
	var key := "pad:%s:%s:%s" % [side, pad.to_html(), accent.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	var n_rows := 48
	var around := 24
	for i in n_rows + 1:
		var y := lerpf(PAD_BOT, PAD_TOP, float(i) / n_rows)
		# Davant de la canyella (la tíbia va una mica enrere cap al turmell).
		var shin := 0.027 - (0.5424 - y) * 0.1124
		var knee := exp(-pow((y - KNEE_Y) / 0.05, 2.0))
		var half_w := PAD_HALF_W + 0.008 * knee
		var depth := PAD_DEPTH + 0.02 * knee
		var groove := 0.0
		for g in GROOVES:
			groove = maxf(groove, exp(-pow((y - g) / 0.008, 2.0)))
		var k := MeshPart.round_ends(y - PAD_BOT, PAD_TOP - y, PAD_ROUND_BOT, PAD_ROUND_TOP)
		var center := Vector3(side * PAD_X, y, shin + 0.006)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in around:
			var th := TAU * j / around
			var s := sin(th)
			var c := cos(th)
			var front := maxf(0.0, c)
			var dz := depth * MeshPart.spow(c, 0.66) - 0.006 * groove * sqrt(front)
			ring.append(center + Vector3(half_w * MeshPart.spow(s, 0.66), 0.0, dz) * k)
			var col := pad.darkened(0.3 * groove * front)
			if c < -0.5:
				col = LINING
			elif s * side > 0.8 and y > 0.13 and y < 0.5:
				col = accent
			rc.append(col)
		rows.append(ring)
		cols.append(rc)
		refs.append(center)
	var part := MeshPart.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, MeshPart.material(0.5))
	_cache[key] = mesh
	return mesh


## Xutera del peu esquerre (side = 1) o dret (−1): tapa la bota, amb la punta rodona i
## baixa, la sola fosca i una tira de color sobre l'empenya.
static func kicker(side: float, pad: Color, accent: Color) -> ArrayMesh:
	var key := "kick:%s:%s:%s" % [side, pad.to_html(), accent.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	var n_rows := 30
	var around := 20
	for i in n_rows + 1:
		var t := float(i) / n_rows
		var z := lerpf(KICK_Z0, KICK_Z1, t)
		var d0 := z - KICK_Z0
		var d1 := KICK_Z1 - z
		# La sola puja una mica a la punta; el damunt hi baixa fent una volta rodona.
		var bot := -0.008 + 0.022 * (1.0 - MeshPart.round_ends(d0, d1, 0.02, 0.04))
		var height := lerpf(0.145, 0.09, smoothstep(0.2, 0.8, t))
		var top := bot + height * MeshPart.round_ends(d0, d1, 0.035, 0.08, 2.5)
		var half_w := lerpf(0.066, 0.06, t) * MeshPart.round_ends(d0, d1, 0.035, 0.06, 2.5)
		var center := Vector3(side * KICK_X, (top + bot) * 0.5, z)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in around:
			var th := TAU * j / around
			var c := cos(th)
			var dy := (top - bot) * 0.5 * MeshPart.spow(c, 0.6 if c >= 0.0 else 0.3)
			ring.append(center + Vector3(half_w * MeshPart.spow(sin(th), 0.6), dy, 0.0))
			var col := pad
			if c < -0.85:
				col = pad.darkened(0.45)
			elif c > 0.3 and t > 0.4 and t < 0.5:
				col = accent
			rc.append(col)
		rows.append(ring)
		cols.append(rc)
		refs.append(center)
	var part := MeshPart.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, MeshPart.material(0.55))
	_cache[key] = mesh
	return mesh


# --- Casc -------------------------------------------------------------------------------


## Casc: closca que tapa el cap per dalt, pels costats i pel clatell, amb la vora de color
## `trim` i una franja `stripe` pel mig; reixa de barres davant la cara (que es veu) i
## protector de coll.
static func helmet(shell: Color, trim: Color, stripe: Color) -> ArrayMesh:
	var key := "helmet:%s:%s:%s" % [shell.to_html(), trim.to_html(), stripe.to_html()]
	if _cache.has(key):
		return _cache[key]
	var mesh := ArrayMesh.new()
	var part := MeshPart.new()
	_shell(part, shell, trim)
	_stripe(part, stripe)
	part.add_to(mesh, MeshPart.material(0.28))
	var cage := MeshPart.new()
	for v in CAGE_V:
		var path := PackedVector3Array()
		for k in 19:
			path.append(_cage_point(lerpf(-CAGE_SIDE, CAGE_SIDE, k / 18.0), v))
		cage.tube(path, 0.0045, CAGE)
	for phi: float in CAGE_PHI + [-CAGE_SIDE, CAGE_SIDE]:
		var path := PackedVector3Array()
		for k in 13:
			path.append(_cage_point(phi, k / 12.0))
		cage.tube(path, 0.0065 if absf(phi) == CAGE_SIDE else 0.0045, CAGE)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = CAGE
	metal.metallic = 0.6
	metal.roughness = 0.35
	cage.add_to(mesh, metal)
	var throat := MeshPart.new()
	_throat_guard(throat, trim)
	var plastic := MeshPart.material(0.35)
	plastic.cull_mode = BaseMaterial3D.CULL_DISABLED
	throat.add_to(mesh, plastic)
	_cache[key] = mesh
	return mesh


static func _shell(part: MeshPart, shell: Color, trim: Color) -> void:
	var cols_n := 48
	var top_rows := 14
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var lining: Array[PackedColorArray] = []
	# Files d'elevació per a cada columna: la vora, el final del ribet (dues vegades, per
	# tallar el color net) i fins al pol.
	for r in top_rows + 3:
		outer.append(PackedVector3Array())
		inner.append(PackedVector3Array())
		var rc := PackedColorArray()
		var lc := PackedColorArray()
		rc.resize(cols_n)
		lc.resize(cols_n)
		rc.fill(trim if r < 2 else shell)
		lc.fill(LINING)
		cols.append(rc)
		lining.append(lc)
	for j in cols_n:
		var phi := -180.0 + 360.0 * j / cols_n
		var edge := shell_edge(phi)
		for r in top_rows + 3:
			var e := edge
			if r >= 1:
				e = lerpf(edge + TRIM_E, 90.0, float(maxi(0, r - 2)) / top_rows)
			outer[r].append(_shell_point(phi, e, 0.0))
			inner[r].append(_shell_point(phi, e, SHELL_T))
	var refs := PackedVector3Array()
	refs.resize(outer.size())
	refs.fill(SHELL_C)
	part.grid(outer, cols, true, refs)
	part.grid(inner, lining, true, refs, true)
	# El cantell: de la vora de fora a la de dins.
	var pole := SHELL_C + Vector3(0.0, SHELL_R.y, 0.0)
	var rim: Array[PackedVector3Array] = [outer[0], inner[0]]
	var rim_cols: Array[PackedColorArray] = [cols[0], cols[0]]
	part.grid(rim, rim_cols, true, PackedVector3Array([pole, pole]))


## Franja pel mig de la closca, del front al clatell, enganxada a la superfície.
static func _stripe(part: MeshPart, color: Color) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	var r2 := SHELL_R * SHELL_R
	# Angle al pla del mig: 0 = endavant, 90 = dalt, més de 90 = cap al clatell.
	var a0 := BROW_E + TRIM_E + 2.0
	var a1 := 180.0 - NAPE_E - TRIM_E - 2.0
	for i in 31:
		var a := deg_to_rad(lerpf(a0, a1, i / 30.0))
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for k in 5:
			var x := STRIPE_W * (k / 2.0 - 1.0)
			var f := sqrt(1.0 - pow(x / SHELL_R.x, 2.0))
			var p := Vector3(x, SHELL_R.y * sin(a) * f, SHELL_R.z * cos(a) * f)
			ring.append(SHELL_C + p + (p / r2).normalized() * 0.0012)
			rc.append(color)
		rows.append(ring)
		cols.append(rc)
		refs.append(SHELL_C)
	part.grid(rows, cols, false, refs)


## Fins on baixa la closca (graus d'elevació) a l'angle `phi` (0 = davant): a la cara, al
## front; als costats, fins a la mandíbula; al darrere, fins al clatell.
static func shell_edge(phi: float) -> float:
	var a := absf(phi)
	var e := lerpf(BROW_E, JAW_E, smoothstep(48.0, 72.0, a))
	return lerpf(e, NAPE_E, smoothstep(110.0, 170.0, a))


static func _shell_point(phi: float, e: float, inset: float) -> Vector3:
	var r := SHELL_R - Vector3.ONE * inset
	var ph := deg_to_rad(phi)
	var el := deg_to_rad(e)
	return SHELL_C + Vector3(r.x * cos(el) * sin(ph), r.y * sin(el), r.z * cos(el) * cos(ph))


## Punt de la reixa: `phi` en graus (0 = davant del nas) i v de 0 (dalt, enganxada al
## front de la closca) a 1 (sota la barbeta). Surt endavant de la cara uns 6 cm.
static func _cage_point(phi: float, v: float) -> Vector3:
	var rise := sin(minf(v / 0.35, 1.0) * PI * 0.5)
	var tuck := smoothstep(0.6, 1.0, v)
	var depth := 0.12 + 0.055 * rise - 0.025 * tuck
	var width := 0.105 + 0.012 * sin(minf(v / 0.3, 1.0) * PI * 0.5) - 0.008 * tuck
	var ph := deg_to_rad(phi)
	return Vector3(width * sin(ph), lerpf(CAGE_TOP, CAGE_BOT, v), SHELL_C.z + depth * cos(ph))


## Protector de coll: una placa corbada que penja de sota la reixa, amb la punta rodona.
static func _throat_guard(part: MeshPart, color: Color) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for i in 9:
		var w := i / 8.0
		var y := CAGE_BOT - 0.004 - 0.052 * w
		var half := 0.052 * sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, (w - 0.5) / 0.5), 2.0)))
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in 13:
			var x := half * (j / 6.0 - 1.0)
			ring.append(Vector3(x, y, 0.128 - 0.05 * w * w - 4.0 * x * x))
			rc.append(color)
		rows.append(ring)
		cols.append(rc)
		refs.append(Vector3(0.0, y, -0.2))
	part.grid(rows, cols, false, refs)


# --- Guants -----------------------------------------------------------------------------


## Guant: una capsa de cantells rodons de mig costat `half`, centrada a l'origen.
static func glove(half: Vector3, color: Color) -> ArrayMesh:
	var key := "glove:%s:%s" % [half, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var refs := PackedVector3Array()
	for i in 13:
		var el := lerpf(-PI * 0.5, PI * 0.5, i / 12.0)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in 20:
			var th := TAU * j / 20.0
			var ce := MeshPart.spow(cos(el), 0.4)
			ring.append(
				Vector3(
					half.x * ce * MeshPart.spow(sin(th), 0.4),
					half.y * MeshPart.spow(sin(el), 0.4),
					half.z * ce * MeshPart.spow(cos(th), 0.4)
				)
			)
			rc.append(color.darkened(0.12) if i < 3 else color)
		rows.append(ring)
		cols.append(rc)
		refs.append(Vector3.ZERO)
	var part := MeshPart.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, MeshPart.material(0.55))
	_cache[key] = mesh
	return mesh
