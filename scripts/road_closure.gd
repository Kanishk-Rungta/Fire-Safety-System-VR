extends Node3D
## Static traffic stays outside the incident area; the sign reflects placed cones.
var placed_bays: Dictionary = {}
var clock := 0.0

func cone_placed(bay: String) -> void:
	placed_bays[bay] = true
	var marker := get_node_or_null("ConeBay_" + bay)
	if marker: marker.hide()
	var label: Label3D = $ClosureSign/Message
	label.text = "ROAD CLOSED\nFIRE CREW AT WORK" if placed_bays.size() >= 2 else "FIRE RESPONSE\nSTOP HERE"

func _process(delta: float) -> void:
	clock += delta
	for lamp in get_tree().get_nodes_in_group("traffic_hazards"):
		if is_ancestor_of(lamp):
			var mat: StandardMaterial3D = lamp.material_override
			mat.emission_energy_multiplier = 1.6 if fmod(clock, 1.0) < 0.5 else 0.0
