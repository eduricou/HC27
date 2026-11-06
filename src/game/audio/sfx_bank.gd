## Banc de sons (assets/audio/, preparats amb tools/prepare_audio.gd). Cada so pot tenir
## variants (_0, _1...) i pick() en tria una a l'atzar, perquè dos cops seguits no sonin
## idèntics. Fa servir el seu propi atzar: no toca el de la simulació.
## ref: SFX (línies 1052–1089), que a la web sintetitzava els sons amb WebAudio.
class_name SfxBank
extends RefCounted

const DIR := "res://assets/audio/"
## Nom → nombre de variants (0: un sol fitxer sense número).
const SOUNDS := {
	&"sfx/stick_pass": 3,
	&"sfx/stick_hit": 3,
	&"sfx/tackle": 2,
	&"sfx/control": 3,
	&"sfx/ball_turf": 2,
	&"sfx/backboard": 2,
	&"sfx/post": 2,
	&"sfx/pads": 2,
	&"sfx/net": 2,
	&"sfx/whistle": 0,
	&"crowd/murmur_a": 0,
	&"crowd/murmur_b": 0,
	&"crowd/applause": 3,
	&"crowd/cheer": 2,
	&"ui/focus": 0,
	&"ui/press": 0,
	&"ui/back": 0,
	&"ui/switch": 0,
	&"ui/whoosh": 0,
}

static var _cache := {}
static var _rng := RandomNumberGenerator.new()


## Totes les variants d'un so.
static func variants(sound: StringName) -> Array[AudioStream]:
	if _cache.has(sound):
		return _cache[sound]
	var out: Array[AudioStream] = []
	var n: int = SOUNDS.get(sound, 0)
	if n == 0:
		out.append(_load(String(sound)))
	else:
		for i in n:
			out.append(_load("%s_%d" % [sound, i]))
	_cache[sound] = out
	return out


static func pick(sound: StringName) -> AudioStream:
	var v := variants(sound)
	return v[_rng.randi() % v.size()]


static func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


static func _load(path: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + path + ext):
			return load(DIR + path + ext)
	push_error("Falta el so %s" % path)
	return null
