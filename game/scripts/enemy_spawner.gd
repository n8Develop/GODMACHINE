extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_enemies: int = 4
@export var spawn_radius: float = 50.0
@export var spawner_health: int = 40

var _spawn_timer: float = 0.0
var _active_enemies: int = 0
var _current_health: int = 0
var _health_bar: ColorRect = null
var _is_alive: bool = true

func _ready() -> void:
	add_to_group("enemies")
	_current_health = spawner_health
	_create_health_bar()
	
	if not enemy_scene:
		push_error("GODMACHINE ERROR: enemy_spawner has no enemy_scene assigned")
		return

func _create_health_bar() -> void:
	_health_bar = ColorRect.new()
	_health_bar.size = Vector2(40, 4)
	_health_bar.position = Vector2(-20, -30)
	_health_bar.color = Color(0.8, 0.1, 0.1, 1.0)
	_health_bar.z_index = 50
	add_child(_health_bar)

func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	
	if not enemy_scene:
		return
	
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval and _active_enemies < max_enemies:
		_spawn_enemy()
		_spawn_timer = 0.0
	
	# Check for nearby player attacks
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var distance := global_position.distance_to(player.global_position)
		if distance <= 40.0 and player.get(&"_has_weapon"):
			if player.get(&"_attack_timer") <= 0.0 and Input.is_action_just_pressed(&"attack"):
				take_damage(10)

func take_damage(amount: int) -> void:
	if not _is_alive:
		return
	
	_current_health -= amount
	_update_health_bar()
	_flash_damage()
	
	if _current_health <= 0:
		_die()

func _update_health_bar() -> void:
	if _health_bar:
		var health_percent := clampf(float(_current_health) / float(spawner_health), 0.0, 1.0)
		_health_bar.size.x = 40.0 * health_percent

func _flash_damage() -> void:
	var rect := get_node_or_null("ColorRect")
	if rect:
		rect.modulate = Color(2.0, 2.0, 2.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		if rect:
			rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _die() -> void:
	_is_alive = false
	
	# Spawn death particles
	for i in range(12):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(-3, -3)
		particle.color = Color(0.8, 0.1, 0.1, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 12.0) * i
		var speed := randf_range(50.0, 90.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + velocity * 0.5, 0.8)
		tween.tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.finished.connect(particle.queue_free)
	
	queue_free()

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