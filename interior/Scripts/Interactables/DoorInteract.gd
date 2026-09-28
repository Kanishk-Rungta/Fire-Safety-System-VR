extends Node3D

## Simple door interaction for desktop mode.
## Left-click to toggle open/close.

var is_open: bool = false
var tween: Tween

@onready var hinge = $InteractableHinge

func interact():
	if tween and tween.is_running():
		return
	
	is_open = !is_open
	var target_angle = deg_to_rad(90.0) if is_open else 0.0
	
	tween = create_tween()
	tween.tween_property(hinge, "rotation:y", target_angle, 0.5).set_ease(Tween.EASE_IN_OUT)
	print("Door ", "opened" if is_open else "closed")
