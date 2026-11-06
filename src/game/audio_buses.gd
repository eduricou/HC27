## Busos d'àudio del joc: Master (general) i, per sota, Ambient (públic), Efectes (pal,
## pilota, xiulet) i Interfície. Es creen en temps d'execució perquè el menú d'opcions en
## pugui canviar el volum ara; la fase 6 hi posarà els sons.
class_name AudioBuses
extends RefCounted

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
