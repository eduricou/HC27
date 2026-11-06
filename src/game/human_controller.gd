## Omple SimInput a partir del teclat, el comandament i el ratolí (accions d'InputActions).
## S'ha de cridar des de _physics_process, un cop per pas de simulació: així els flancs
## («just pressed») valen per a un sol pas, com a la web. ref: sampleInput()
## La direcció és relativa a la càmera: amb la TV, amunt és −y de la simulació; amb la
## càmera del córner curt (darrere de la porteria), amunt és cap on mira la càmera.
class_name HumanController
extends RefCounted

## Gir (radiants) que s'aplica ara a la direcció. Només s'actualitza amb la palanca o les
## tecles de moure deixades anar: en un canvi de càmera, el jugador no canvia de rumb fins
## que l'usuari torna a prémer.
static var angle := 0.0


static func poll(inp: SimInput, camera_angle: float = 0.0) -> void:
	compose(
		inp,
		Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"),
		Input.is_action_pressed(&"sprint"),
		Input.is_action_pressed(&"shoot"),
		Input.is_action_just_pressed(&"pass"),
		Input.is_action_just_pressed(&"shoot"),
		Input.is_action_just_released(&"shoot"),
		camera_angle
	)
	inp.tap_e = Input.is_action_just_pressed(InputActions.SKIP)


## Només els botons que salten la presentació i la repetició (CPU contra CPU: no hi ha
## cap jugador humà, però l'usuari també pot saltar-les, com a la web).
static func poll_skip(inp: SimInput) -> void:
	compose(inp, Vector2.ZERO, false, false, false, false, false)
	inp.pass_e = Input.is_action_just_pressed(&"pass")
	inp.shoot_e = Input.is_action_just_pressed(&"shoot")
	inp.tap_e = Input.is_action_just_pressed(InputActions.SKIP)


## Part pura de poll(), per a les proves. mv va en coordenades de pantalla (dreta = +x,
## avall = +y); amb camera_angle = 0 (càmera TV) coincideixen amb les de la simulació.
static func compose(
	inp: SimInput,
	mv: Vector2,
	sprint: bool,
	shoot_held: bool,
	pass_e: bool,
	shoot_e: bool,
	shoot_up_e: bool,
	camera_angle: float = 0.0
) -> void:
	if mv.length() > 1.0:
		mv = mv.normalized()
	if mv.length() < InputActions.MOVE_DEADZONE:
		angle = camera_angle
	inp.mv = mv.rotated(angle) if angle != 0.0 else mv
	inp.sprint = sprint
	inp.shoot_held = shoot_held
	inp.pass_e = pass_e
	inp.shoot_e = shoot_e
	inp.shoot_up_e = shoot_up_e
	inp.tap_e = false
