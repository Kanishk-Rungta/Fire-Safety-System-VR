extends Area3D

var rescued = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not rescued and body.is_in_group("victim") and body.is_alive and MissionSystem.current_step == MissionSystem.Step.REACH_SAFE_ZONE:
		rescued = true
		print("VICTIM RESCUED SUCCESSFULLY!")
		
		var ms = get_node_or_null("/root/MissionSystem")
		if ms:
			ms.advance(ms.Step.COMPLETE)
		
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.game_won()
		# Give visual feedback that they are safe
		var mesh = body.get_node_or_null("MeshInstance3D")
		if mesh:
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.0, 1.0, 0.0)
			mesh.material_override = material
