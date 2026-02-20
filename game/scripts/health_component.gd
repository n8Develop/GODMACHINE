extends Node
class_name HealthComponent

signal died
signal health_changed(new_health: int)
signal max_health_changed(new_max: int)
signal damaged(amount: int)

@export var max_health: int = 100
@export var current_health: int = 100
@export var spawn_death_ghost: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	damaged.emit(amount)
	
	if current_health <= 0:
		_die()

func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = min(current_health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)

func _die() -> void:
	# Spawn ghost if enabled
	if spawn_death_ghost:
		var ghost_script := load("res://scripts/player_death_ghost.gd")
		if ghost_script:
			var ghost: Node2D = ghost_script.new()
			ghost.global_position = get_parent().global_position
			get_tree().current_scene.add_child(ghost)
	
	# Emit signal before potential queue_free
	died.emit()