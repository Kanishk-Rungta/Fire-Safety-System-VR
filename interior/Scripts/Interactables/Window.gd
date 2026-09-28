extends Node3D
## Interactable window — left-click to open/close.
## When opened the connected SmokeZone gradually disperses over ~12 seconds.
## When closed it reactivates the zone.

@export var smoke_zone_path: NodePath = NodePath("")
@export var is_open: bool = false

var pane_node: CSGBox3D = null
var _smoke_zone: Node = null

func _ready():
	add_to_group("interactable")
	add_to_group("windows")
	if smoke_zone_path:
		_smoke_zone = get_node_or_null(smoke_zone_path)
	pane_node = get_node_or_null("Pane")

func interact():
	if is_open:
		_close()
	else:
		_open()

func _open():
	is_open = true
	print("Window opened — smoke dispersing gradually.")
	

	# Slide pane up
	if pane_node:
		var tween = create_tween()
		tween.tween_property(pane_node, "position:y", 1.4, 0.6).set_ease(Tween.EASE_OUT)

	# Trigger gradual smoke dispersal
	if _smoke_zone:
		if _smoke_zone.has_method("gradual_disperse"):
			_smoke_zone.gradual_disperse()
		else:
			# Fallback: instant kill (legacy)
			_smoke_zone.set_process(false)

func _close():
	is_open = false
	print("Window closed — smoke building back up.")

	# Slide pane back down
	if pane_node:
		var tween = create_tween()
		tween.tween_property(pane_node, "position:y", 0.0, 0.6).set_ease(Tween.EASE_IN)

	# Reactivate smoke zone
	if _smoke_zone:
		if _smoke_zone.has_method("reactivate"):
			_smoke_zone.reactivate()
		else:
			_smoke_zone.set_process(true)
