extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal died

@export var max_health: int = 100
@export var current_health: int = max_health

var _flash_timer: float = 0.0
var _parent_sprite: Node = null

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health)
	max_health_changed.emit(max_health)
	
	# Find any ColorRect child of parent for flashing
	if get_parent():
		for child in get_parent().get_children():
			if child is ColorRect:
				_parent_sprite = child
				break

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _parent_sprite:
			# Restore original modulation
			_parent_sprite.modulate = Color.WHITE

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health)
	
	# Flash white when hit
	if _parent_sprite:
		_parent_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		_flash_timer = 0.1
	
	if current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = mini(current_health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)