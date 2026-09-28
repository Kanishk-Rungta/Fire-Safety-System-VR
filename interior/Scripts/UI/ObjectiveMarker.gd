## ObjectiveMarker — a 3D floating beacon above the current mission target.
## Drop one instance per possible target (extinguisher, fire, victim, safe zone)
## into the scene and set which mission step it belongs to.
## It auto-shows/hides based on MissionSystem.current_step.
extends Node3D

## Which mission step this marker represents.
@export_enum("OPEN_WINDOWS:0","PICKUP_EXTINGUISHER:1","EXTINGUISH_FIRE:2","FIND_VICTIM:3","CARRY_VICTIM:4","REACH_SAFE_ZONE:5") \
	var for_step: int = 0

## If set, the marker will hover above this node instead of its own position.
@export var follow_target: NodePath = NodePath("")

@onready var label_3d: Label3D     = get_node_or_null("Label3D")
@onready var beacon_mesh: MeshInstance3D = get_node_or_null("BeaconMesh")
@onready var beacon_light: OmniLight3D   = get_node_or_null("BeaconLight")

var _follow_node: Node3D = null
var _base_y: float = 0.0
var _pulse_timer: float = 0.0
var _player: Node3D = null

const HOVER_HEIGHT: float = 2.2   # metres above target origin
const PULSE_SPEED:  float = 2.5
const PULSE_RANGE:  float = 0.18  # up-down oscillation amplitude

func _ready() -> void:
	_base_y = global_position.y
	if follow_target:
		_follow_node = get_node_or_null(follow_target)

	# Start hidden — _check_visibility will show/hide each frame
	visible = false

	# Connect to mission step changes
	if MissionSystem:
		MissionSystem.step_changed.connect(_on_step_changed)
	_check_visibility()

func _on_step_changed(_step, _title, _hint) -> void:
	_check_visibility()

func _check_visibility() -> void:
	var ms = get_node_or_null("/root/MissionSystem")
	if ms:
		visible = (ms.current_step == for_step)
		if for_step == 0:
			visible = visible and is_instance_valid(_follow_node) and not _follow_node.is_open
		if for_step == 2:
			for fire in get_tree().get_nodes_in_group("fire"):
				if not fire.is_extinguished:
					_follow_node = fire
					break

func _process(delta: float) -> void:
	_check_visibility()
	if not visible:
		return

	_pulse_timer += delta

	# Follow dynamic target (e.g. victim moving when carried)
	if _follow_node and is_instance_valid(_follow_node):
		var tp = _follow_node.global_position
		global_position.x = tp.x
		global_position.z = tp.z
		global_position.y = tp.y + HOVER_HEIGHT + sin(_pulse_timer * PULSE_SPEED) * PULSE_RANGE
	else:
		global_position.y = _base_y + sin(_pulse_timer * PULSE_SPEED) * PULSE_RANGE

	# Pulse light intensity
	if beacon_light:
		beacon_light.light_energy = 1.2 + sin(_pulse_timer * PULSE_SPEED * 1.5) * 0.5

	# Update distance label
	if label_3d:
		if not _player:
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				_player = players[0]
		if _player and is_instance_valid(_player):
			var dist = _player.global_position.distance_to(global_position)
			label_3d.text = "▼ %.1f m" % dist
