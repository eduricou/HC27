## Conversió entre les coordenades de la simulació i les de Godot.
## Simulació: x = llargada, y = amplada (+y cap a la càmera TV), z = altura.
## Godot: Vector3(x, z, y), amb Y amunt. ref: comentari de la línia 1207 de la referència
class_name Coords
extends RefCounted


static func to_view(x: float, y: float, z: float = 0.0) -> Vector3:
	return Vector3(x, z, y)


## Rotació al voltant de Y perquè el −Z local d'un node apunti cap a l'angle `face` de la
## simulació (direcció (cos face, sin face)).
static func face_to_yaw(face: float) -> float:
	return atan2(-cos(face), -sin(face))
