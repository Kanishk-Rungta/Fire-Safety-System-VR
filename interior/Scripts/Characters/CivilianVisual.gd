extends Node3D
var breath := 0.0
func _process(delta: float) -> void:
	breath += delta
	$Torso.scale.y = 0.49 + sin(breath * 2.2) * 0.007
	$Head.rotation.x = -0.13 + sin(breath * 2.2) * 0.008
