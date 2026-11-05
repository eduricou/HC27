## Generador d'atzar de la simulació: mulberry32 amb llavor.
## És el mateix generador que fa servir tools/oracle_web.mjs a la versió web, de manera
## que amb la mateixa llavor totes dues simulacions reben la mateixa seqüència.
## ref: R() (Math.random) i gauss()
class_name SimRng
extends RefCounted

const MASK := 0xFFFFFFFF
const INV_2_32 := 1.0 / 4294967296.0

## Nombre de crides a rand() (per depurar desincronitzacions amb la web).
var calls := 0
var _a: int


func _init(seed_value: int = 0) -> void:
	_a = seed_value & MASK


## Nombre a [0, 1), com Math.random(). ref: R()
func rand() -> float:
	calls += 1
	var a := (_a + 0x6D2B79F5) & MASK
	_a = a
	# t = Math.imul(a ^ a >>> 15, 1 | a)
	var x := a ^ (a >> 15)
	var y := 1 | a
	var t := (
		(
			(x & 0xFFFF) * (y & 0xFFFF)
			+ ((((x >> 16) * (y & 0xFFFF) + (x & 0xFFFF) * (y >> 16)) & 0xFFFF) << 16)
		)
		& MASK
	)
	# t = (t + Math.imul(t ^ t >>> 7, 61 | t)) ^ t
	x = t ^ (t >> 7)
	y = 61 | t
	var m := (
		(
			(x & 0xFFFF) * (y & 0xFFFF)
			+ ((((x >> 16) * (y & 0xFFFF) + (x & 0xFFFF) * (y >> 16)) & 0xFFFF) << 16)
		)
		& MASK
	)
	t = ((t + m) & MASK) ^ t
	return float(t ^ (t >> 14)) * INV_2_32


## Soroll aproximadament gaussià. ref: gauss()
func gauss() -> float:
	return (rand() + rand() + rand() - 1.5) * 1.15
