## Analitza el WAV que grava el Movie Maker de Godot (tools/audio_check.sh) per comprovar que
## el so no satura: pic, mostres retallades, segon més fort i nivell mitjà.
## Ús: "$GODOT" --headless -s res://tools/audio_check.gd -- <fitxer.wav> [pic_màxim_dBFS]
## Surt amb codi 1 si el pic passa del màxim (−0,1 dBFS per defecte) o hi ha mostres
## retallades.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Ús: -s res://tools/audio_check.gd -- <fitxer.wav> [pic_màxim_dBFS]")
		quit(2)
		return
	var limit := float(args[1]) if args.size() > 1 else -0.1
	var r := analyse(args[0])
	if r.is_empty():
		quit(2)
		return
	print(
		(
			(
				"SO: %.1f s · pic %.2f dBFS · %d mostres retallades · "
				+ "segon més fort %.1f dB RMS (%.0f s) · mitjana %.1f dB RMS"
			)
			% [r["secs"], r["peak_db"], r["clipped"], r["loudest_db"], r["loudest_at"], r["rms_db"]]
		)
	)
	var ok: bool = r["peak_db"] <= limit and r["clipped"] == 0
	print("SO OK: no satura" if ok else "SO FALLA: satura")
	quit(0 if ok else 1)


## Llegeix un WAV PCM de 16 o 32 bits (enter) i en treu les mesures.
static func analyse(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "RIFF":
		printerr("No és un WAV: %s" % path)
		return {}
	f.get_32()
	f.get_buffer(4)  # WAVE
	var channels := 2
	var rate := 48000
	var bits := 16
	var data := PackedByteArray()
	while f.get_position() < f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		if id == "fmt ":
			var fmt := f.get_buffer(size)
			channels = fmt.decode_u16(2)
			rate = fmt.decode_u32(4)
			bits = fmt.decode_u16(14)
		elif id == "data":
			data = f.get_buffer(size)
		else:
			f.seek(f.get_position() + size)
		if size % 2 == 1:
			f.seek(f.get_position() + 1)
	var bytes := bits / 8
	var n := data.size() / bytes
	var full := float(1 << (bits - 1))
	var peak := 0.0
	var clipped := 0
	var sum := 0.0
	var sec_sum := 0.0
	var loudest := 0.0
	var loudest_at := 0.0
	var per_sec := rate * channels
	for i in n:
		var v := float(data.decode_s16(i * 2) if bytes == 2 else data.decode_s32(i * 4)) / full
		var a := absf(v)
		peak = maxf(peak, a)
		if a >= 0.999:
			clipped += 1
		sum += v * v
		sec_sum += v * v
		if (i + 1) % per_sec == 0:
			if sec_sum > loudest:
				loudest = sec_sum
				loudest_at = float(i + 1) / per_sec - 1.0
			sec_sum = 0.0
	return {
		"secs": float(n) / per_sec,
		"peak_db": linear_to_db(maxf(peak, 1e-9)),
		"clipped": clipped,
		"loudest_db": linear_to_db(sqrt(loudest / per_sec)),
		"loudest_at": loudest_at,
		"rms_db": linear_to_db(sqrt(sum / maxf(1.0, n))),
	}
