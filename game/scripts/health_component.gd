extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal died
signal took_damage(amount: int)

@export var max_health: int = 100
@export var current_health: int = 100

var _last_hp: int = 100

func _ready() -> void:
	current_health = max_health
	_last_hp = current_health

func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	
	var old_hp := current_health
	current_health = max(0, current_health - amount)
	
	var damage_delta := old_hp - current_health
	took_damage.emit(damage_delta)
	health_changed.emit(current_health)
	
	if current_health == 0:
		_on_death()

func _on_death() -> void:
	# Spawn death ghost for player
	var owner_node := get_parent()
	if owner_node and owner_node.is_in_group("player"):
		_spawn_death_ghost()
	
	died.emit()

func _spawn_death_ghost() -> void:
	var ghost_script := load("res://scripts/player_death_ghost.gd")
	var ghost_instance: Node2D = ghost_script.new()
	ghost_instance.global_position = get_parent().global_position
	
	var main := get_tree().current_scene
	if main:
		main.add_child(ghost_instance)

func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func set_max_health(new_max: int) -> void:
	if new_max <= 0:
		return
	
	max_health = new_max
	current_health = min(current_health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)

func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return current_health > 0

func _process(_delta: float) -> void:
	if current_health != _last_hp:
		_last_hp = current_health