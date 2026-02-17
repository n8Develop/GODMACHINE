extends Node2D
class_name RoomBase

## Base class for all dungeon rooms. Handles door connections and room transitions.

signal room_cleared
signal player_entered
signal player_exited

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies_in_room: Array[Node] = []

func _ready() -> void:
	_find_doors()
	_find_enemies()
	
	if _enemies_in_room.size() > 0:
		_lock_doors()

func _find_doors() -> void:
	var doors_node := get_node_or_null("Doors")
	if doors_node:
		for child in doors_node.get_children():
			if child is Area2D:
				_doors.append(child)
				child.body_entered.connect(_on_door_body_entered)

func _find_enemies() -> void:
	var enemies_node := get_node_or_null("Enemies")
	if enemies_node:
		for child in enemies_node.get_children():
			_enemies_in_room.append(child)
			if child.has_signal(&"died"):
				child.died.connect(_on_enemy_died)

func _lock_doors() -> void:
	for door in _doors:
		door.monitoring = false

func _unlock_doors() -> void:
	for door in _doors:
		door.monitoring = true

func _on_enemy_died() -> void:
	await get_tree().create_timer(0.1).timeout
	_check_clear_condition()

func _check_clear_condition() -> void:
	var alive_count := 0
	for enemy in _enemies_in_room:
		if is_instance_valid(enemy):
			alive_count += 1
	
	if alive_count == 0 and not is_cleared:
		is_cleared = true
		_unlock_doors()
		room_cleared.emit()

func _on_door_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var door := _get_door_from_body(body)
		if door and door.has_meta("target_room"):
			var target: String = door.get_meta("target_room")
			_transition_to_room(target)

func _get_door_from_body(body: Node2D) -> Area2D:
	for door in _doors:
		if door.overlaps_body(body):
			return door
	return null

func _transition_to_room(target_room_id: String) -> void:
	print("TRANSITION REQUEST: ", target_room_id)
	# Room manager will handle this later