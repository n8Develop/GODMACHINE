extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_enemies: int = 4
@export var spawn_radius: float = 50.0

var _spawn_timer: float = 0.0
var _active_enemies: int = 0

func _ready() -> void:
	if not enemy_scene:
		push_error("GODMACHINE ERROR: enemy_spawner has no enemy_scene assigned")
		return

func _physics_process(delta: float) -> void:
	if not enemy_scene:
		return
	
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval and _active_enemies < max_enemies:
		_spawn_enemy()
		_spawn_timer = 0.0

func _spawn_enemy() -> void:
	var enemy_instance := enemy_scene.instantiate()
	if not enemy_instance:
		return
	
	# Random position around spawner
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	enemy_instance.global_position = global_position + offset
	
	# Connect death signal to track count
	var health_comp := enemy_instance.get_node_or_null("HealthComponent")
	if health_comp:
		health_comp.died.connect(_on_enemy_died)
	
	get_parent().add_child(enemy_instance)
	_active_enemies += 1
	print("GODMACHINE: Spawner created entity #", _active_enemies)

func _on_enemy_died() -> void:
	_active_enemies -= 1
	if _active_enemies < 0:
		_active_enemies = 0