## Buffer circular dels últims fotogrames per a les repeticions de gol.
## Cada fotograma: per jugador [x, y, face, anim o −1 si està quiet] i després la pilota
## [x, y, z]. ref: record(), G.rec
class_name ReplayBuffer
extends RefCounted

const CAPACITY := 330
const REPLAY_FRAMES := 300

var count := 0
var _frames: Array[PackedFloat32Array] = []
var _head := 0


func clear() -> void:
	count = 0
	_head = 0
	_frames.clear()


## ref: record()
func record(players: Array[Player], ball: Ball) -> void:
	count += 1
	var n := players.size() * 4
	var f: PackedFloat32Array
	if _frames.size() < CAPACITY:
		f = PackedFloat32Array()
		f.resize(n + 3)
		_frames.append(f)
	else:
		f = _frames[_head]
		_head = (_head + 1) % CAPACITY
	for k in players.size():
		var p := players[k]
		f[k * 4] = p.x
		f[k * 4 + 1] = p.y
		f[k * 4 + 2] = p.face
		f[k * 4 + 3] = p.anim if p.moving else -1.0
	f[n] = ball.x
	f[n + 1] = ball.y
	f[n + 2] = ball.z


## Nombre de fotogrames que tindria una repetició de `n` fotogrames.
func length_of(n: int = REPLAY_FRAMES) -> int:
	return mini(n, mini(count, CAPACITY))


## Còpia dels últims `n` fotogrames, del més antic al més recent. ref: G.rec.slice(-300)
func snapshot(n: int = REPLAY_FRAMES) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	var size := _frames.size()
	var take := mini(n, size)
	# El més antic és a _head quan el buffer és ple, o a 0 si encara no ho és.
	var oldest := _head if size == CAPACITY else 0
	for k in range(size - take, size):
		out.append(_frames[(oldest + k) % size].duplicate())
	return out
