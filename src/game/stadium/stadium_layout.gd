## On va cada cosa del camp, en coordenades de la simulació (metres). És el camp real de
## l'Iluro al carrer Galícia de Mataró (foto aèria; docs/decisions/0006), no l'estadi de
## la web: no hi ha grada, només tanques als laterals.
##   −y (oest, al fons de la vista TV): passeig amb les banquetes, tanca, arbres i el carrer
##       Galícia amb cotxes i cases.
##   +y (est, on és la càmera TV): tanca, bardissa i talús amb la carretera a dalt.
##   +x (nord): les casetes del club. −x (sud): la xarxa alta i un camp de matolls.
## La ciutat del fons (hospital i blocs) és la de glInit() a la web, amb el mateix
## generador (Park–Miller amb llavor 11).
class_name StadiumLayout
extends RefCounted

const HL := Constants.HL
const HW := Constants.HW

## Direcció cap al sol de tarda (x, y, z de la simulació): sud-oest, darrere del passeig.
## ref: SUN
const SUN := Vector3(-0.8, -0.25, 0.5)

## Fins on arriba el formigó al voltant de la gespa: als extrems, el passeig de l'oest
## (fins a la tanca) i la franja de l'est (fins a la bardissa).
const APRON_X := HL + 8.0
const WALK_Y := -HW - 10.0
const EAST_Y := HW + 5.8
## Tanca del passeig (oest) i de l'est, i alçada.
const FENCE_H := 2.0
const EAST_FENCE_H := 1.3
## Bardissa de l'est: davant, fondària i alçada.
const HEDGE_Y := HW + 6.0
const HEDGE_D := 1.6
const HEDGE_H := 3.0
## Talús de l'est i carretera de dalt (a ROAD_Z m d'alçada).
const SLOPE_Y0 := HW + 7.6
const ROAD_Y0 := HW + 20.0
const ROAD_Y1 := HW + 28.0
const ROAD_Z := 7.0
const SLOPE_TOP := Vector2(HW + 60.0, 13.0)
## Carrer Galícia: franja amb arbres, vorera, calçada i vorera de l'altra banda.
const TREE_Y := -HW - 11.3
const SIDEWALK_Y := -HW - 12.5
const STREET_Y0 := -HW - 15.0
const STREET_Y1 := -HW - 24.0
const HOUSES_Y := -HW - 27.0
## Rotonda al nord-oest.
const ROUNDABOUT := Vector3(HL + 16.0, -HW - 19.5, 9.0)

## Xarxa alta de darrere la porteria del sud i la més baixa del nord.
const SOUTH_NET := {"x": -HL - 7.0, "y0": -HW - 8.0, "y1": HW + 4.0, "h": 7.0}
const NORTH_NET := {"x": HL + 7.0, "y0": -16.0, "y1": 16.0, "h": 5.0}

## Torres de llum: quatre al passeig (entre les banquetes i les pancartes) i dues a les
## cantonades de l'est. Al costat de la càmera TV no n'hi pot haver entre x = ±41:
## quedarien entre la càmera i el camp.
const POLES: Array[Vector2] = [
	Vector2(-38.25, WALK_Y + 0.7),
	Vector2(-12.0, WALK_Y + 0.7),
	Vector2(12.0, WALK_Y + 0.7),
	Vector2(38.25, WALK_Y + 0.7),
	Vector2(-44.0, HEDGE_Y - 0.5),
	Vector2(44.0, HEDGE_Y - 0.5),
]
## Posició de la càmera TV (CameraRig.tv_target(): 26 m enfora de la banda i 13 m amunt) i
## fins on pot anar en x.
const TV_CAM := Vector2(HW + 26.0, 13.0)
const TV_CAM_X := HL - 11.0
const POLE_H := 18.0

## Banquetes al passeig, a banda i banda de la línia del mig (Iluro a l'esquerra): centre
## x, amplada, davant (cap al camp) i darrere.
const BENCH_X: Array[float] = [-4.6, 4.6]
const BENCH_W := 6.0
const BENCH_Y0 := -HW - 5.0
const BENCH_Y1 := -HW - 6.8
const BENCH_H := 2.1

## Casetes del club al nord: [Rect2(x0, y0, mida x, mida y), alçada, paret, teulada].
## La paret "club" fa servir la façana amb el rètol ILURO HC.
const HUTS := [
	[Rect2(HL + 10.0, -HW - 8.0, 6.0, 7.0), 3.0, "c9c6bd", "6b7076"],
	[Rect2(HL + 11.0, -HW + 0.5, 4.0, 5.0), 3.2, "f2f1ec", "e4e4df"],
	[Rect2(HL + 9.5, -HW + 7.0, 6.0, 12.0), 3.4, "club", "8d97a3"],
	[Rect2(HL + 10.0, -HW + 20.5, 5.0, 5.0), 3.0, "d9d4c7", "9c3a2c"],
]
## Zona pavimentada de les casetes.
const HUTS_AREA := Rect2(HL + 8.0, -HW - 10.0, 18.0, 37.0)

## Hospital del fons.
const HOSPITAL := Rect2(30.0, -175.0, 75.0, 25.0)
const HOSPITAL_H := 26.0

## Persones dretes al passeig.
const SPECTATORS := 34


## Generador de la web: seed = seed·16807 mod (2³¹ − 1). ref: rnd() de glInit()
class ParkMiller:
	var seed := 11

	func next() -> float:
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647.0


## Blocs de pisos del fons: [[Rect2(x0, y0, w, d), h], ...]. ref: línies 1521–1523
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


## Altura del terreny a l'est (talús i carretera) a la coordenada y.
static func ground_z(y: float) -> float:
	if y <= SLOPE_Y0:
		return 0.0
	if y <= ROAD_Y0:
		return ROAD_Z * (y - SLOPE_Y0) / (ROAD_Y0 - SLOPE_Y0)
	if y <= ROAD_Y1:
		return ROAD_Z
	return lerpf(ROAD_Z, SLOPE_TOP.y, clampf((y - ROAD_Y1) / (SLOPE_TOP.x - ROAD_Y1), 0.0, 1.0))


## Vegetació: pins i arbustos, [Vector4(x, y, z de la base, escala)]. Al talús de davant de
## la càmera TV només hi ha arbustos baixos (si no, taparien el camp).
static func vegetation(seed_value: int = 27) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pines: Array[Vector4] = []
	var bushes: Array[Vector4] = []
	# Talús de l'est: arbustos entre la bardissa i la carretera; pins més amunt.
	for i in 46:
		var y := rng.randf_range(SLOPE_Y0 + 1.5, ROAD_Y0 - 1.0)
		var x := rng.randf_range(-120.0, 120.0)
		bushes.append(Vector4(x, y, ground_z(y), rng.randf_range(0.5, 0.9)))
	for i in 34:
		var y := rng.randf_range(ROAD_Y1 + 3.0, SLOPE_TOP.x)
		var x := rng.randf_range(-130.0, 130.0)
		pines.append(Vector4(x, y, ground_z(y), rng.randf_range(0.8, 1.25)))
	# Camp de matolls del sud.
	for i in 14:
		var x := rng.randf_range(-HL - 70.0, -HL - 14.0)
		var y := rng.randf_range(-60.0, HW + 6.0)
		pines.append(Vector4(x, y, 0.0, rng.randf_range(0.8, 1.3)))
	for i in 24:
		var x := rng.randf_range(-HL - 70.0, -HL - 10.0)
		var y := rng.randf_range(-60.0, HW + 6.0)
		bushes.append(Vector4(x, y, 0.0, rng.randf_range(0.6, 1.1)))
	# Darrere les casetes del club, al nord.
	for i in 10:
		var x := rng.randf_range(HL + 28.0, HL + 70.0)
		var y := rng.randf_range(-50.0, HW + 6.0)
		pines.append(Vector4(x, y, 0.0, rng.randf_range(0.8, 1.2)))
	# Els pins de lluny primer (com a la web), perquè els transparents s'ordenin millor.
	pines.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.y < b.y)
	return {"pines": pines, "bushes": bushes}


## Arbres del carrer Galícia, a la franja de darrere la tanca del passeig.
static func street_trees() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var x := -HL - 4.0
	while x <= HL + 4.0:
		out.append(Vector2(x, TREE_Y))
		x += 8.5
	return out


## Direcció cap al sol en coordenades de Godot (normalitzada).
static func sun_view() -> Vector3:
	var s := SUN.normalized()
	return Coords.to_view(s.x, s.y, s.z)
