extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_enemies: int = 4
@export var spawn_radius: float = 50.0
@export var spawner_health: int = 40

var _spawn_timer: float = 0.0
var _spawned_enemies: Array[Node] = []
var _current_health: int = 0
var _health_bar: Control = null
var _health_bar_fill: ColorRect = null

func _ready() -> void:
	add_to_group("spawners")
	_current_health = spawner_health
	_create_health_bar()

func get_enemy_type() -> String:
	if not enemy_scene:
		return ""
	var path := enemy_scene.resource_path
	if "bat" in path:
		return "bat"
	elif "slime" in path:
		return "slime"
	elif "skeleton" in path:
		return "skeleton"
	return "unknown"

func set_enemy_scene(new_scene: PackedScene) -> void:
	enemy_scene = new_scene

func _create_health_bar() -> void:
	_health_bar = Control.new()
	_health_bar.position = Vector2(-20, -30)
	_health_bar.z_index = 50
	add_child(_health_bar)
	
	var bg := ColorRect.new()
	bg.size = Vector2(40, 4)
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	_health_bar.add_child(bg)
	
	_health_bar_fill = ColorRect.new()
	_health_bar_fill.size = Vector2(40, 4)
	_health_bar_fill.color = Color(0.9, 0.2, 0.2, 1.0)
	_health_bar.add_child(_health_bar_fill)

func _physics_process(delta: float) -> void:
	_spawn_timer += delta
	
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		if _spawned_enemies.size() < max_enemies:
			_spawn_enemy()
	
	# Check if player weapon is in range and attacking
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("_has_weapon"):
		var distance := global_position.distance_to(player.global_position)
		if distance <= player.attack_range:
			if Input.is_action_just_pressed(&"attack") and player._has_weapon:
				take_damage(player.attack_damage)

func take_damage(amount: int) -> void:
	_current_health -= amount
	_update_health_bar()
	_flash_damage()
	
	if _current_health <= 0:
		_die()

func _update_health_bar() -> void:
	if not _health_bar_fill:
		return
	
	var health_percent := float(_current_health) / float(spawner_health)
	_health_bar_fill.size.x = 40.0 * clamp(health_percent, 0.0, 1.0)

func _flash_damage() -> void:
	var visual := get_node_or_null("Visual")
	if visual is ColorRect:
		visual.modulate = Color(2.0, 2.0, 2.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(visual):
			visual.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _die() -> void:
	# Spawn death particles
	for i in range(12):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(-3, -3)
		particle.color = Color(0.9, 0.2, 0.1, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 12.0) * i
		var velocity := Vector2(cos(angle), sin(angle)) * randf_range(60, 120)
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + velocity * 0.5, 0.6)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.finished.connect(particle.queue_free)
	
	queue_free()

func _spawn_enemy() -> void:
	if not enemy_scene:
		return
	
	var enemy := enemy_scene.instantiate()
	
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	enemy.global_position = global_position + offset
	
	get_parent().add_child(enemy)
	_spawned_enemies.append(enemy)
	
	var health := enemy.get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	await get_tree().create_timer(0.1).timeout
	
	var living_enemies: Array[Node] = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			living_enemies.append(enemy)
	
	_spawned_enemies = living_enemies