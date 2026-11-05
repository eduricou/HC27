## On va cada cosa de l'estadi, en coordenades de la simulació (metres). Les mesures i
## l'atzar de la ciutat i dels pins són els de glInit() a la web (línies 1502–1539), amb
## el mateix generador (Park–Miller amb llavor 11), perquè el fons sigui el mateix.
class_name StadiumLayout
extends RefCounted

const HL := Constants.HL
const HW := Constants.HW

## Torres de llum: [x, y] i altura dels focus. ref: TOWERS, TOWER_H
const TOWERS: Array[Vector2] = [
	Vector2(-HL - 6.0, -HW - 12.0),
	Vector2(HL + 6.0, -HW - 12.0),
	Vector2(-HL - 6.0, HW + 14.0),
	Vector2(HL + 6.0, HW + 14.0),
]
const TOWER_H := 25.0
## Direcció cap al sol de tarda (x, y, z de la simulació). ref: SUN
const SUN := Vector3(-0.8, -0.25, 0.5)

## Grada: de x0 a x1, davant (yf) i darrere (yb); 8 files de seients.
const STAND_X0 := -32.0
const STAND_X1 := 32.0
const STAND_YF := -HW - 9.0
const STAND_YB := -HW - 21.0
const STAND_ROWS := 8
const STAND_Z0 := 1.3
const STAND_Z1 := 9.3
const STAND_BACK_H := 12.8
const ROOF_FRONT := Vector2(STAND_YF + 0.8, 12.2)
const ROOF_BACK := Vector2(STAND_YB - 0.6, 13.6)
const STAND_COLUMNS: Array[float] = [-31.0, -15.5, 0.0, 15.5, 31.0]

## Tanques LED: la llarga davant de la grada i les dels fons, a banda i banda de la porteria.
const LED_Y := -HW - 4.3
const LED_X := 45.0
const LED_END_X := HL + 4.6
const LED_END_SPANS: Array[Vector2] = [Vector2(-24.0, -7.0), Vector2(7.0, 24.0)]

## Xarxa alta darrere de cada porteria.
const BACKNET_X := HL + 6.5
const BACKNET_Y := 16.0
const BACKNET_H := 6.0

## Límit del voral (on acaba el formigó). ref: apr a FS_GROUND
const APRON_X := HL + 8.0
const APRON_Y0 := -HW - 9.0
const APRON_Y1 := HW + 8.5

## Casa del club: [x0, x1, y0, y1] i altura.
const CLUBHOUSE := Rect2(-HL - 26.0, -HW - 12.0, 15.0, 15.0)
const CLUBHOUSE_H := 6.5
## Hospital del fons.
const HOSPITAL := Rect2(30.0, -175.0, 75.0, 25.0)
const HOSPITAL_H := 26.0

## Banquetes, al costat de la càmera TV: centre x de cada una (Iluro a l'esquerra, Polo a
## la dreta), davant (y0, cap al camp) i darrere (y1).
const BENCH_X: Array[float] = [-8.0, 8.0]
const BENCH_W := 7.0
const BENCH_Y0 := HW + 4.9
const BENCH_Y1 := HW + 6.7
const BENCH_H := 2.2


## Generador de la web: seed = seed·16807 mod (2³¹ − 1). ref: rnd() de glInit()
class ParkMiller:
	var seed := 11

	func next() -> float:
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647.0


## Blocs de pisos: Rect2(x0, y0, w, d) i altura (z de la Rect2 no existeix: es retorna a
## part). Retorna [[Rect2, h], ...] i deixa el generador a punt per als pins.
static func city_blocks(rnd: ParkMiller) -> Array:
	var out := []
	for i in 26:
		var x0 := -260.0 + rnd.next() * 520.0
		var y0 := -170.0 - rnd.next() * 110.0
		var w := 16.0 + rnd.next() * 22.0
		var d := 10.0 + rnd.next() * 12.0
		var h := 9.0 + rnd.next() * 20.0
		if x0 > 15.0 and x0 < 120.0 and y0 > -190.0:
			continue
		out.append([Rect2(x0, y0 - d, w, d), h])
	return out


## Pins pinyers: [Vector3(x, y, escala), ...], ordenats de lluny a prop com a la web.
static func pines(rnd: ParkMiller) -> Array[Vector3]:
	var pts: Array[Vector2] = []
	for i in 70:
		var x: float
		var y: float
		var zone := rnd.next()
		if zone < 0.3:
			var s := -1.0 if rnd.next() < 0.5 else 1.0
			x = s * (HL + 12.0 + rnd.next() * 22.0)
			y = -40.0 + rnd.next() * 70.0
		elif zone < 0.75:
			x = -75.0 + rnd.next() * 150.0
			y = -52.0 - rnd.next() * 30.0
		else:
			var s := -1.0 if rnd.next() < 0.5 else 1.0
			x = s * (36.0 + rnd.next() * 14.0)
			y = -38.0 - rnd.next() * 16.0
		if x < -HL - 8.0 and x > -HL - 29.0 and y > -HW - 15.0 and y < -HW + 6.0:
			continue
		if absf(x) < 34.0 and y > -HW - 22.0:
			continue
		pts.append(Vector2(x, y))
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var out: Array[Vector3] = []
	for p in pts:
		out.append(Vector3(p.x, p.y, 0.8 + rnd.next() * 0.5))
	return out


## Altura del graó de la fila `r` (0 = la de davant).
static func row_z(r: int) -> float:
	return STAND_Z0 + r * (STAND_Z1 - STAND_Z0) / (STAND_ROWS - 1)


## y del davant del graó de la fila `r`.
static func row_y(r: int) -> float:
	return STAND_YF - r * (STAND_YF - STAND_YB) / STAND_ROWS


## Direcció cap al sol en coordenades de Godot (normalitzada).
static func sun_view() -> Vector3:
	var s := SUN.normalized()
	return Coords.to_view(s.x, s.y, s.z)
