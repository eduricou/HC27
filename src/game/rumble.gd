## Vibració del comandament en xuts, entrades i gols, només per al jugador humà (i si està
## activada a les opcions). Fa vibrar tots els comandaments connectats.
class_name Rumble
extends Node

var runner: MatchRunner
var enabled := true


func on_events(events: Array[Dictionary]) -> void:
	if not enabled or runner == null or runner.sim == null:
		return
	var s := runner.sim.s
	for e in events:
		var v := pattern(s, e)
		if v.z > 0.0:
			pulse(v.x, v.y, v.z)


## Vibració d'un esdeveniment: (motor suau, motor fort, segons). Zero si no n'hi ha.
static func pattern(s: MatchState, e: Dictionary) -> Vector3:
	if s.mode != &"match" or s.human_idx < 0 or s.state == &"replay":
		return Vector3.ZERO
	var human := s.teams[s.human_idx]
	match e["type"]:
		&"kick":
			var p: Player = e.get("player")
			if p and p.team == human and e.get("kind") != &"pass":
				var k := clampf(float(e.get("speed", 10.0)) / 30.0, 0.0, 1.0)
				return Vector3(0.25 + 0.3 * k, 0.2 + 0.6 * k, 0.1 + 0.08 * k)
		&"tackle":
			var p: Player = e.get("player")
			if p == null:
				return Vector3.ZERO
			if p.team == human:
				# Entrada nostra: cop sec.
				return Vector3(0.35, 0.45, 0.1) if e.get("won") else Vector3(0.2, 0.15, 0.08)
			if e.get("won"):
				# Ens han pres la pilota: més fort.
				return Vector3(0.5, 0.8, 0.18)
		&"goal":
			if int(e.get("team", -1)) == human.idx:
				return Vector3(0.7, 1.0, 0.6)
			return Vector3(0.3, 0.25, 0.3)
	return Vector3.ZERO


static func pulse(weak: float, strong: float, secs: float) -> void:
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, weak, strong, secs)
