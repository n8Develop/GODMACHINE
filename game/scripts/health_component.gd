extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)

func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
	
	if current_health <= 0:
		current_health = 0
		_spawn_death_particles()
		died.emit()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health)

func _spawn_death_particles() -> void:
	var parent := get_parent()
	if not parent is Node2D:
		return
	
	var particle_count := randi_range(8, 14)
	for i in particle_count:
		var particle := ColorRect.new()
		var size := randi_range(3, 7)
		particle.custom_minimum_size = Vector2(size, size)
		particle.color = Color(0.8, 0.1, 0.1, 1.0)
		particle.position = parent.global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.z_index = 50
		
		var direction := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var speed := randf_range(60, 120)
		
		parent.get_parent().add_child(particle)
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + direction * speed, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.finished.connect(particle.queue_free)