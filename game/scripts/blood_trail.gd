extends Node2D
class_name BloodTrail

@export var drop_interval: float = 0.5
@export var hp_threshold: float = 0.5  # Start bleeding below 50% HP
@export var drop_alpha_base: float = 0.3
@export var drop_alpha_critical: float = 0.5

var _drop_timer: float = 0.0
var _bleeding_suppressed: bool = false
var _suppress_timer: float = 0.0

func _ready() -> void:
	add_to_group("blood_trail")
	z_index = -4

func _physics_process(delta: float) -> void:
	# Handle bleeding suppression
	if _bleeding_suppressed:
		_suppress_timer -= delta
		if _suppress_timer <= 0.0:
			_bleeding_suppressed = false
	
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	
	var health := player.get_node_or_null("HealthComponent")
	if not health:
		return
	
	var hp_percent := float(health.current_health) / float(health.max_health)
	
	# Only bleed if wounded and not suppressed
	if hp_percent >= hp_threshold or _bleeding_suppressed:
		return
	
	_drop_timer += delta
	
	if _drop_timer >= drop_interval:
		_drop_timer = 0.0
		_spawn_blood_drop(player.global_position, hp_percent)

func _spawn_blood_drop(pos: Vector2, hp_percent: float) -> void:
	var drop := ColorRect.new()
	drop.size = Vector2(4, 4)
	drop.position = pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))
	
	# Darker blood as HP drops
	var severity := 1.0 - (hp_percent / hp_threshold)
	var red := 0.6 - (severity * 0.2)
	var alpha := lerp(drop_alpha_base, drop_alpha_critical, severity)
	
	drop.color = Color(red, 0.1, 0.1, alpha)
	drop.z_index = -4
	
	# Add to current room, not to this trail node
	var room := get_tree().current_scene.get_node_or_null("CurrentRoom")
	if room:
		room.add_child(drop)
	else:
		get_tree().current_scene.add_child(drop)

func stop_bleeding(duration: float) -> void:
	_bleeding_suppressed = true
	_suppress_timer = duration