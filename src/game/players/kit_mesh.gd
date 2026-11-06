## Prepara el cos base per pintar-hi l'equipació (shaders/player_kit.gdshader). Per a cada
## vèrtex: la posició en repòs i la part del cos (cap, tronc, braç o cama) segons l'os que
## més hi pesa. Les dades van en una textura (un píxel per vèrtex) que el shader llegeix
## amb VERTEX_ID: així no cal tocar la malla i se'n conserven els LOD i la pell.
## On acaba cada peça de roba es decideix al shader amb la posició en repòs (que
## s'interpola suaument): alçada a les cames i al tronc, distància al centre als braços
## (el model és en postura de T). classify() fa el mateix aquí, per a les proves.
class_name KitMesh
extends RefCounted

enum Region { SKIN, SHIRT, SLEEVE, SHORTS, SOCKS, SHOES, FOREARM, HAND }
enum Part { HEAD, TORSO, ARM, LEG }

## Amplada de la textura de dades (vèrtexs per fila).
const TEX_W := 1024
## Fracció de l'extremitat (des de dalt) que tapa la roba.
const SLEEVE_T := 0.55
const SHORTS_T := 0.45
const SOCK_T := 0.14


## Part del cos d'un os pel nom (esquelet de Quaternius, noms com l'Unreal Mannequin).
static func part_of(bone: String) -> int:
	if bone in ["neck_01", "Head"]:
		return Part.HEAD
	for a: String in ["upperarm", "lowerarm", "hand", "index", "middle", "pinky", "ring", "thumb"]:
		if bone.begins_with(a):
			return Part.ARM
	for l: String in ["thigh", "calf", "foot", "ball"]:
		if bone.begins_with(l):
			return Part.LEG
	return Part.TORSO


## Línies on acaba cada peça de roba, en repòs (espai del model, metres). Són els
## paràmetres del shader.
static func landmarks(sk: Skeleton3D) -> Dictionary:
	var at := func(n: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(n)).origin
	var pelvis: Vector3 = at.call("pelvis")
	var neck: Vector3 = at.call("neck_01")
	var shoulder: Vector3 = at.call("upperarm_l")
	var elbow: Vector3 = at.call("lowerarm_l")
	var wrist: Vector3 = at.call("hand_l")
	var hip: Vector3 = at.call("thigh_l")
	var knee: Vector3 = at.call("calf_l")
	var ankle: Vector3 = at.call("foot_l")
	var waist := pelvis.y + 0.06
	var collar := neck.y - 0.06
	return {
		"waist_y": waist,
		"collar_y": collar,
		"collar_r": 0.085,
		"neck_z": neck.z,
		"chest_y": lerpf(waist, collar, 0.55),
		"band_y": lerpf(waist, collar, 0.72),
		"sleeve_x": lerpf(absf(shoulder.x), absf(elbow.x), SLEEVE_T),
		"wrist_x": absf(wrist.x) - 0.02,
		"shorts_y": lerpf(hip.y, knee.y, SHORTS_T),
		"socks_y": lerpf(knee.y, ankle.y, SOCK_T),
		"ankle_y": ankle.y + 0.02,
	}


## Regió del vèrtex a la posició p (repòs), de la part del cos `part`. És la mateixa regla
## que fa servir el shader.
static func classify(p: Vector3, part: int, lm: Dictionary) -> int:
	match part:
		Part.HEAD:
			return Region.SKIN
		Part.TORSO:
			return Region.SHORTS if p.y < lm["waist_y"] else Region.SHIRT
		Part.ARM:
			var ax := absf(p.x)
			if ax < lm["sleeve_x"]:
				return Region.SLEEVE
			return Region.HAND if ax > lm["wrist_x"] else Region.FOREARM
	if p.y > lm["shorts_y"]:
		return Region.SHORTS
	if p.y > lm["socks_y"]:
		return Region.SKIN
	return Region.SOCKS if p.y > lm["ankle_y"] else Region.SHOES


## Textura de dades (RGBA float, un píxel per vèrtex): xyz = repòs, a = part del cos.
static func data_texture(mesh: Mesh, skin: Skin, sk: Skeleton3D) -> ImageTexture:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / maxi(1, verts.size())
	var parts := PackedInt32Array()
	for i in skin.get_bind_count():
		var bn := String(skin.get_bind_name(i))
		parts.append(part_of(bn if bn != "" else sk.get_bone_name(skin.get_bind_bone(i))))
	var h := ceili(float(verts.size()) / TEX_W)
	var img := Image.create_empty(TEX_W, maxi(1, h), false, Image.FORMAT_RGBAF)
	for v in verts.size():
		var best := 0
		for k in range(1, per):
			if weights[v * per + k] > weights[v * per + best]:
				best = k
		var p := verts[v]
		img.set_pixel(v % TEX_W, v / TEX_W, Color(p.x, p.y, p.z, parts[bones[v * per + best]]))
	return ImageTexture.create_from_image(img)
