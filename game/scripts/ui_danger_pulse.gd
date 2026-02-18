extends Control
class_name UIDangerPulse

var _pulse_timer: float = 0.0
var _pulse_speed: float = 2.0
var _base_alpha: float = 0.0

@onready var _overlay: ColorRect = $Overlay

func _ready() -> void:
	# Create red vignette overlay
	_overlay = ColorRect.new()
	_overlay.anchor_left = 0.0
	_overlay.anchor_top = 0.0
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.color = Color(0.8, 0.1, 0.1, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		_overlay.modulate.a = 0.0
		return
	
	var health_component := player.get_node_or_null("HealthComponent")
	if not health_component:
		_overlay.modulate.a = 0.0
		return
	
	var current_hp: int = health_component.get_meta("current_health", 100)
	var max_hp: int = health_component.get_meta("max_health", 100)
	var health_percent := float(current_hp) / float(max_hp)
	
	# Danger threshold: pulse when below 30% health
	if health_percent < 0.3:
		_pulse_timer += delta * _pulse_speed
		var pulse := abs(sin(_pulse_timer))
		
		# Intensity based on how low health is
		var danger_level := 1.0 - (health_percent / 0.3)
		_base_alpha = 0.15 + (danger_level * 0.25)
		
		_overlay.modulate.a = _base_alpha * pulse
		
		# Speed up pulse as health drops
		_pulse_speed = 2.0 + (danger_level * 2.0)
	else:
		# Fade out when healthy
		_overlay.modulate.a = lerp(_overlay.modulate.a, 0.0, delta * 3.0)
		_pulse_timer = 0.0
		_pulse_speed = 2.0