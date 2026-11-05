## Efectes de l'estadi que depenen del partit però no de les regles: la xarxa que es
## mou després d'un gol, el públic que salta i el desplaçament de les tanques LED.
## A la web viuen a G (G.net, G.crowdJump) i avancen dins d'update(); aquí avancen amb
## els passos de la simulació (MatchRunner.stepped), i per tant s'aturen amb la pausa.
## ref: línies 406, 525, 952–953, 989, 997, 1007 i 1566
class_name StadiumFx
extends RefCounted

## Segons que dura el moviment de la xarxa.
const NET_SECONDS := 3.2
## Velocitat a què es calma el públic (per segon).
const JUMP_DECAY := 0.16

## Porteria de la xarxa que es mou (−1 o 1), o 0 si cap.
var net_side := 0
var net_y := 0.0
var net_t := 0.0
## De 0 (assegut) a 1 (gol).
var crowd_jump := 0.0


func reset() -> void:
	net_side = 0
	net_t = 0.0
	crowd_jump = 0.0


## Llegeix els esdeveniments d'un pas i avança `dt` segons.
func step(events: Array[Dictionary], dt: float) -> void:
	# Com a update(): primer avança el temps i després passa el que toca en aquest pas.
	if net_side != 0:
		net_t += dt
		if net_t > NET_SECONDS:
			net_side = 0
	crowd_jump = maxf(0.0, crowd_jump - dt * JUMP_DECAY)
	for e in events:
		match e["type"]:
			&"kick":
				if e["kind"] == &"shot":
					crowd_jump = maxf(crowd_jump, 0.25)
			&"goal":
				_net(e["side"], e["y"])
				crowd_jump = 1.0
			&"net":
				# La pilota torna a entrar a la porteria durant la repetició.
				_net(e["side"], e["y"])
			&"replay_start", &"replay_end":
				net_side = 0


func _net(side: int, y: float) -> void:
	net_side = side
	net_y = clampf(y, -Constants.GHW, Constants.GHW)
	net_t = 0.0


## Desplaçament de la textura de les tanques LED al temps `t` del partit: cada 5 s
## passen a l'anunci següent (1/8 de textura) en 0,6 s. ref: uScroll a glRender()
static func led_scroll(t: float) -> float:
	var ct := fmod(t, 5.0)
	var k := 1.0
	if ct < 0.6:
		var x := ct / 0.6
		k = x * x * (3.0 - 2.0 * x)
	return (floorf(t / 5.0) + k) * 0.125
