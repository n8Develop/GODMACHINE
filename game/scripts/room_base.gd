extends Node2D
class_name RoomBase

signal room_cleared
signal player_entered
signal player_exited

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array[Node] = []
var _spawners: Array[Node2D] = []
var _fade_overlay: ColorRect = null

func _ready() -> void:
	add_to_group("rooms")
	_create_fade_overlay()
	_fade_from_black()
	await get_tree().create_timer(0.1).timeout
	_find_doors()
	_find_enemies()
	_find_spawners()
	
	# Adapt room based on dungeon memory
	_adapt_to_memory()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()

func _adapt_to_memory() -> void:
	var memory := get_tree().current_scene.get_node_or_null("DungeonMemory") as DungeonMemory
	if not memory:
		return
	
	var threat := memory.get_threat_level()
	var is_desperate := memory.is_player_desperate()
	
	# If player is desperate (low HP), increase healing spawn chance
	if is_desperate and randf() < memory.get_adaptive_heal_chance():
		_spawn_emergency_health()
	
	# Adjust enemy count based on threat history
	var base_enemy_count := _enemies.size()
	var adjusted_count := memory.get_adaptive_spawn_count(base_enemy_count)
	var diff := adjusted_count - base_enemy_count
	
	if diff > 0:
		# Spawn additional enemies
		for i in range(diff):
			_spawn_additional_enemy()
	elif diff < 0:
		# Remove some enemies (mercy scaling)
		for i in range(abs(diff)):
			if _enemies.size() > 1:
				var victim := _enemies.pop_back()
				if is_instance_valid(victim):
					victim.queue_free()
	
	# Force variety in spawners
	for spawner in _spawners:
		if spawner.has_method("get_enemy_type"):
			var enemy_type: String = spawner.get_enemy_type()
			if memory.should_force_variety(enemy_type):
				# Replace spawner's enemy scene with a different type
				_randomize_spawner_enemy(spawner)

func _spawn_emergency_health() -> void:
	var pickup_scene := load("res://scenes/pickup_health_greater.tscn") as PackedScene
	if not pickup_scene:
		return
	
	var pickup := pickup_scene.instantiate()
	# Place in center of room
	pickup.position = Vector2(320, 240)
	
	var pickups_container := get_node_or_null("Pickups")
	if pickups_container:
		pickups_container.add_child(pickup)
	else:
		add_child(pickup)

func _spawn_additional_enemy() -> void:
	# Pick a random enemy type from existing enemies
	if _enemies.is_empty():
		return
	
	var template := _enemies.pick_random()
	if not is_instance_valid(template):
		return
	
	var new_enemy := template.duplicate()
	# Random position near room edges
	var spawn_pos := Vector2(
		randf_range(100, 540),
		randf_range(100, 380)
	)
	new_enemy.position = spawn_pos
	
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		enemies_container.add_child(new_enemy)
		_enemies.append(new_enemy)
		var health := new_enemy.get_node_or_null("HealthComponent")
		if health:
			health.died.connect(_on_enemy_died)
	else:
		new_enemy.queue_free()

func _randomize_spawner_enemy(spawner: Node2D) -> void:
	var enemy_types := [
		"res://scenes/enemy_bat.tscn",
		"res://scenes/enemy_slime_poison.tscn",
		"res://scenes/enemy_skeleton.tscn"
	]
	
	var new_scene := load(enemy_types.pick_random()) as PackedScene
	if new_scene and spawner.has_method("set_enemy_scene"):
		spawner.set_enemy_scene(new_scene)

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 1000
	
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(_fade_overlay)
	add_child(canvas)
	
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

func _fade_from_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, 0.4)

func _fade_to_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.3)
	await tween.finished

func _find_doors() -> void:
	var doors_container := get_node_or_null("Doors")
	if doors_container:
		for child in doors_container.get_children():
			if child is Area2D:
				_doors.append(child)
				child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.is_in_group("enemies"):
				_enemies.append(child)
				var health := child.get_node_or_null("HealthComponent")
				if health:
					health.died.connect(_on_enemy_died)

func _find_spawners() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.has_method("take_damage"):
				_spawners.append(child)
				child.tree_exited.connect(_on_enemy_died)

func _lock_doors() -> void:
	for door in _doors:
		door.monitoring = false
		var visual := door.get_node_or_null("Visual")
		if visual is ColorRect:
			visual.color = Color(0.6, 0.1, 0.1, 1.0)

func _unlock_doors() -> void:
	for door in _doors:
		door.monitoring = true
		var visual := door.get_node_or_null("Visual")
		if visual is ColorRect:
			visual.color = Color(0.2, 0.8, 0.3, 1.0)

func _on_enemy_died() -> void:
	_check_clear_condition()

func _check_clear_condition() -> void:
	await get_tree().create_timer(0.1).timeout
	
	var living_enemies := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			living_enemies += 1
	
	var living_spawners := 0
	for spawner in _spawners:
		if is_instance_valid(spawner):
			living_spawners += 1
	
	if living_enemies == 0 and living_spawners == 0:
		is_cleared = true
		_unlock_doors()
		room_cleared.emit()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if body.is_in_group("player"):
		var target_room_id: String = door.get_meta("target_room_id", "")
		if target_room_id != "":
			_transition_to_room(target_room_id)

func _transition_to_room(target_room_id: String) -> void:
	await _fade_to_black()
	
	var room_scenes := {
		"start": "res://scenes/room_start.tscn",
		"corridor": "res://scenes/room_corridor.tscn",
		"arena": "res://scenes/room_arena.tscn",
		"treasure": "res://scenes/room_treasure.tscn",
		"boss": "res://scenes/room_boss.tscn"
	}
	
	var scene_path: String = room_scenes.get(target_room_id, "")
	if scene_path == "":
		return
	
	var new_room_scene := load(scene_path) as PackedScene
	if not new_room_scene:
		return
	
	var main := get_tree().current_scene
	var player := main.get_node_or_null("Player")
	
	queue_free()
	
	var new_room := new_room_scene.instantiate()
	new_room.name = "CurrentRoom"
	main.add_child(new_room)
	main.move_child(new_room, 0)
	
	if player:
		player.global_position = Vector2(320, 400)
	
	# Notify memory system of room entry
	if main.has_method("_on_room_entered"):
		main._on_room_entered(new_room)