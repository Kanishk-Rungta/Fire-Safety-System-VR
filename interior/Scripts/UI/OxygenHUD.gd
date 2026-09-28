extends CanvasLayer

@onready var status_label: Label        = $Control/StatusLabel
@onready var prompt_label: Label        = $Control/PromptLabel
@onready var alert_label: Label         = get_node_or_null("Control/AlertLabel")
@onready var vignette: ColorRect        = $VignetteOverlay
@onready var crosshair_h: Panel         = $Control/CrosshairH
@onready var crosshair_v: Panel         = $Control/CrosshairV
@onready var fire_aim_ring: Panel       = $Control/FireAimRing

const CROSSHAIR_NORMAL_COLOR = Color(1.0, 1.0, 1.0, 0.75)
const CROSSHAIR_FIRE_COLOR   = Color(1.0, 0.35, 0.05, 1.0)

var pulse_timer: float = 0.0
var alert_timer: float = 0.0
var alert_text:  String = ""

var _last_o2: int = 100
var _last_hp: int = 100

func _ready():
	vignette.color = Color(0, 0, 0, 0)
	prompt_label.text = ""
	if alert_label:
		alert_label.visible = false

func _process(delta: float) -> void:
	pass

func show_spread_alert(object_name: String):
	alert_text = "🔥 FLASHOVER: Fire spread to the %s!" % object_name
	alert_timer = 5.0
	if alert_label:
		alert_label.text = alert_text
		alert_label.visible = true

func show_victim_danger_alert():
	alert_text = "🚨 CRITICAL: Fire encroaching on the Victim!"
	alert_timer = 6.0
	if alert_label:
		alert_label.text = alert_text
		alert_label.visible = true

func update_health(current_hp: float, max_hp: float, on_fire: bool) -> void:
	var ratio = clamp(current_hp / max_hp, 0.0, 1.0)
	_last_hp = int(ratio * 100.0)
	_update_status_label()

func set_crosshair_fire(on: bool) -> void:
	if fire_aim_ring:
		fire_aim_ring.visible = on
	var col = CROSSHAIR_FIRE_COLOR if on else CROSSHAIR_NORMAL_COLOR
	if crosshair_h:
		crosshair_h.modulate = col
	if crosshair_v:
		crosshair_v.modulate = col

func update_oxygen(current_o2: float, max_o2: float, in_smoke: bool,
		is_crouching: bool, delta: float = 0.016, smoke_density: float = 1.0):
	pulse_timer += delta * 5.0
	var ratio = clamp(current_o2 / max_o2, 0.0, 1.0)
	_last_o2 = int(ratio * 100.0)
	_update_status_label()

	if in_smoke and not is_crouching:
		var pulse = (sin(pulse_timer * 1.5) + 1.0) * 0.5
		prompt_label.visible = true
		prompt_label.text = "⚠️ TOXIC SMOKE! CROUCH (CTRL / C) TO GET LOW"
		prompt_label.modulate = Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.9, 0.2), pulse)
		var si = (1.0 - ratio) * 0.6 * smoke_density + 0.25 * smoke_density
		vignette.color = Color(0.15, 0.02, 0.02, si + pulse * 0.15)
	elif in_smoke and is_crouching:
		prompt_label.visible = true
		if smoke_density < 0.5:
			var pct = int((1.0 - smoke_density) * 100.0)
			prompt_label.text = "🪟 SMOKE CLEARING (%d%%) — ALMOST SAFE TO STAND" % pct
			prompt_label.modulate = Color(0.8, 0.9, 0.4, 1.0)
		else:
			prompt_label.text = "✅ BELOW SMOKE LAYER — AIR IS BREATHABLE"
			prompt_label.modulate = Color(0.4, 0.9, 0.5, 1.0)
		vignette.color.a = move_toward(vignette.color.a, 0.0, delta * 2.0)
	else:
		if ratio < 0.99:
			prompt_label.visible = true
			prompt_label.text = "RECOVERING OXYGEN..."
			prompt_label.modulate = Color(0.6, 0.8, 1.0, 0.8)
		elif is_crouching:
			prompt_label.visible = true
			prompt_label.text = "✅ AIR CLEAR — PRESS C TO STAND UP"
			prompt_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		else:
			prompt_label.visible = false
			prompt_label.text = ""
		vignette.color.a = move_toward(vignette.color.a, 0.0, delta * 3.0)

	if alert_timer > 0.0:
		alert_timer -= delta
		if alert_label:
			alert_label.visible = true
			alert_label.text = alert_text
			var flash = (sin(pulse_timer * 3.0) + 1.0) * 0.5
			alert_label.modulate = Color(1.0, 0.35, 0.1).lerp(Color(1.0, 0.95, 0.3), flash)
	else:
		if alert_label and alert_label.visible:
			alert_label.visible = false

func _update_status_label():
	if status_label:
		status_label.text = "Oxygen: %d%%\nHealth: %d%%" % [_last_o2, _last_hp]
