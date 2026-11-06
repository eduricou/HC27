## Prepara els sons del joc (assets/audio/) a partir dels paquets baixats (tots CC0):
## - Kenney «Impact Sounds» i «Interface Sounds» (kenney.nl), descomprimits a
##   <carpeta>/kenney/impact/ i <carpeta>/kenney/interface/;
## - BigSoundBank (bigsoundbank.com), els OGG pel número: <carpeta>/bsb/<número>.ogg
##   (https://bigsoundbank.com/UPLOAD/ogg/<número>.ogg).
## Copia els que es fan servir amb noms clars, retalla el xiulet i genera el «whoosh» de la
## cortineta. Ús: "$GODOT" --headless --path . -s res://tools/prepare_audio.gd -- <carpeta>
extends SceneTree

const OUT := "res://assets/audio"
## Kenney Impact Sounds: so del joc ← fitxer (sense _00N.ogg) i variants.
const IMPACT := {
	"sfx/stick_pass": ["impactWood_light", [0, 1, 2]],
	"sfx/stick_hit": ["impactWood_medium", [0, 1, 2]],
	"sfx/tackle": ["impactWood_heavy", [0, 1]],
	"sfx/control": ["impactGeneric_light", [0, 1, 2]],
	"sfx/ball_turf": ["impactSoft_medium", [0, 1]],
	"sfx/backboard": ["impactPlank_medium", [0, 2]],
	"sfx/post": ["impactMetal_medium", [0, 1]],
	"sfx/pads": ["impactPunch_medium", [0, 1]],
	"sfx/net": ["impactSoft_heavy", [0, 1]],
}
## Kenney Interface Sounds.
const INTERFACE := {
	"ui/focus": ["tick", [1]],
	"ui/press": ["click", [2]],
	"ui/back": ["back", [1]],
	"ui/switch": ["tick", [2]],
}
## BigSoundBank: so del joc ← número.
const BSB := {
	"crowd/murmur_a": "0825",  # Spanish crowd: gent d'un poble petit (80 s)
	"crowd/murmur_b": "3515",  # Crowd of 50-60 People #1 (108 s)
	"crowd/applause_0": "0812",  # Applause about 25-50 people #1 (exterior)
	"crowd/applause_1": "0813",
	"crowd/applause_2": "0814",
	"crowd/cheer_0": "0236",  # Shouts and Applauses of Teens #1
	"crowd/cheer_1": "0237",
}
## Xiulet: el bufet llarg de «Whistle, plastic #3» (BigSoundBank 1141), de 5,46 s a 8,62 s.
const WHISTLE := ["1141", 5.46, 8.62]
const RATE := 44100


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Ús: -s res://tools/prepare_audio.gd -- <carpeta amb kenney/ i bsb/>")
		quit(2)
		return
	var src := args[0]
	for sub in ["sfx", "ui", "crowd"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/" + sub))
	var n := 0
	for key: String in IMPACT:
		n += _copy_variants(src + "/kenney/impact/Audio", key, IMPACT[key])
	for key: String in INTERFACE:
		n += _copy_variants(src + "/kenney/interface/Audio", key, INTERFACE[key])
	for key: String in BSB:
		n += _copy(src + "/bsb/" + BSB[key] + ".ogg", "%s/%s.ogg" % [OUT, key])
	var whistle := _trim(src + "/bsb/" + WHISTLE[0] + ".ogg", WHISTLE[1], WHISTLE[2])
	_save_wav(whistle, OUT + "/sfx/whistle.wav")
	_save_wav(whoosh(), OUT + "/ui/whoosh.wav")
	print(
		"Sons preparats: %d copiats, xiulet (%.2f s) i whoosh." % [n, whistle.size() / float(RATE)]
	)
	quit()


func _copy_variants(dir: String, key: String, spec: Array) -> int:
	var n := 0
	for i in spec[1].size():
		var from := "%s/%s_%03d.ogg" % [dir, spec[0], spec[1][i]]
		var to := "%s/%s_%d.ogg" % [OUT, key, i] if spec[1].size() > 1 else "%s/%s.ogg" % [OUT, key]
		n += _copy(from, to)
	return n


func _copy(from: String, to: String) -> int:
	var err := DirAccess.copy_absolute(from, ProjectSettings.globalize_path(to))
	if err != OK:
		printerr("No puc copiar %s (%s)" % [from, error_string(err)])
		return 0
	return 1


## Mostres mono (−1..1) del fitxer, de t0 a t1 segons, amb 5 ms d'entrada i 40 ms de sortida.
static func _trim(path: String, t0: float, t1: float) -> PackedFloat32Array:
	var st := AudioStreamOggVorbis.load_from_file(path)
	var pb := st.instantiate_playback()
	pb.start(t0)
	var n := int((t1 - t0) * RATE)
	var pcm := PackedVector2Array()
	while pcm.size() < n:
		var chunk := pb.mix_audio(1.0, mini(4096, n - pcm.size()))
		if chunk.is_empty():
			break
		pcm.append_array(chunk)
	var out := PackedFloat32Array()
	out.resize(pcm.size())
	var fin := int(0.005 * RATE)
	var fout := int(0.04 * RATE)
	for i in pcm.size():
		var g := minf(1.0, minf(float(i) / fin, float(pcm.size() - 1 - i) / fout))
		out[i] = (pcm[i].x + pcm[i].y) * 0.5 * g
	return out


## Soroll filtrat que puja i baixa en 0,8 s (la cortineta tapa la pantalla al mig).
static func whoosh() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	var n := int(0.8 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var u := float(i) / n
		# Envolupant: puja fins al 44 %, s'aguanta i s'apaga.
		var env := smoothstep(0.0, 0.44, u) * (1.0 - smoothstep(0.56, 1.0, u))
		# Tall del filtre: de 300 Hz a 3 kHz al mig i torna a baixar.
		var fc := 300.0 + 2700.0 * sin(PI * u)
		var a := 1.0 - exp(-TAU * fc / RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		lp2 += (lp - lp2) * a
		out[i] = lp2 * env * 1.6
	return out


static func _save_wav(samples: PackedFloat32Array, path: String) -> void:
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	# Pic a −1 dB, com els de Kenney.
	var gain := db_to_linear(-1.0) / maxf(peak, 1e-6)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.save_to_wav(ProjectSettings.globalize_path(path))
