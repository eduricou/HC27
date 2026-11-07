## Col·loca el pal i els objectius de les mans dins de l'actualització de l'esquelet, després
## de la postura i abans de la IK dels braços (PlayerRig.place_stick_now()). Així es fan
## servir les espatlles d'aquest mateix fotograma: corrent, pugen i baixen fins a 25 cm a
## cada passa, i amb les del fotograma anterior la mà dreta no arribava al pal.
class_name StickPlacer
extends SkeletonModifier3D

var rig: PlayerRig


func _process_modification_with_delta(_delta: float) -> void:
	if rig:
		rig.place_stick_now()
