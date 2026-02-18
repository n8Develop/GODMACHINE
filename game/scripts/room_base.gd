extends Node2D
class_name RoomBase

signal room_cleared
signal player_entered
signal player_exited

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array[Node] = []
var _spawners: Array[Node] = []
var _fade_overlay: ColorRect = null

func _ready() -> void:
	add_to_group("rooms")
	_create_fade_overlay()
	await get_tree().process_frame
	_find_doors()
	_find_enemies()
	_find_spawners()
	_adapt_to_memory()
	_spawn_floor_debris()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()
	else:
		is_cleared = true
	
	_fade_from_black()

func _spawn_floor_debris() -> void:
	# Simple scattered debris — bones, rocks, cracks
	var debris_container := Node2D.new()
	debris_container.name = "FloorDebris"
	debris_container.z_index = -5
	add_child(debris_container)
	
	# Get room bounds from walls
	var bounds := Rect2(0, 0, 640, 480)
	var walls := get_node_or_null("Walls")
	if walls:
		for child in walls.get_children():
			if child is CollisionShape2D:
				var shape := child.shape as RectangleShape2D
				if shape:
					bounds = Rect2(child.global_position - shape.size/2, shape.size)
					break
	
	# Spawn 8-16 debris pieces
	var count := randi_range(8, 16)
	for i in range(count):
		var debris := ColorRect.new()
		var debris_type := randi() % 3
		
		match debris_type:
			0:  # Bone fragment
				debris.size = Vector2(randf_range(4, 8), randf_range(2, 4))
				debris.color = Color(0.85, 0.82, 0.75, 0.6)
			1:  # Rock
				debris.size = Vector2(randf_range(3, 6), randf_range(3, 6))
				debris.color = Color(0.3, 0.3, 0.35, 0.5)
			2:  # Crack/stain
				debris.size = Vector2(randf_range(6, 12), randf_range(1, 2))
				debris.color = Color(0.15, 0.15, 0.18, 0.4)
		
		# Random position within room bounds
		debris.position = Vector2(
			randf_range(bounds.position.x + 40, bounds.position.x + bounds.size.x - 40),
			randf_range(bounds.position.y + 40, bounds.position.y + bounds.size.y - 40)
		)
		debris.rotation = randf() * TAU
		debris_container.add_child(debris)

func _adapt_to_memory() -> void:
	var memory := get_node_or_null("/root/Main/DungeonMemory") as DungeonMemory
	if not memory:
		return
	
	# Emergency healing when desperate
	if memory.is_player_desperate():
		_spawn_emergency_health()
	
	# Adjust enemy count based on threat
	var adaptive_count := memory.get_adaptive_spawn_count(_enemies.size())
	var diff := adaptive_count - _enemies.size()
	
	if diff > 0:
		for i in range(diff):
			_spawn_additional_enemy()
	elif diff < 0:
		for i in range(abs(diff)):
			if _enemies.size() > 0:
				var idx := randi() % _enemies.size()
				_enemies[idx].queue_free()
				_enemies.remove_at(idx)
	
	# Randomize spawner enemies to avoid patterns
	for spawner in _spawners:
		if spawner.has_method("get_enemy_type"):
			var enemy_type := spawner.get_enemy_type()
			if memory.should_force_variety(enemy_type):
				_randomize_spawner_enemy(spawner)

func _spawn_emergency_health() -> void:
	var health_scene := load("res://scenes/pickup_health.tscn") as PackedScene
	if not health_scene:
		return
	
	var pickup := health_scene.instantiate()
	pickup.position = Vector2(320, 240) + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	var pickups := get_node_or_null("Pickups")
	if pickups:
		pickups.add_child(pickup)

func _spawn_additional_enemy() -> void:
	if _enemies.size() == 0:
		return
	
	var template := _enemies[randi() % _enemies.size()]
	var new_enemy := template.duplicate()
	new_enemy.position = Vector2(randf_range(100, 540), randf_range(100, 380))
	
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		enemies_container.add_child(new_enemy)
		_enemies.append(new_enemy)
		
		var health := new_enemy.get_node_or_null("HealthComponent")
		if health and health.has_signal("died"):
			health.died.connect(_on_enemy_died)

func _randomize_spawner_enemy(spawner: Node2D) -> void:
	if not spawner.has_method("set_enemy_scene"):
		return
	
	const ENEMY_SCENES := [
		"res://scenes/enemy_slime_poison.tscn",
		"res://scenes/enemy_bat.tscn",
		"res://scenes/enemy_skeleton.tscn"
	]
	
	var scene_path := ENEMY_SCENES[randi() % ENEMY_SCENES.size()]
	var new_scene := load(scene_path) as PackedScene
	if new_scene:
		spawner.set_enemy_scene(new_scene)

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 1.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 1000
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "FadeLayer"
	add_child(canvas)
	canvas.add_child(_fade_overlay)

func _fade_from_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.4)

func _fade_to_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.3)
	await tween.finished

func _find_doors() -> void:
	var doors_node := get_node_or_null("Doors")
	if not doors_node:
		return
	for child in doors_node.get_children():
		if child is Area2D:
			_doors.append(child)
			child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	var enemies_node := get_node_or_null("Enemies")
	if not enemies_node:
		return
	for child in enemies_node.get_children():
		if child.is_in_group("enemies"):
			_enemies.append(child)
			var health := child.get_node_or_null("HealthComponent")
			if health and health.has_signal("died"):
				health.died.connect(_on_enemy_died)

func _find_spawners() -> void:
	var enemies_node := get_node_or_null("Enemies")
	if not enemies_node:
		return
	for child in enemies_node.get_children():
		if child.has_method("get_enemy_type"):
			_spawners.append(child)

func _lock_doors() -> void:
	for door in _doors:
		door.set_meta("is_locked", true)

func _unlock_doors() -> void:
	for door in _doors:
		door.set_meta("is_locked", false)

func _on_enemy_died() -> void:
	_check_clear_condition()

func _check_clear_condition() -> void:
	if is_cleared:
		return
	
	await get_tree().create_timer(0.1).timeout
	
	var alive_count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			alive_count += 1
	
	var spawner_count := 0
	for spawner in _spawners:
		if is_instance_valid(spawner):
			spawner_count += 1
	
	if alive_count == 0 and spawner_count == 0:
		is_cleared = true
		_unlock_doors()
		room_cleared.emit()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	if door.get_meta("is_locked", false):
		return
	
	var target_room_id: String = door.get_meta("target_room_id", "")
	if target_room_id.is_empty():
		return
	
	_transition_to_room(target_room_id)

func _transition_to_room(target_room_id: String) -> void:
	await _fade_to_black()
	
	var main := get_tree().current_scene
	var player := main.get_node_or_null("Player")
	if not player:
		return
	
	var new_room_scene := load("res://scenes/" + target_room_id + ".tscn") as PackedScene
	if not new_room_scene:
		return
	
	var old_room := main.get_node_or_null("CurrentRoom")
	if old_room:
		old_room.queue_free()
	
	var new_room := new_room_scene.instantiate()
	new_room.name = "CurrentRoom"
	main.add_child(new_room)
	main.move_child(new_room, 0)
	
	player.global_position = Vector2(320, 400)
	
	if main.has_method("_on_room_entered"):
		main._on_room_entered(new_room)