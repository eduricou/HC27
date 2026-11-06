# Converteix les animacions de la Universal Animation Library 1 i 2 (Quaternius, CC0) a
# l'esquelet del jugador (Universal Base Characters) i les desa en una AnimationLibrary:
# assets/models/animations/players.res. La fa servir src/game/players/player_rig.gd.
#
# Ús: "$GODOT" --headless --path . -s res://tools/build_player_anims.gd
#
# Els dos esquelets tenen els mateixos ossos, però les rotacions de repòs no són iguals
# (fins a 17° al coll), de manera que no n'hi ha prou de copiar les pistes. Per a cada
# fotograma es calcula la rotació global de cada os respecte al seu repòs al maniquí i
# s'aplica al repòs del jugador; la pelvis es mou el mateix que al maniquí, escalada per
# l'alçada. De les animacions de córrer se'n mesura la velocitat a què el peu de suport
# va enrere (metres per segon) i la llargada de la passa (metres per cicle), i el cicle es
# fa començar al mig del recolzament del peu esquerre. PlayerRig les fa anar
# sincronitzades i al ritme de la velocitat del jugador, perquè els peus no rellisquin.
# Detalls: docs/decisions/0007.
extends SceneTree

const BODY := "res://assets/models/players/Superhero_Male_FullBody.gltf"
const SOURCES := {
	"ual1": "res://assets/models/animations/UAL1_Standard.glb",
	"ual2": "res://assets/models/animations/UAL2_Standard.glb",
}
const OUT := "res://assets/models/animations/players.res"
const FPS := 30.0
const SKELETON_PATH := "Armature/Skeleton3D"

## Nom al joc → [paquet, nom a la biblioteca, bucle, velocitat de terra a mesurar].
const PICK := {
	"idle": ["ual1", "Idle", true, false],
	"walk": ["ual1", "Walk", true, true],
	"jog": ["ual1", "Jog_Fwd", true, true],
	"sprint": ["ual1", "Sprint", true, true],
	"celebrate": ["ual2", "Yes", false, false],
	"protest": ["ual2", "Idle_No", false, false],
	"hit": ["ual1", "Hit_Chest", false, false],
	"dive": ["ual2", "Slide_Start", false, false],
	"lunge": ["ual2", "Shield_Dash", false, false],
}


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var body: Node = (load(BODY) as PackedScene).instantiate()
	var bsk := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var lib := AnimationLibrary.new()
	var sources := {}
	for key: String in SOURCES:
		sources[key] = (load(SOURCES[key]) as PackedScene).instantiate()
	for name: String in PICK:
		var pick: Array = PICK[name]
		var src: Node = sources[pick[0]]
		var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var msk := src.find_child("Skeleton3D", true, false) as Skeleton3D
		if not ap.has_animation(pick[1]):
			printerr("No trobo l'animació %s a %s" % [pick[1], pick[0]])
			return 1
		var anim := retarget(ap.get_animation(pick[1]), msk, bsk)
		if pick[3]:
			# Torna a convertir-la començant amb el peu esquerre a terra.
			var phase := contact_time(anim, bsk, "ball_l")
			anim = retarget(ap.get_animation(pick[1]), msk, bsk, phase)
			var v := ground_speed(anim, bsk)
			anim.set_meta(&"ground_speed", v)
			anim.set_meta(&"stride", v * anim.length)
			print(
				(
					"  %-10s %.2f s · %.2f m/s · passa %.2f m · comença a %.2f s"
					% [name, anim.length, v, v * anim.length, phase]
				)
			)
		else:
			print("  %-10s %.2f s" % [name, anim.length])
		anim.loop_mode = Animation.LOOP_LINEAR if pick[2] else Animation.LOOP_NONE
		lib.add_animation(name, anim)
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	for key: String in sources:
		(sources[key] as Node).free()
	body.free()
	if err != OK:
		printerr("No he pogut desar %s (%d)" % [OUT, err])
		return 1
	print("Desat: %s (%d animacions)" % [OUT, PICK.size()])
	return 0


## Rotació global de repòs de cada os.
static func global_rest_rotations(sk: Skeleton3D) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for b in sk.get_bone_count():
		out.append(sk.get_bone_global_rest(b).basis.get_rotation_quaternion())
	return out


## Passa l'animació `src` (esquelet `msk`) a l'esquelet `bsk`. Amb `offset`, el cicle
## comença `offset` segons més tard (només per a animacions en bucle).
static func retarget(
	src: Animation, msk: Skeleton3D, bsk: Skeleton3D, offset: float = 0.0
) -> Animation:
	var n := bsk.get_bone_count()
	var mrest := global_rest_rotations(msk)
	var brest := global_rest_rotations(bsk)
	# Pistes de rotació i de posició de l'animació original, per os del maniquí.
	var rot_track := {}
	var pos_track := {}
	for t in src.get_track_count():
		var bone := String(src.track_get_path(t).get_concatenated_subnames())
		match src.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rot_track[bone] = t
			Animation.TYPE_POSITION_3D:
				pos_track[bone] = t
	var pelvis := bsk.find_bone("pelvis")
	var mpelvis := msk.find_bone("pelvis")
	var height_k := (
		bsk.get_bone_global_rest(pelvis).origin.y / msk.get_bone_global_rest(mpelvis).origin.y
	)
	var out := Animation.new()
	out.length = src.length
	var tracks := PackedInt32Array()
	tracks.resize(n)
	for b in n:
		tracks[b] = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tracks[b], "%s:%s" % [SKELETON_PATH, bsk.get_bone_name(b)])
	var ptrack := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(ptrack, "%s:pelvis" % SKELETON_PATH)
	var frames := maxi(1, ceili(src.length * FPS))
	var mglobal: Array[Quaternion] = []
	var bglobal: Array[Quaternion] = []
	mglobal.resize(n)
	bglobal.resize(n)
	for k in frames + 1:
		var time := minf(k / FPS, src.length)
		var st := fmod(time + offset, src.length) if offset > 0.0 else time
		if offset > 0.0 and k == frames:
			st = offset
		for b in n:
			var name := bsk.get_bone_name(b)
			var mb := msk.find_bone(name)
			var local: Quaternion
			if rot_track.has(name):
				local = src.rotation_track_interpolate(rot_track[name], st)
			else:
				local = msk.get_bone_rest(mb).basis.get_rotation_quaternion()
			var mp := msk.get_bone_parent(mb)
			# Els ossos van de pares a fills: el pare ja està calculat.
			mglobal[b] = (mglobal[bsk.get_bone_parent(b)] * local) if mp >= 0 else local
			var world := mglobal[b] * mrest[mb].inverse()
			bglobal[b] = world * brest[b]
			var bp := bsk.get_bone_parent(b)
			var blocal := (bglobal[bp].inverse() * bglobal[b]) if bp >= 0 else bglobal[b]
			out.rotation_track_insert_key(tracks[b], time, blocal.normalized())
		if pos_track.has("pelvis"):
			var mpos: Vector3 = src.position_track_interpolate(pos_track["pelvis"], st)
			var delta := (mpos - msk.get_bone_rest(mpelvis).origin) * height_k
			out.position_track_insert_key(ptrack, time, bsk.get_bone_rest(pelvis).origin + delta)
	return out


## Velocitat (m/s) a què va enrere el peu de suport: és la velocitat d'avançar sense que
## rellisqui. El model mira cap a +Z.
static func ground_speed(anim: Animation, sk: Skeleton3D) -> float:
	var frames := ceili(anim.length * FPS)
	var speeds := PackedFloat64Array()
	for foot: String in ["ball_l", "ball_r"]:
		var fb := sk.find_bone(foot)
		var ys := PackedFloat64Array()
		var zs := PackedFloat64Array()
		for k in frames + 1:
			var p := bone_position(anim, sk, fb, minf(k / FPS, anim.length))
			ys.append(p.y)
			zs.append(p.z)
		var lo := ys[0]
		for y in ys:
			lo = minf(lo, y)
		for k in frames:
			if ys[k] < lo + 0.03 and ys[k + 1] < lo + 0.03:
				speeds.append(-(zs[k + 1] - zs[k]) * FPS)
	if speeds.is_empty():
		return 0.0
	speeds.sort()
	return speeds[speeds.size() / 2]


## Instant del mig del recolzament del peu `foot` (el tram més llarg en què és a menys de
## 2,5 cm del punt més baix): és el mateix moment de la passa a totes les animacions.
static func contact_time(anim: Animation, sk: Skeleton3D, foot: String) -> float:
	var fb := sk.find_bone(foot)
	var n := ceili(anim.length * FPS)
	var ys := PackedFloat64Array()
	var lo := 1e9
	for k in n:
		var y := bone_position(anim, sk, fb, k / FPS).y
		ys.append(y)
		lo = minf(lo, y)
	# Tram de recolzament més llarg, tenint en compte que el cicle torna a començar.
	var best_start := 0
	var best_len := 0
	for start in n:
		if ys[start] >= lo + 0.025 or ys[posmod(start - 1, n)] < lo + 0.025:
			continue
		var len := 0
		while len < n and ys[(start + len) % n] < lo + 0.025:
			len += 1
		if len > best_len:
			best_len = len
			best_start = start
	return fmod((best_start + best_len * 0.5) / FPS, anim.length)


## Posició (espai de l'esquelet) de l'os `bone` a l'instant `time` de l'animació.
static func bone_position(anim: Animation, sk: Skeleton3D, bone: int, time: float) -> Vector3:
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.push_front(b)
		b = sk.get_bone_parent(b)
	var xf := Transform3D.IDENTITY
	for c in chain:
		var path := NodePath("%s:%s" % [SKELETON_PATH, sk.get_bone_name(c)])
		var rest := sk.get_bone_rest(c)
		var rot := rest.basis.get_rotation_quaternion()
		var pos := rest.origin
		var rt := anim.find_track(path, Animation.TYPE_ROTATION_3D)
		if rt >= 0:
			rot = anim.rotation_track_interpolate(rt, time)
		var pt := anim.find_track(path, Animation.TYPE_POSITION_3D)
		if pt >= 0:
			pos = anim.position_track_interpolate(pt, time)
		xf = xf * Transform3D(Basis(rot), pos)
	return xf.origin
