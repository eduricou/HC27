## Constants del camp i del joc, i geometria compartida de la simulació.
## Unitats: metres i segons. x = llargada, y = amplada, z = altura.
## ref: línies 289–295 i 363–372 de reference/web/index.html
class_name Constants
extends RefCounted

const FL := 91.4
const FW := 55.0
const HL := FL / 2.0
const HW := FW / 2.0
## Mitja amplada, altura i fondària de la porteria.
const GHW := 1.83
const GH := 2.14
const GD := 1.2
## Radi del cercle i de la línia discontínua (5 m més enllà).
const CR := 14.63
const DR := 19.63
## Línia de 23 m, mesurada des del centre.
const L23 := HL - 22.9
const PSPOT := 6.475
const STEP := 1.0 / 60.0
## Durada d'un quart al rellotge del partit (15 min).
const QGAME := 900.0

## Pes de cada atribut [velocitat, control, passada, xut, defensa, resistència] a la valoració.
const WEIGHTS := {
	"DF": [0.15, 0.15, 0.2, 0.05, 0.35, 0.1],
	"MF": [0.15, 0.25, 0.3, 0.1, 0.1, 0.1],
	"FW": [0.25, 0.25, 0.1, 0.3, 0.0, 0.1],
}
## Posicions base (1-4-3-3) en fraccions del camp: [x, y].
const SLOTS := {
	"DF": [[-0.62, -0.62], [-0.7, -0.2], [-0.7, 0.2], [-0.62, 0.62]],
	"MF": [[-0.28, -0.5], [-0.32, 0.0], [-0.28, 0.5]],
	"FW": [[0.12, -0.55], [0.2, 0.0], [0.12, 0.55]],
}
## Dificultat de la CPU: reacció, error, velocitat, entrada i bonus del porter.
const DIFFS := {
	"facil": {"react": 0.62, "err": 1.7, "spd": 0.92, "tack": 0.65, "gk": -0.12},
	"normal": {"react": 0.38, "err": 1.0, "spd": 1.0, "tack": 1.0, "gk": 0.0},
	"dificil": {"react": 0.22, "err": 0.6, "spd": 1.04, "tack": 1.3, "gk": 0.07},
}
## Colors de pell i de cabell (només per a la presentació; la simulació en desa l'índex).
const SKINS: Array[String] = [
	"#f1c9a8", "#e3b48e", "#cf9a72", "#b07a52", "#8a5a3b", "#efc19c", "#d8a37c"
]
const HAIRS: Array[String] = [
	"#2b1d14",
	"#8e8a84",
	"#4a2f1d",
	"#c9c6be",
	"#1b1a19",
	"#6e6a64",
	"#5a4634",
	"#dedcd5",
	"#3a2a20"
]


## Diferència d'angle de a a b, normalitzada a [-π, π]. ref: angDiff()
static func ang_diff(a: float, b: float) -> float:
	var d := b - a
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	return d


## Si (x, y) és dins del cercle d'atac de la porteria del costat `side` (+1 o −1).
## ref: inCircle()
static func in_circle(x: float, y: float, side: int, r: float = CR) -> bool:
	var dx := (side * HL - x) * side
	if dx < -0.3:
		return false
	var ay := absf(y)
	if ay <= GHW:
		return dx <= r
	var ey := ay - GHW
	return sqrt(dx * dx + ey * ey) <= r


## Porta un cop franc d'atac a menys de 5 m del cercle fins a la línia discontínua.
## Retorna [x, y]. ref: pushToDotted()
static func push_to_dotted(x: float, y: float, side: int) -> PackedFloat64Array:
	var gx := side * HL
	var dx := (gx - x) * side
	var ay := absf(y)
	var sg := -1.0 if y < 0.0 else 1.0
	if ay <= GHW:
		return PackedFloat64Array([gx - side * DR, y])
	var vx := dx
	var vy := ay - GHW
	var l := sqrt(vx * vx + vy * vy)
	if l == 0.0:
		l = 1.0
	return PackedFloat64Array([gx - side * vx / l * DR, sg * (GHW + vy / l * DR)])
