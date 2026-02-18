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
	_spawn_floor_debris()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()
		_start_clear_check_timer()
	else:
		is_cleared = true
	
	_fade_from_black()

func _start_clear_check_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_check_clear_condition)
	add_child(timer)
	timer.start()

func _spawn_floor_debris() -> void:
	var debris_container := Node2D.new()
	debris_container.name = "FloorDebris"
	debris_container.z_index = -5
	add_child(debris_container)
	
	var bounds := Rect2(80, 80, 480, 320)
	
	var count := randi_range(8, 16)
	for i in range(count):
		var debris := ColorRect.new()
		var debris_type := randi() % 3
		
		match debris_type:
			0:
				debris.size = Vector2(randf_range(4, 8), randf_range(2, 4))
				debris.color = Color(0.85, 0.82, 0.75, 0.6)
			1:
				debris.size = Vector2(randf_range(3, 6), randf_range(3, 6))
				debris.color = Color(0.3, 0.3, 0.35, 0.5)
			2:
				debris.size = Vector2(randf_range(6, 12), randf_range(1, 2))
				debris.color = Color(0.15, 0.15, 0.18, 0.4)
		
		debris.position = Vector2(
			randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		debris.rotation = randf() * TAU
		debris_container.add_child(debris)

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

func _check_clear_condition() -> void:
	if is_cleared:
		return
	
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