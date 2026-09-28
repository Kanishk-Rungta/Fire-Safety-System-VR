extends Node

## FireSpreadManager — Autoload singleton that makes ignited Combustible objects
## radiate heat to their neighbors, creating cascading fire spread independent of
## the original Fire.tscn source node.  This means fire "creeps" furniture-to-furniture
## even after the initial source has been extinguished.

@export var spread_radius: float = 2.5
@export var heat_per_second: float = 14.0

func _process(delta: float) -> void:
	var all_combustibles = get_tree().get_nodes_in_group("combustible")

	for source in all_combustibles:
		if not is_instance_valid(source):
			continue
		# Only ignited, still-burning objects spread heat
		if not source.get("is_ignited"):
			continue
		if source.get("is_burnt_out"):
			continue

		var source_pos: Vector3 = source.global_position

		for target in all_combustibles:
			if not is_instance_valid(target) or target == source:
				continue
			if target.get("is_ignited") or target.get("is_burnt_out"):
				continue

			var dist: float = source_pos.distance_to(target.global_position)
			if dist <= spread_radius:
				var falloff: float = 1.0 - (dist / spread_radius)
				# Thin-fabric items (curtains, towels) ignite even faster from nearby fire
				var fabric_bonus: float = 1.4 if target.get("is_thin_fabric") else 1.0
				var heat: float = heat_per_second * falloff * fabric_bonus * delta
				if target.has_method("apply_heat"):
					target.apply_heat(heat, source)
