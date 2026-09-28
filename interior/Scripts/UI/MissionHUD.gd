extends CanvasLayer
@onready var task_text: Label = $PanelContainer/TaskText
func _process(_delta: float) -> void:
	var t := int(GameManager.elapsed)
	task_text.text = "HOUSE RESCUE  |  %02d:%02d  |  Step %d / 6\n%s\n%s" % [t / 60, t % 60, mini(MissionSystem.current_step + 1, 6), MissionSystem.get_title(), MissionSystem.get_hint()]
