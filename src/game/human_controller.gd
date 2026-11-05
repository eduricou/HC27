## Omple SimInput a partir del teclat i el comandament (accions d'InputActions).
## S'ha de cridar des de _physics_process, un cop per pas de simulació: així els flancs
## («just pressed») valen per a un sol pas, com a la web. ref: sampleInput()
class_name HumanController
extends RefCounted


static func poll(inp: SimInput) -> void:
	compose(
		inp,
		Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"),
		Input.is_action_pressed(&"sprint"),
		Input.is_action_pressed(&"shoot"),
		Input.is_action_just_pressed(&"pass"),
		Input.is_action_just_pressed(&"shoot"),
		Input.is_action_just_released(&"shoot")
	)


## Part pura de poll(), per a les proves. mv va en coordenades de pantalla, que amb la
## càmera TV coincideixen amb les de la simulació (dreta = +x, avall = +y).
static func compose(
	inp: SimInput,
	mv: Vector2,
	sprint: bool,
	shoot_held: bool,
	pass_e: bool,
	shoot_e: bool,
	shoot_up_e: bool
) -> void:
	if mv.length() > 1.0:
		mv = mv.normalized()
	inp.mv = mv
	inp.sprint = sprint
	inp.shoot_held = shoot_held
	inp.pass_e = pass_e
	inp.shoot_e = shoot_e
	inp.shoot_up_e = shoot_up_e
