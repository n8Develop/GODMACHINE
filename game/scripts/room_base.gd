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
var _all_doors_locked: bool = false
var _fade_overlay: ColorRect = null

func _ready() -> void:
	_find_doors()
	_find_enemies()
	_find_spawners()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()
		for enemy in _enemies:
			if enemy.has_signal(&"died"):
				enemy.died.connect(_on_enemy_died)
	
	player_entered.emit()
	_create_fade_overlay()
	_fade_from_black()

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.size = Vector2(640, 480)
	_fade_overlay.z_index = 200
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

func _fade_from_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): _fade_overlay.hide())

func _fade_to_black() -> void:
	if not _fade_overlay:
		return
	_fade_overlay.show()
	_fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.25)
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
			if child.has_node("HealthComponent"):
				_enemies.append(child)
				var health := child.get_node("HealthComponent") as HealthComponent
				if health and health.has_signal(&"died"):
					health.died.connect(_on_enemy_died)

func _find_spawners() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.has_method("_spawn_enemy"):
				_spawners.append(child)

func _lock_doors() -> void:
	_all_doors_locked = true
	for door in _doors:
		door.set_meta(&"locked_by_room", true)

func _unlock_doors() -> void:
	_all_doors_locked = false
	for door in _doors:
		door.set_meta(&"locked_by_room", false)

func _on_enemy_died() -> void:
	await get_tree().create_timer(0.1).timeout
	_check_clear_condition()

func _check_clear_condition() -> void:
	var alive_enemies := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			alive_enemies += 1
	
	var active_spawners := 0
	for spawner in _spawners:
		if is_instance_valid(spawner) and spawner.get(&"_is_active"):
			active_spawners += 1
	
	if alive_enemies == 0 and active_spawners == 0 and not is_cleared:
		is_cleared = true
		_unlock_doors()
		room_cleared.emit()
		print("GODMACHINE: Room ", room_id, " cleared — barriers lifted")

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if body.is_in_group("player"):
		if door.get_meta(&"locked_by_room", false):
			print("GODMACHINE: Door locked — clear the room first")
			return
		
		var target := door.get_meta(&"target_room", "")
		if target != "":
			_transition_to_room(target)

func _transition_to_room(target_room_id: String) -> void:
	print("GODMACHINE: Transitioning to ", target_room_id)
	
	await _fade_to_black()
	
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var visited: Array = player.get_meta(&"visited_rooms", [])
		if not visited.has(target_room_id):
			visited.append(target_room_id)
			player.set_meta(&"visited_rooms", visited)
	
	var main := get_parent()
	var current_room := main.get_node_or_null("CurrentRoom")
	if current_room:
		current_room.queue_free()
	
	var room_map := {
		"start": "res://scenes/room_start.tscn",
		"corridor": "res://scenes/room_corridor.tscn",
		"treasure": "res://scenes/room_treasure.tscn",
		"arena": "res://scenes/room_arena.tscn"
	}
	
	var scene_path: String = room_map.get(target_room_id, "res://scenes/room_start.tscn")
	var new_room := load(scene_path).instantiate()
	new_room.name = "CurrentRoom"
	main.add_child(new_room)
	
	if player:
		player.global_position = Vector2(320, 400)