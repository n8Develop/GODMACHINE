extends Node2D
class_name RoomBase

signal room_cleared
signal player_entered
signal player_exited

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array[Node] = []
var _initial_enemy_count: int = 0
var _spawners: Array[Node] = []

func _ready() -> void:
	_find_doors()
	_find_enemies()
	_find_spawners()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()
	
	# Track player visit
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var visited_rooms: Array = player.get_meta("visited_rooms", [])
		if not visited_rooms.has(room_id):
			visited_rooms.append(room_id)
			player.set_meta("visited_rooms", visited_rooms)

func _find_doors() -> void:
	var doors_container := get_node_or_null("Doors")
	if not doors_container:
		return
	
	for child in doors_container.get_children():
		if child is Area2D:
			_doors.append(child)
			child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if not enemies_container:
		return
	
	for child in enemies_container.get_children():
		if child.has_node("HealthComponent"):
			_enemies.append(child)
			var health := child.get_node("HealthComponent") as HealthComponent
			if health:
				health.died.connect(_on_enemy_died)
	
	_initial_enemy_count = _enemies.size()

func _find_spawners() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if not enemies_container:
		return
	
	for child in enemies_container.get_children():
		if child.has_method("_spawn_enemy"):
			_spawners.append(child)

func _lock_doors() -> void:
	for door in _doors:
		door.monitoring = false

func _unlock_doors() -> void:
	for door in _doors:
		door.monitoring = true
	is_cleared = true
	room_cleared.emit()
	print("GODMACHINE: Room ", room_id, " cleared — passage granted")

func _on_enemy_died() -> void:
	_check_clear_condition()

func _check_clear_condition() -> void:
	if is_cleared:
		return
	
	# Count alive enemies (including spawned ones)
	var alive_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get_parent() == get_node("Enemies"):
			alive_count += 1
	
	# Check if spawners are still active
	var active_spawners := 0
	for spawner in _spawners:
		if spawner.has_method("_spawn_enemy"):
			active_spawners += 1
	
	if alive_count == 0 and active_spawners == 0:
		_unlock_doors()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if body.is_in_group("player"):
		var target := door.get_meta("target_room", "") as String
		if target != "":
			_transition_to_room(target)

func _get_door_from_body(body: Node2D) -> Area2D:
	for door in _doors:
		if door.overlaps_body(body):
			return door
	return null

func _transition_to_room(target_room_id: String) -> void:
	print("GODMACHINE: Transition requested — ", room_id, " → ", target_room_id)
	var room_map := {
		"start": preload("res://scenes/room_start.tscn"),
		"corridor": preload("res://scenes/room_corridor.tscn"),
		"treasure": preload("res://scenes/room_treasure.tscn"),
		"arena": preload("res://scenes/room_arena.tscn")
	}
	
	if not room_map.has(target_room_id):
		push_error("GODMACHINE ERROR: Unknown room — ", target_room_id)
		return
	
	var new_room := room_map[target_room_id].instantiate()
	var main := get_parent()
	var player := get_tree().get_first_node_in_group("player")
	
	if main and player:
		var player_pos := player.global_position
		main.remove_child(self)
		queue_free()
		main.add_child(new_room)
		main.move_child(new_room, 0)
		player.global_position = player_pos