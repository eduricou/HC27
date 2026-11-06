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


## Malla en construcció: vèrtexs, normals, colors i triangles d'una superfície.
class Part:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()

	## Graella pts[i][j]: i al llarg, j al voltant (si `closed`, la volta es tanca). Les
	## normals surten de la mateixa graella i miren lluny de refs[i] (el centre de cada
	## anella), o cap a dins si `inward`.
	func grid(
		pts: Array[PackedVector3Array],
		cols: Array[PackedColorArray],
		closed: bool,
		refs: PackedVector3Array,
		inward := false
	) -> void:
		var rows := pts.size()
		var m := pts[0].size()
		var start := verts.size()
		for i in rows:
			for j in m:
				var p := pts[i][j]
				var du := pts[mini(i + 1, rows - 1)][j] - pts[maxi(i - 1, 0)][j]
				var jn := (j + 1) % m if closed else mini(j + 1, m - 1)
				var jp := (j + m - 1) % m if closed else maxi(j - 1, 0)
				var n := du.cross(pts[i][jn] - pts[i][jp])
				var out := p - refs[i]
				if n.length_squared() < 1e-14:
					# Anella feta un punt (una punta o el pol): la normal va enfora.
					var axis := refs[0] - refs[1] if i == 0 else refs[i] - refs[i - 1]
					n = out if out.length_squared() > 1e-10 else axis
				elif n.dot(out) < 0.0:
					n = -n
				verts.append(p)
				normals.append((-n if inward else n).normalized())
				colors.append(cols[i][j])
		for i in rows - 1:
			for j in m if closed else m - 1:
				var j2 := (j + 1) % m
				var a := start + i * m + j
				var b := start + (i + 1) * m + j
				var c := start + (i + 1) * m + j2
				var d := start + i * m + j2
				_tri(a, b, c)
				_tri(a, c, d)

	## Tub de radi `r` al llarg de `path` (les barres de la reixa).
	func tube(path: PackedVector3Array, r: float, color: Color, sides := 6) -> void:
		var along := (path[path.size() - 1] - path[0]).normalized()
		var ref := Vector3.UP if absf(along.y) < 0.7 else Vector3.RIGHT
		var rows: Array[PackedVector3Array] = []
		var cols: Array[PackedColorArray] = []
		for i in path.size():
			var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
			var u := t.cross(ref).normalized()
			var w := t.cross(u)
			var ring := PackedVector3Array()
			var rc := PackedColorArray()
			for k in sides:
				var a := TAU * k / sides
				ring.append(path[i] + (u * cos(a) + w * sin(a)) * r)
				rc.append(color)
			rows.append(ring)
			cols.append(rc)
		grid(rows, cols, true, path)

	## Godot dibuixa la cara de davant dels triangles en sentit horari.
	func _tri(a: int, b: int, c: int) -> void:
		var face := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if face.dot(normals[a] + normals[b] + normals[c]) > 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	func add_to(mesh: ArrayMesh, mat: Material) -> void:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_COLOR] = colors
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


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
		var k := _round_ends(y - PAD_BOT, PAD_TOP - y, PAD_ROUND_BOT, PAD_ROUND_TOP)
		var center := Vector3(side * PAD_X, y, shin + 0.006)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in around:
			var th := TAU * j / around
			var s := sin(th)
			var c := cos(th)
			var front := maxf(0.0, c)
			var dz := depth * _spow(c, 0.66) - 0.006 * groove * sqrt(front)
			ring.append(center + Vector3(half_w * _spow(s, 0.66), 0.0, dz) * k)
			var col := pad.darkened(0.3 * groove * front)
			if c < -0.5:
				col = LINING
			elif s * side > 0.8 and y > 0.13 and y < 0.5:
				col = accent
			rc.append(col)
		rows.append(ring)
		cols.append(rc)
		refs.append(center)
	var part := Part.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, _material(0.5))
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
		var bot := -0.008 + 0.022 * (1.0 - _round_ends(d0, d1, 0.02, 0.04))
		var height := lerpf(0.145, 0.09, smoothstep(0.2, 0.8, t))
		var top := bot + height * _round_ends(d0, d1, 0.035, 0.08, 2.5)
		var half_w := lerpf(0.066, 0.06, t) * _round_ends(d0, d1, 0.035, 0.06, 2.5)
		var center := Vector3(side * KICK_X, (top + bot) * 0.5, z)
		var ring := PackedVector3Array()
		var rc := PackedColorArray()
		for j in around:
			var th := TAU * j / around
			var c := cos(th)
			var dy := (top - bot) * 0.5 * _spow(c, 0.6 if c >= 0.0 else 0.3)
			ring.append(center + Vector3(half_w * _spow(sin(th), 0.6), dy, 0.0))
			var col := pad
			if c < -0.85:
				col = pad.darkened(0.45)
			elif c > 0.3 and t > 0.4 and t < 0.5:
				col = accent
			rc.append(col)
		rows.append(ring)
		cols.append(rc)
		refs.append(center)
	var part := Part.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, _material(0.55))
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
	var part := Part.new()
	_shell(part, shell, trim)
	_stripe(part, stripe)
	part.add_to(mesh, _material(0.28))
	var cage := Part.new()
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
	var throat := Part.new()
	_throat_guard(throat, trim)
	var plastic := _material(0.35)
	plastic.cull_mode = BaseMaterial3D.CULL_DISABLED
	throat.add_to(mesh, plastic)
	_cache[key] = mesh
	return mesh


static func _shell(part: Part, shell: Color, trim: Color) -> void:
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
static func _stripe(part: Part, color: Color) -> void:
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
static func _throat_guard(part: Part, color: Color) -> void:
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
			var ce := _spow(cos(el), 0.4)
			ring.append(
				Vector3(
					half.x * ce * _spow(sin(th), 0.4),
					half.y * _spow(sin(el), 0.4),
					half.z * ce * _spow(cos(th), 0.4)
				)
			)
			rc.append(color.darkened(0.12) if i < 3 else color)
		rows.append(ring)
		cols.append(rc)
		refs.append(Vector3.ZERO)
	var part := Part.new()
	part.grid(rows, cols, true, refs)
	var mesh := ArrayMesh.new()
	part.add_to(mesh, _material(0.55))
	_cache[key] = mesh
	return mesh


# --- Ajudes -----------------------------------------------------------------------------


## Escala de la secció a prop de les puntes perquè acabin rodones: d0 i d1 són les
## distàncies a cada punta i r0 i r1 els radis de la volta. Amb e > 2, la punta és més
## xata (superel·lipse).
static func _round_ends(d0: float, d1: float, r0: float, r1: float, e := 2.0) -> float:
	var u := 0.0
	if d0 < r0:
		u = 1.0 - d0 / r0
	elif d1 < r1:
		u = 1.0 - d1 / r1
	return pow(maxf(0.0, 1.0 - pow(u, e)), 1.0 / e)


## Potència amb signe: superel·lipses (seccions de cantells rodons).
static func _spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


static func _material(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m
