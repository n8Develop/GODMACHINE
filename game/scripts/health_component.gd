extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal died

@export var max_health: int = 100
@export var current_health: int = 100
@export var spawns_blood: bool = true

var _flash_timer: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
	current_health = max_health

func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			var parent := get_parent()
			if parent:
				parent.modulate = Color.WHITE

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	
	# Spawn blood drops
	if spawns_blood and get_parent() is Node2D:
		_spawn_blood_drops()
	
	# Flash white
	var parent := get_parent()
	if parent:
		parent.modulate = Color(2.0, 2.0, 2.0, 1.0)
		_flash_timer = 0.1
	
	if current_health <= 0:
		_is_dead = true
		died.emit()

func _spawn_blood_drops() -> void:
	var parent := get_parent() as Node2D
	if not parent:
		return
	
	var room := parent.get_parent()
	if not room:
		return
	
	# Create 3-5 blood drops
	var drop_count := randi_range(3, 5)
	for i in range(drop_count):
		var drop := ColorRect.new()
		drop.size = Vector2(3, 3)
		drop.color = Color(0.6, 0.1, 0.1, 1.0)
		drop.z_index = -3
		
		# Random offset from hit position
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		drop.global_position = parent.global_position + offset
		
		room.add_child(drop)
		
		# Fade out over time
		var tween := create_tween()
		tween.tween_property(drop, "modulate:a", 0.0, 2.0)
		tween.tween_callback(drop.queue_free)

func heal(amount: int) -> void:
	if _is_dead:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = min(current_health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)