extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal took_damage(amount: int)
signal died

@export var max_health: int = 100
@export var current_health: int = 100
@export var invulnerable: bool = false

var _last_hp: int = 100

func _ready() -> void:
	current_health = max_health
	_last_hp = current_health

func take_damage(amount: int) -> void:
	if invulnerable or current_health <= 0:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	took_damage.emit(amount)
	
	if current_health <= 0:
		_spawn_death_ghost()
		died.emit()

func _spawn_death_ghost() -> void:
	# Only spawn ghost for player deaths
	if not get_parent().is_in_group("player"):
		return
	
	var ghost_script := load("res://scripts/player_death_ghost.gd")
	var ghost: Node2D = ghost_script.new()
	ghost.global_position = get_parent().global_position
	
	# Add to main scene, not as child of dying entity
	var main := get_tree().current_scene
	if main:
		main.add_child(ghost)

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = min(current_health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)

func _process(_delta: float) -> void:
	# Track HP changes for wound flash
	if current_health < _last_hp:
		var damage_taken := _last_hp - current_health
		# Flash intensity based on damage severity
		if damage_taken >= 20:
			_flash_wound(0.6)
		elif damage_taken >= 10:
			_flash_wound(0.4)
		else:
			_flash_wound(0.2)
	
	_last_hp = current_health

func _flash_wound(intensity: float) -> void:
	var wound_flash := get_tree().current_scene.get_node_or_null("CanvasLayer/UIWoundFlash")
	if wound_flash and wound_flash.has_method("trigger_flash"):
		wound_flash.trigger_flash(intensity)