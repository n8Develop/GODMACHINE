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
var _clear_check_timer: Timer = null
var _fade_overlay: ColorRect = null

func _ready() -> void:
	add_to_group("rooms")
	_spawn_floor_debris()
	_create_fade_overlay()
	_fade_from_black()
	
	await get_tree().process_frame
	_find_doors()
	_find_enemies()
	_find_spawners()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()
		_start_clear_check_timer()
	else:
		is_cleared = true
		_unlock_doors()

func _start_clear_check_timer() -> void:
	_clear_check_timer = Timer.new()
	_clear_check_timer.wait_time = 0.5
	_clear_check_timer.timeout.connect(_check_clear_condition)
	add_child(_clear_check_timer)
	_clear_check_timer.start()

func _spawn_floor_debris() -> void:
	var debris_count := randi_range(8, 16)
	for i in range(debris_count):
		var debris := ColorRect.new()
		debris.z_index = -5
		
		var debris_type := randi() % 3
		match debris_type:
			0:  # Bone
				debris.size = Vector2(randf_range(4, 10), randf_range(2, 4))
				debris.color = Color(0.85, 0.82, 0.75, 0.7)
			1:  # Rock
				debris.size = Vector2(randf_range(3, 8), randf_range(3, 8))
				debris.color = Color(0.3, 0.28, 0.25, 0.6)
			2:  # Crack
				debris.size = Vector2(randf_range(12, 24), randf_range(1, 2))
				debris.color = Color(0.15, 0.13, 0.12, 0.5)
		
		debris.position = Vector2(
			randf_range(50, 590),
			randf_range(50, 430)
		)
		debris.rotation = randf_range(0, TAU)
		add_child(debris)

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.size = Vector2(640, 480)
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.z_index = 1000
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

func _fade_from_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, 0.3)
	await tween.finished
	_fade_overlay.hide()

func _fade_to_black() -> void:
	if not _fade_overlay:
		return
	_fade_overlay.show()
	_fade_overlay.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.3)
	await tween.finished

func _find_doors() -> void:
	_doors.clear()
	var doors_container := get_node_or_null("Doors")
	if not doors_container:
		return
	
	for child in doors_container.get_children():
		if child is Area2D:
			_doors.append(child)
			child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	_enemies.clear()
	var enemies_container := get_node_or_null("Enemies")
	if not enemies_container:
		return
	
	for child in enemies_container.get_children():
		if child.is_in_group("enemies"):
			_enemies.append(child)

func _find_spawners() -> void:
	_spawners.clear()
	var enemies_container := get_node_or_null("Enemies")
	if not enemies_container:
		return
	
	for child in enemies_container.get_children():
		if "spawner_health" in child:
			_spawners.append(child)

func _lock_doors() -> void:
	for door in _doors:
		door.monitoring = false
		var visual := door.get_node_or_null("Visual")
		if visual is ColorRect:
			visual.color = Color(0.7, 0.2, 0.2, 1.0)

func _unlock_doors() -> void:
	for door in _doors:
		door.monitoring = true
		var visual := door.get_node_or_null("Visual")
		if visual is ColorRect:
			visual.color = Color(0.3, 0.7, 0.3, 1.0)

func _check_clear_condition() -> void:
	var alive_enemies := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			alive_enemies += 1
	
	var alive_spawners := 0
	for spawner in _spawners:
		if is_instance_valid(spawner):
			alive_spawners += 1
	
	if alive_enemies == 0 and alive_spawners == 0:
		if _clear_check_timer:
			_clear_check_timer.stop()
		is_cleared = true
		_unlock_doors()
		room_cleared.emit()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var target_id: String = door.get_meta("target_room_id", "")
	if target_id.is_empty():
		return
	
	_transition_to_room(target_id)

func _transition_to_room(target_room_id: String) -> void:
	await _fade_to_black()
	
	var main := get_tree().current_scene
	if not main:
		return
	
	var room_map := {
		"start": "res://scenes/room_start.tscn",
		"corridor": "res://scenes/room_corridor.tscn",
		"arena": "res://scenes/room_arena.tscn",
		"treasure": "res://scenes/room_treasure.tscn",
		"boss": "res://scenes/room_boss.tscn"
	}
	
	var scene_path: String = room_map.get(target_room_id, "res://scenes/room_corridor.tscn")
	var new_room_scene: PackedScene = load(scene_path)
	if not new_room_scene:
		return
	
	var new_room: Node = new_room_scene.instantiate()
	new_room.name = "CurrentRoom"
	
	var old_room := main.get_node_or_null("CurrentRoom")
	if old_room:
		old_room.queue_free()
	
	main.add_child(new_room)
	main.move_child(new_room, 0)
	
	var player := main.get_node_or_null("Player")
	if player:
		player.global_position = Vector2(320, 400)
	
	if new_room.has_method("_fade_from_black"):
		new_room._fade_from_black()