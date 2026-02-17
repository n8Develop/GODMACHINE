extends Control
class_name UIHealthBar

@onready var fill := $Fill
@onready var label := $Label

var _current_hp: int = 0
var _max_hp: int = 0

func _ready() -> void:
	# Find player and connect to their health component
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health: HealthComponent = player.get_node_or_null("HealthComponent")
		if health:
			health.health_changed.connect(_on_health_changed)
			health.max_health_changed.connect(_on_max_health_changed)
			# Initialize with current values
			_current_hp = health.current_health
			_max_hp = health.max_health
			_update_display()

func _on_health_changed(new_hp: int) -> void:
	_current_hp = new_hp
	_update_display()

func _on_max_health_changed(new_max: int) -> void:
	_max_hp = new_max
	_update_display()

func _update_display() -> void:
	if _max_hp <= 0:
		return
	
	var ratio := float(_current_hp) / float(_max_hp)
	fill.size.x = 160.0 * ratio
	
	# Color shifts from green to yellow to red
	if ratio > 0.6:
		fill.color = Color(0.2, 0.9, 0.3, 1.0)
	elif ratio > 0.3:
		fill.color = Color(0.9, 0.9, 0.2, 1.0)
	else:
		fill.color = Color(0.9, 0.2, 0.2, 1.0)
	
	label.text = "%d / %d" % [_current_hp, _max_hp]