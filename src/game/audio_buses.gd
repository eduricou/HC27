## Busos d'àudio del joc: Master (general) i, per sota, Ambient (públic), Efectes (pal,
## pilota, xiulet) i Interfície. Es creen en temps d'execució. El Master porta un limitador
## a −0,5 dB: per molts sons que coincideixin (gol, xiulet, crits), no satura mai.
class_name AudioBuses
extends RefCounted

## Sostre del limitador del Master (dBFS).
const CEILING_DB := -0.5
const BUSES: Array[StringName] = [&"Master", &"Ambient", &"Efectes", &"Interficie"]
const NAMES := {
	&"Master": "General",
	&"Ambient": "Ambient",
	&"Efectes": "Efectes",
	&"Interficie": "Interfície",
}


static func ensure() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, &"Master")
	var master := AudioServer.get_bus_index(&"Master")
	for k in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, k) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = CEILING_DB
	AudioServer.add_bus_effect(master, lim)


## Volum lineal 0–1 (0 silencia el bus).
static func set_volume(bus: StringName, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


static func get_volume(bus: StringName) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i < 0 or AudioServer.is_bus_mute(i):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(i)), 0.0, 1.0)
