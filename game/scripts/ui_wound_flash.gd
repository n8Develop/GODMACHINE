extends Control
class_name UIWoundFlash

var _flash_overlay: ColorRect
var _last_hp: int = 100
var _flash_duration: float = 0.0

func _ready() -> void:
	# Create full-screen red flash overlay
	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(0.8, 0.1, 0.1, 0.0)
	_flash_overlay.anchor_right = 1.0
	_flash_overlay.anchor_bottom = 1.0
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.z_index = 90
	add_child(_flash_overlay)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var health := player.get_node_or_null("HealthComponent")
	if not health:
		return
	
	var current_hp: int = health.get("current_health")
	var max_hp: int = health.get("max_health")
	
	# Detect damage
	if current_hp < _last_hp:
		var damage: int = _last_hp - current_hp
		if damage >= 10:
			# Significant wound — trigger flash
			var intensity: float = min(float(damage) / float(max_hp), 0.5)
			_flash_overlay.color.a = intensity
			_flash_duration = 0.3
	
	_last_hp = current_hp
	
	# Fade flash
	if _flash_duration > 0.0:
		_flash_duration -= delta
		if _flash_duration <= 0.0:
			_flash_overlay.color.a = 0.0
		else:
			_flash_overlay.color.a = (_flash_duration / 0.3) * 0.5